from fastapi import APIRouter, Depends, status
from sqlalchemy.orm import Session

from database import get_db
from dependencies import require_miembro_or_admin_role
from schemas import ReceiptDictionaryEntry, TicketMatchRequest
from services.receipt_service import ReceiptService

router = APIRouter()


def get_receipt_service(db: Session = Depends(get_db)) -> ReceiptService:
    return ReceiptService(db)


@router.post('/match', status_code=status.HTTP_201_CREATED)
def match_ticket_items(
    request: TicketMatchRequest,
    service: ReceiptService = Depends(get_receipt_service),
    user_hogar=Depends(require_miembro_or_admin_role),
):
    """
    Recibe el ticket revisado por el usuario.
    Aprende asociaciones ticket-producto y, si llega la metadata necesaria,
    persiste el stock en inventario por cada EAN escaneado.
    """
    hogar_id, user_id = user_hogar
    return service.match_ticket_items(request, hogar_id, user_id)


@router.get('/dictionary', response_model=list[ReceiptDictionaryEntry])
def get_dictionary_memory(
    service: ReceiptService = Depends(get_receipt_service),
    user_hogar=Depends(require_miembro_or_admin_role),
):
    """
    Devuelve la memoria histórica del hogar.
    Agrupa los EANs físicos asociados a cada nombre de ticket por supermercado.
    """
    hogar_id, _ = user_hogar
    return service.get_dictionary_memory(hogar_id)
