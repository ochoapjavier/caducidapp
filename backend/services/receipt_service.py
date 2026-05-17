from collections import Counter

from fastapi import HTTPException
from sqlalchemy.orm import Session

from repositories.receipt_repository import ReceiptRepository
from schemas.item import StockItemCreate, StockItemCreateFromScan
from schemas.receipt import TicketAllocation, TicketMatchRequest
from services.stock_service import StockService


class ReceiptService:
    def __init__(self, db: Session):
        self.db = db
        self.repo = ReceiptRepository(db)
        self.stock_service = StockService(db)

    def _resolve_supermercado_id(self, request: TicketMatchRequest) -> int:
        if request.supermercado_id is not None:
            supermercado = self.repo.get_supermercado_by_id(request.supermercado_id)
            if supermercado is None:
                raise HTTPException(
                    status_code=404,
                    detail='Supermercado no encontrado.',
                )
            return supermercado.id_supermercado

        nombre_super = request.supermercado_nombre.strip().upper()
        if not nombre_super:
            nombre_super = 'DESCONOCIDO'

        supermercado = self.repo.get_supermercado_by_name(nombre_super)
        if supermercado is not None:
            return supermercado.id_supermercado

        supermercado = self.repo.create_supermercado(nombre=nombre_super)
        return supermercado.id_supermercado

    def _learn_dictionary_mappings(
        self,
        hogar_id: int,
        supermercado_id: int,
        ticket_nombre: str,
        barcodes: list[str],
    ) -> int:
        matches_creados = 0
        for barcode in dict.fromkeys(barcodes):
            product = self.repo.get_product_by_barcode_and_hogar(barcode, hogar_id)
            if product is None:
                continue

            exists = self.repo.dictionary_entry_exists(
                ticket_nombre=ticket_nombre,
                supermercado_id=supermercado_id,
                hogar_id=hogar_id,
                product_id=product.id_producto,
            )
            if exists:
                continue

            self.repo.create_dictionary_entry(
                hogar_id=hogar_id,
                ticket_nombre=ticket_nombre,
                supermercado_id=supermercado_id,
                product_id=product.id_producto,
            )
            matches_creados += 1

        return matches_creados

    def _normalize_allocations(self, item) -> list[TicketAllocation]:
        if item.asignaciones:
            allocations: list[TicketAllocation] = []
            total_quantity = 0

            for allocation in item.asignaciones:
                if allocation.cantidad <= 0:
                    raise HTTPException(
                        status_code=400,
                        detail=(
                            f'La línea "{item.nombre}" tiene una asignación con cantidad inválida.'
                        ),
                    )

                barcode = allocation.barcode.strip() if allocation.barcode else None
                normalized_product_name = (allocation.product_name or item.nombre).strip()

                total_quantity += allocation.cantidad
                allocations.append(
                    TicketAllocation(
                        cantidad=allocation.cantidad,
                        barcode=barcode,
                        product_name=normalized_product_name,
                        brand=allocation.brand,
                        image_url=allocation.image_url,
                        ubicacion_id=allocation.ubicacion_id or item.ubicacion_id,
                        fecha_caducidad=allocation.fecha_caducidad or item.fecha_caducidad,
                    )
                )

            if total_quantity != item.cantidad:
                raise HTTPException(
                    status_code=400,
                    detail=(
                        f'La línea "{item.nombre}" reparte {total_quantity} unidades '
                        f'pero el ticket indica {item.cantidad}.'
                    ),
                )

            return allocations

        normalized_barcodes = [
            barcode.strip()
            for barcode in item.eansAsignados
            if barcode and barcode.strip()
        ]
        if not normalized_barcodes:
            return []

        should_preserve_legacy_stock_rule = (
            item.ubicacion_id is not None and item.fecha_caducidad is not None
        )
        if should_preserve_legacy_stock_rule and len(normalized_barcodes) != item.cantidad:
            raise HTTPException(
                status_code=400,
                detail=(
                    f'La línea "{item.nombre}" debe tener un EAN por unidad '
                    'para guardarse correctamente en inventario.'
                ),
            )

        return [
            TicketAllocation(
                cantidad=quantity,
                barcode=barcode,
                product_name=item.nombre,
                ubicacion_id=item.ubicacion_id,
                fecha_caducidad=item.fecha_caducidad,
            )
            for barcode, quantity in Counter(normalized_barcodes).items()
        ]

    def match_ticket_items(
        self,
        request: TicketMatchRequest,
        hogar_id: int,
        user_id: str,
    ) -> dict:
        supermercado_id = self._resolve_supermercado_id(request)
        matches_creados = 0
        stock_lineas_procesadas = 0
        stock_unidades_procesadas = 0

        for item in request.items:
            allocations = self._normalize_allocations(item)

            for allocation in allocations:
                if (
                    allocation.ubicacion_id is None
                    or allocation.fecha_caducidad is None
                ):
                    continue

                if allocation.barcode:
                    payload = StockItemCreateFromScan(
                        barcode=allocation.barcode,
                        product_name=allocation.product_name or item.nombre,
                        brand=allocation.brand,
                        image_url=allocation.image_url,
                        ubicacion_id=allocation.ubicacion_id,
                        cantidad=allocation.cantidad,
                        fecha_caducidad=allocation.fecha_caducidad,
                    )
                    self.stock_service.process_scan_stock(payload, hogar_id, user_id)
                else:
                    payload = StockItemCreate(
                        product_name=allocation.product_name or item.nombre,
                        brand=allocation.brand,
                        image_url=allocation.image_url,
                        ubicacion_id=allocation.ubicacion_id,
                        cantidad=allocation.cantidad,
                        fecha_caducidad=allocation.fecha_caducidad,
                    )
                    self.stock_service.process_manual_stock(payload, hogar_id, user_id)

                stock_lineas_procesadas += 1
                stock_unidades_procesadas += allocation.cantidad

            learned_barcodes = [allocation.barcode for allocation in allocations if allocation.barcode]
            if learned_barcodes:
                matches_creados += self._learn_dictionary_mappings(
                    hogar_id=hogar_id,
                    supermercado_id=supermercado_id,
                    ticket_nombre=item.nombre,
                    barcodes=learned_barcodes,
                )

        self.db.commit()
        return {
            'message': 'Ticket procesado correctamente',
            'matches_creados': matches_creados,
            'stock_lineas_procesadas': stock_lineas_procesadas,
            'stock_unidades_procesadas': stock_unidades_procesadas,
        }

    def get_dictionary_memory(self, hogar_id: int) -> list[dict]:
        rows = self.repo.get_dictionary_rows(hogar_id)

        memory_map: dict[tuple[int, str], dict[str, dict]] = {}
        for supermercado_id, ticket_nombre, barcode, product_name, brand, image_url in rows:
            if not barcode:
                continue

            key = (supermercado_id, ticket_nombre)
            if key not in memory_map:
                memory_map[key] = {}
            if barcode not in memory_map[key]:
                memory_map[key][barcode] = {
                    'barcode': barcode,
                    'product_name': product_name,
                    'brand': brand,
                    'image_url': image_url,
                }

        response = []
        for (supermercado_id, ticket_nombre), matches_by_barcode in memory_map.items():
            matches = list(matches_by_barcode.values())
            response.append(
                {
                    'supermercado_id': supermercado_id,
                    'ticket_nombre': ticket_nombre,
                    'eans': [match['barcode'] for match in matches],
                    'matches': matches,
                }
            )

        return response