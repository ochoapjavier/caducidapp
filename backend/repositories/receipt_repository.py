from sqlalchemy.orm import Session

from models import DiccionarioTicketProducto, Product, Supermercado


class ReceiptRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_supermercado_by_id(self, supermercado_id: int) -> Supermercado | None:
        return (
            self.db.query(Supermercado)
            .filter(Supermercado.id_supermercado == supermercado_id)
            .first()
        )

    def get_supermercado_by_name(self, nombre: str) -> Supermercado | None:
        return (
            self.db.query(Supermercado)
            .filter(Supermercado.nombre.ilike(nombre))
            .first()
        )

    def create_supermercado(
        self,
        nombre: str,
        logo_url: str | None = None,
        color_hex: str | None = '#808080',
    ) -> Supermercado:
        supermercado = Supermercado(
            nombre=nombre,
            logo_url=logo_url,
            color_hex=color_hex,
        )
        self.db.add(supermercado)
        self.db.commit()
        self.db.refresh(supermercado)
        return supermercado

    def get_product_by_barcode_and_hogar(
        self, barcode: str, hogar_id: int
    ) -> Product | None:
        return (
            self.db.query(Product)
            .filter(Product.barcode == barcode, Product.hogar_id == hogar_id)
            .first()
        )

    def dictionary_entry_exists(
        self,
        ticket_nombre: str,
        supermercado_id: int,
        hogar_id: int,
        product_id: int,
    ) -> bool:
        return (
            self.db.query(DiccionarioTicketProducto)
            .filter(
                DiccionarioTicketProducto.ticket_nombre == ticket_nombre,
                DiccionarioTicketProducto.fk_supermercado == supermercado_id,
                DiccionarioTicketProducto.hogar_id == hogar_id,
                DiccionarioTicketProducto.fk_producto_maestro == product_id,
            )
            .first()
            is not None
        )

    def create_dictionary_entry(
        self,
        hogar_id: int,
        ticket_nombre: str,
        supermercado_id: int,
        product_id: int,
    ) -> DiccionarioTicketProducto:
        entry = DiccionarioTicketProducto(
            hogar_id=hogar_id,
            ticket_nombre=ticket_nombre,
            fk_supermercado=supermercado_id,
            fk_producto_maestro=product_id,
        )
        self.db.add(entry)
        return entry

    def get_dictionary_rows(self, hogar_id: int):
        return (
            self.db.query(
                DiccionarioTicketProducto.fk_supermercado,
                DiccionarioTicketProducto.ticket_nombre,
                Product.barcode,
                Product.nombre,
                Product.marca,
                Product.image_url,
            )
            .join(
                Product,
                DiccionarioTicketProducto.fk_producto_maestro == Product.id_producto,
            )
            .filter(DiccionarioTicketProducto.hogar_id == hogar_id)
            .all()
        )