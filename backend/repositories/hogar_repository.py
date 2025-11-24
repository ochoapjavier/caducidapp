# backend/repositories/hogar_repository.py
from sqlalchemy.orm import Session
from typing import Optional
from models import Hogar, HogarMiembro
import secrets
import string


class HogarRepository:
    """Repository for household and membership data access."""
    
    def __init__(self, db: Session):
        self.db = db
    
    # ========== HOGAR OPERATIONS ==========
    
    def create_hogar(
        self, 
        nombre: str, 
        created_by: str, 
        icono: str = 'home'
    ) -> Hogar:
        """Create a new household with a unique invitation code."""
        codigo = self._generate_invitation_code()
        
        hogar = Hogar(
            nombre=nombre,
            created_by=created_by,
            icono=icono,
            codigo_invitacion=codigo
        )
        self.db.add(hogar)
        self.db.commit()
        self.db.refresh(hogar)
        return hogar
    
    def get_hogar_by_id(self, hogar_id: int) -> Optional[Hogar]:
        """Get household by ID."""
        return self.db.query(Hogar).filter(Hogar.id_hogar == hogar_id).first()
    
    def get_hogar_by_codigo(self, codigo: str) -> Optional[Hogar]:
        """Get household by invitation code."""
        return self.db.query(Hogar).filter(
            Hogar.codigo_invitacion == codigo.upper()
        ).first()
    
    def get_hogares_by_user(self, user_id: str) -> list[Hogar]:
        """Get all households where user is a member."""
        return (
            self.db.query(Hogar)
            .join(HogarMiembro)
            .filter(HogarMiembro.user_id == user_id)
            .order_by(Hogar.fecha_creacion.desc())
            .all()
        )
    
    def update_hogar(
        self, 
        hogar_id: int, 
        nombre: Optional[str] = None,
        icono: Optional[str] = None
    ) -> Optional[Hogar]:
        """Update household information."""
        hogar = self.get_hogar_by_id(hogar_id)
        if not hogar:
            return None
        
        if nombre is not None:
            hogar.nombre = nombre
        if icono is not None:
            hogar.icono = icono
        
        self.db.commit()
        self.db.refresh(hogar)
        return hogar
    
    def delete_hogar(self, hogar_id: int) -> bool:
        """Delete a household (cascade deletes members, locations, products, inventory)."""
        hogar = self.get_hogar_by_id(hogar_id)
        if not hogar:
            return False
        
        self.db.delete(hogar)
        self.db.commit()
        return True
    
    def regenerate_invitation_code(self, hogar_id: int) -> Optional[str]:
        """Generate a new invitation code for the household."""
        hogar = self.get_hogar_by_id(hogar_id)
        if not hogar:
            return None
        
        hogar.codigo_invitacion = self._generate_invitation_code()
        self.db.commit()
        return hogar.codigo_invitacion
    
    # ========== MIEMBRO OPERATIONS ==========
    
    def add_miembro(
        self,
        hogar_id: int,
        user_id: str,
        rol: str = 'miembro',
        apodo: Optional[str] = None
    ) -> Optional[HogarMiembro]:
        """Add a member to a household."""
        # Check if already a member
        existing = self.get_miembro(user_id, hogar_id)
        if existing:
            return None  # Already a member
        
        miembro = HogarMiembro(
            fk_hogar=hogar_id,
            user_id=user_id,
            rol=rol,
            apodo=apodo
        )
        self.db.add(miembro)
        self.db.commit()
        self.db.refresh(miembro)
        return miembro
    
    def get_miembro(self, user_id: str, hogar_id: int) -> Optional[HogarMiembro]:
        """Get membership information for a user in a household."""
        return self.db.query(HogarMiembro).filter(
            HogarMiembro.user_id == user_id,
            HogarMiembro.fk_hogar == hogar_id
        ).first()
    
    def get_miembros_by_hogar(self, hogar_id: int) -> list[HogarMiembro]:
        """Get all members of a household."""
        return (
            self.db.query(HogarMiembro)
            .filter(HogarMiembro.fk_hogar == hogar_id)
            .order_by(HogarMiembro.fecha_union)
            .all()
        )
    
    def update_miembro_rol(
        self, 
        user_id: str, 
        hogar_id: int, 
        nuevo_rol: str
    ) -> Optional[HogarMiembro]:
        """Update a member's role in a household."""
        miembro = self.get_miembro(user_id, hogar_id)
        if not miembro:
            return None
        
        miembro.rol = nuevo_rol
        self.db.commit()
        self.db.refresh(miembro)
        return miembro
    
    def update_miembro_apodo(
        self, 
        user_id: str, 
        hogar_id: int, 
        apodo: str
    ) -> Optional[HogarMiembro]:
        """Update a member's nickname in a household."""
        miembro = self.get_miembro(user_id, hogar_id)
        if not miembro:
            return None
        
        miembro.apodo = apodo
        self.db.commit()
        self.db.refresh(miembro)
        return miembro
    
    def remove_miembro(self, user_id: str, hogar_id: int) -> bool:
        """Remove a member from a household."""
        miembro = self.get_miembro(user_id, hogar_id)
        if not miembro:
            return False
        
        self.db.delete(miembro)
        self.db.commit()
        return True
    
    def user_is_member_of_hogar(self, user_id: str, hogar_id: int) -> bool:
        """Check if user is a member of the household."""
        return self.get_miembro(user_id, hogar_id) is not None
    
    def user_is_admin_of_hogar(self, user_id: str, hogar_id: int) -> bool:
        """Check if user is an admin of the household."""
        miembro = self.get_miembro(user_id, hogar_id)
        return miembro is not None and miembro.rol == 'admin'
    
    def count_admins(self, hogar_id: int) -> int:
        """Count admin members in a household."""
        return self.db.query(HogarMiembro).filter(
            HogarMiembro.fk_hogar == hogar_id,
            HogarMiembro.rol == 'admin'
        ).count()
    
    # ========== HELPER METHODS ==========
    
    def _generate_invitation_code(self) -> str:
        """Generate a unique 8-character invitation code."""
        while True:
            # Generate random 8-char code with uppercase letters and numbers
            codigo = ''.join(
                secrets.choice(string.ascii_uppercase + string.digits) 
                for _ in range(8)
            )
            # Check if it's unique
            existing = self.db.query(Hogar).filter(
                Hogar.codigo_invitacion == codigo
            ).first()
            if not existing:
                return codigo
