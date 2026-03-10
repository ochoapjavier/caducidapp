# backend/routers/receipts.py
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from database import get_db
from models import Product, DiccionarioTicketProducto, Supermercado
from schemas import TicketMatchRequest
from dependencies import require_miembro_or_admin_role

router = APIRouter()

@router.post("/match", status_code=status.HTTP_201_CREATED)
def match_ticket_items(
    request: TicketMatchRequest,
    db: Session = Depends(get_db),
    user_hogar=Depends(require_miembro_or_admin_role)
):
    """
    Recibe la lista de items procesados por el OCR y el Matchmaker.
    Guarda las asociaciones entre el "nombre_ticket" y el "id_producto"
    para que la app "Aprenda" y autocompleta la próxima vez.
    """
    hogar_id, user = user_hogar
    matches_creados = 0

    # Determinar qué supermercado_id usar
    actual_supermercado_id = request.supermercado_id

    if actual_supermercado_id is None:
        # El cliente no mandó ID, mandó el texto para intentar recuperarlo o crearlo
        nombre_super = request.supermercado_nombre.strip().upper()
        super_obj = db.query(Supermercado).filter(Supermercado.nombre.ilike(nombre_super)).first()
        
        if super_obj:
            actual_supermercado_id = super_obj.id_supermercado
        else:
            # Creación dinámica (El "Híbrido Silencioso") si el frontal confía
            nuevo_super = Supermercado(
                nombre=nombre_super,
                logo_url=None,
                color_hex='#808080'
            )
            db.add(nuevo_super)
            db.commit()
            db.refresh(nuevo_super)
            actual_supermercado_id = nuevo_super.id_supermercado

    for item in request.items:
        if not item.eansAsignados:
            continue
            
        # Para cada EAN asignado, buscamos si el producto existe en este hogar
        for ean in item.eansAsignados:
            producto = db.query(Product).filter(
                Product.barcode == ean, 
                Product.hogar_id == hogar_id
            ).first()

            if producto:
                # Verificar si ya existe en el diccionario para no duplicar (ahora permite N productos distintos bajo el mismo nombre)
                existe = db.query(DiccionarioTicketProducto).filter(
                    DiccionarioTicketProducto.ticket_nombre == item.nombre,
                    DiccionarioTicketProducto.fk_supermercado == actual_supermercado_id,
                    DiccionarioTicketProducto.hogar_id == hogar_id,
                    DiccionarioTicketProducto.fk_producto_maestro == producto.id_producto
                ).first()
                
                if not existe:
                    nuevo_dic = DiccionarioTicketProducto(
                        hogar_id=hogar_id,
                        ticket_nombre=item.nombre,
                        fk_supermercado=actual_supermercado_id,
                        fk_producto_maestro=producto.id_producto
                    )
                    db.add(nuevo_dic)
                    matches_creados += 1

    db.commit()
    return {"message": "Aprendizaje completado", "matches_creados": matches_creados}

@router.get("/dictionary", response_model=list[dict])
def get_dictionary_memory(
    db: Session = Depends(get_db),
    user_hogar=Depends(require_miembro_or_admin_role)
):
    """
    Devuelve la memoria histórica del hogar.
    Agrupa los EANs físicos asociados a cada nombre de ticket por supermercado.
    """
    hogar_id, user = user_hogar
    
    # Recuperamos todos los mapeos de este hogar uniendo la tabla de productos para obtener el EAN (barcode)
    results = db.query(
        DiccionarioTicketProducto.fk_supermercado,
        DiccionarioTicketProducto.ticket_nombre,
        Product.barcode
    ).join(
        Product, DiccionarioTicketProducto.fk_producto_maestro == Product.id_producto
    ).filter(
        DiccionarioTicketProducto.hogar_id == hogar_id
    ).all()
    
    # Agrupamos en memoria (1 a N)
    memory_map = {}
    for super_id, t_nombre, barcode in results:
        key = (super_id, t_nombre)
        if key not in memory_map:
            memory_map[key] = []
        if barcode and barcode not in memory_map[key]:
            memory_map[key].append(barcode)
            
    # Formateamos la respuesta
    response = []
    for (super_id, t_nombre), eans in memory_map.items():
        response.append({
            "supermercado_id": super_id,
            "ticket_nombre": t_nombre,
            "eans": eans
        })
        
    return response
