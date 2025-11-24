# backend/services/hogar_service.py
"""Business logic for household management."""

from sqlalchemy.orm import Session
from typing import Optional
from fastapi import HTTPException, status

from repositories.hogar_repository import HogarRepository
from schemas.hogar import (
    HogarCreate, HogarUpdate, HogarSchema, HogarDetalle,
    HogarMiembroCreate, HogarMiembroUpdate, MiembroInfo
)


class HogarService:
    """Service layer for household operations."""
    
    def __init__(self, db: Session):
        self.repo = HogarRepository(db)
    
    def create_hogar(self, hogar_data: HogarCreate, user_id: str) -> HogarSchema:
        """
        Create a new household and make the creator an admin.
        
        Args:
            hogar_data: Household creation data
            user_id: ID of the user creating the household
        
        Returns:
            Created household with user's role information
        """
        # Create the household
        hogar = self.repo.create_hogar(
            nombre=hogar_data.nombre,
            created_by=user_id,
            icono=hogar_data.icono
        )
        
        # Add creator as admin
        self.repo.add_miembro(
            hogar_id=hogar.id_hogar,
            user_id=user_id,
            rol='admin',
            apodo='Yo'
        )
        
        # Return with role info
        return HogarSchema(
            id_hogar=hogar.id_hogar,
            nombre=hogar.nombre,
            created_by=hogar.created_by,
            fecha_creacion=hogar.fecha_creacion,
            icono=hogar.icono,
            codigo_invitacion=hogar.codigo_invitacion,
            miembros_count=1,
            mi_rol='admin'
        )
    
    def get_hogares_usuario(self, user_id: str) -> list[HogarSchema]:
        """
        Get all households where user is a member.
        
        Args:
            user_id: User ID
        
        Returns:
            List of households with user's role and member count
        """
        hogares = self.repo.get_hogares_by_user(user_id)
        result = []
        
        for hogar in hogares:
            miembro = self.repo.get_miembro(user_id, hogar.id_hogar)
            miembros_count = len(self.repo.get_miembros_by_hogar(hogar.id_hogar))
            
            result.append(HogarSchema(
                id_hogar=hogar.id_hogar,
                nombre=hogar.nombre,
                created_by=hogar.created_by,
                fecha_creacion=hogar.fecha_creacion,
                icono=hogar.icono,
                codigo_invitacion=hogar.codigo_invitacion,
                miembros_count=miembros_count,
                mi_rol=miembro.rol if miembro else None
            ))
        
        return result
    
    def get_hogar_detalle(self, hogar_id: int, user_id: str) -> HogarDetalle:
        """
        Get detailed household information including members.
        
        Args:
            hogar_id: Household ID
            user_id: Current user ID (for role information)
        
        Returns:
            Detailed household information
        
        Raises:
            HTTPException 404: If household not found
        """
        hogar = self.repo.get_hogar_by_id(hogar_id)
        if not hogar:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Hogar no encontrado"
            )
        
        miembros = self.repo.get_miembros_by_hogar(hogar_id)
        mi_miembro = self.repo.get_miembro(user_id, hogar_id)
        
        return HogarDetalle(
            id_hogar=hogar.id_hogar,
            nombre=hogar.nombre,
            created_by=hogar.created_by,
            fecha_creacion=hogar.fecha_creacion,
            icono=hogar.icono,
            codigo_invitacion=hogar.codigo_invitacion,
            miembros_count=len(miembros),
            mi_rol=mi_miembro.rol if mi_miembro else None,
            miembros=[
                MiembroInfo(
                    user_id=m.user_id,
                    rol=m.rol,
                    apodo=m.apodo,
                    fecha_union=m.fecha_union
                )
                for m in miembros
            ]
        )
    
    def update_hogar(
        self, 
        hogar_id: int, 
        hogar_data: HogarUpdate
    ) -> HogarSchema:
        """
        Update household information.
        
        Args:
            hogar_id: Household ID
            hogar_data: Update data
        
        Returns:
            Updated household
        
        Raises:
            HTTPException 404: If household not found
        """
        hogar = self.repo.update_hogar(
            hogar_id=hogar_id,
            nombre=hogar_data.nombre,
            icono=hogar_data.icono
        )
        
        if not hogar:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Hogar no encontrado"
            )
        
        miembros_count = len(self.repo.get_miembros_by_hogar(hogar_id))
        
        return HogarSchema(
            id_hogar=hogar.id_hogar,
            nombre=hogar.nombre,
            created_by=hogar.created_by,
            fecha_creacion=hogar.fecha_creacion,
            icono=hogar.icono,
            codigo_invitacion=hogar.codigo_invitacion,
            miembros_count=miembros_count,
            mi_rol=None
        )
    
    def delete_hogar(self, hogar_id: int):
        """
        Delete a household (admin only, checked by dependency).
        
        Args:
            hogar_id: Household ID
        
        Raises:
            HTTPException 404: If household not found
        """
        success = self.repo.delete_hogar(hogar_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Hogar no encontrado"
            )
    
    def unirse_a_hogar(
        self, 
        codigo: str, 
        user_id: str,
        apodo: Optional[str] = None
    ) -> HogarSchema:
        """
        Join a household using an invitation code.
        
        Args:
            codigo: Invitation code
            user_id: User ID
            apodo: Optional nickname
        
        Returns:
            Household information
        
        Raises:
            HTTPException 404: If invitation code is invalid
            HTTPException 400: If user is already a member
        """
        hogar = self.repo.get_hogar_by_codigo(codigo)
        if not hogar:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Código de invitación inválido"
            )
        
        # Try to add member
        miembro = self.repo.add_miembro(
            hogar_id=hogar.id_hogar,
            user_id=user_id,
            rol='miembro',
            apodo=apodo
        )
        
        if not miembro:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Ya eres miembro de este hogar"
            )
        
        miembros_count = len(self.repo.get_miembros_by_hogar(hogar.id_hogar))
        
        return HogarSchema(
            id_hogar=hogar.id_hogar,
            nombre=hogar.nombre,
            created_by=hogar.created_by,
            fecha_creacion=hogar.fecha_creacion,
            icono=hogar.icono,
            codigo_invitacion=hogar.codigo_invitacion,
            miembros_count=miembros_count,
            mi_rol='miembro'
        )
    
    def regenerar_codigo_invitacion(self, hogar_id: int) -> str:
        """
        Generate a new invitation code (admin only).
        
        Args:
            hogar_id: Household ID
        
        Returns:
            New invitation code
        
        Raises:
            HTTPException 404: If household not found
        """
        codigo = self.repo.regenerate_invitation_code(hogar_id)
        if not codigo:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Hogar no encontrado"
            )
        return codigo
    
    def expulsar_miembro(
        self, 
        hogar_id: int, 
        user_id_to_remove: str,
        requesting_user_id: str
    ):
        """
        Remove a member from household (admin only).
        
        Args:
            hogar_id: Household ID
            user_id_to_remove: User ID to remove
            requesting_user_id: Admin user making the request
        
        Raises:
            HTTPException 400: If trying to remove yourself or last admin
            HTTPException 404: If member not found
        """
        # Cannot remove yourself
        if user_id_to_remove == requesting_user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="No puedes expulsarte a ti mismo. Usa 'abandonar hogar' en su lugar."
            )
        
        # Check if removing an admin
        miembro = self.repo.get_miembro(user_id_to_remove, hogar_id)
        if miembro and miembro.rol == 'admin':
            # Ensure there's another admin
            admin_count = self.repo.count_admins(hogar_id)
            if admin_count <= 1:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No puedes expulsar al último administrador. Asigna otro admin primero."
                )
        
        success = self.repo.remove_miembro(user_id_to_remove, hogar_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Miembro no encontrado"
            )
    
    def abandonar_hogar(self, hogar_id: int, user_id: str):
        """
        Leave a household.
        
        Args:
            hogar_id: Household ID
            user_id: User ID
        
        Raises:
            HTTPException 400: If user is the last admin
        """
        miembro = self.repo.get_miembro(user_id, hogar_id)
        if miembro and miembro.rol == 'admin':
            admin_count = self.repo.count_admins(hogar_id)
            if admin_count <= 1:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="Eres el último administrador. Asigna otro admin antes de abandonar, o elimina el hogar."
                )
        
        success = self.repo.remove_miembro(user_id, hogar_id)
        if not success:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="No eres miembro de este hogar"
            )
    
    def cambiar_rol_miembro(
        self,
        hogar_id: int,
        user_id_target: str,
        nuevo_rol: str
    ):
        """
        Change a member's role (admin only).
        
        Args:
            hogar_id: Household ID
            user_id_target: User whose role to change
            nuevo_rol: New role
        
        Raises:
            HTTPException 400: If trying to demote last admin
            HTTPException 404: If member not found
        """
        # If demoting an admin, check there's another
        miembro = self.repo.get_miembro(user_id_target, hogar_id)
        if miembro and miembro.rol == 'admin' and nuevo_rol != 'admin':
            admin_count = self.repo.count_admins(hogar_id)
            if admin_count <= 1:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail="No puedes quitar el rol de admin al último administrador"
                )
        
        updated = self.repo.update_miembro_rol(user_id_target, hogar_id, nuevo_rol)
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Miembro no encontrado"
            )
    
    def actualizar_apodo_miembro(
        self,
        hogar_id: int,
        user_id: str,
        nuevo_apodo: str
    ):
        """
        Update a member's nickname.
        
        Args:
            hogar_id: Household ID
            user_id: User ID
            nuevo_apodo: New nickname
        
        Raises:
            HTTPException 404: If member not found
        """
        updated = self.repo.update_miembro_apodo(user_id, hogar_id, nuevo_apodo)
        if not updated:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Miembro no encontrado"
            )
