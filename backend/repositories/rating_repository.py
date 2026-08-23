# backend/repositories/rating_repository.py
from sqlalchemy.orm import Session
from sqlalchemy import and_
from datetime import datetime
from models import ProductRating, Product
from schemas import ProductRatingCreate

class RatingRepository:
    def __init__(self, db: Session):
        self.db = db

    def get_user_rating(self, product_id: int, user_id: str) -> ProductRating | None:
        """Obtiene la valoración de un usuario específico sobre un producto."""
        return (
            self.db.query(ProductRating)
            .filter(
                and_(
                    ProductRating.fk_producto == product_id,
                    ProductRating.user_id == user_id
                )
            )
            .first()
        )

    def upsert_rating(
        self,
        product_id: int,
        user_id: str,
        hogar_id: int,
        rating_data: ProductRatingCreate
    ) -> ProductRating:
        """Crea o actualiza la valoración de un usuario para un producto."""
        rating = self.get_user_rating(product_id, user_id)
        
        if not rating:
            rating = ProductRating(
                fk_producto=product_id,
                user_id=user_id,
                hogar_id=hogar_id,
                puntuacion=rating_data.puntuacion,
                es_favorito=rating_data.es_favorito,
                nota=rating_data.nota,
                tags=rating_data.tags,
            )
            self.db.add(rating)
        else:
            rating.puntuacion = rating_data.puntuacion
            rating.es_favorito = rating_data.es_favorito
            rating.nota = rating_data.nota
            rating.tags = rating_data.tags
            rating.updated_at = datetime.utcnow()
            
        self.db.commit()
        self.db.refresh(rating)
        return rating

    def toggle_favorite(self, product_id: int, user_id: str, hogar_id: int) -> bool:
        """Alterna el estado de favorito para un producto. Si no existía valoración, crea una inicial."""
        rating = self.get_user_rating(product_id, user_id)
        
        if not rating:
            rating = ProductRating(
                fk_producto=product_id,
                user_id=user_id,
                hogar_id=hogar_id,
                puntuacion=5.0,  # Puntuación por defecto al marcar favorito sin reseña previa
                es_favorito=True,
            )
            self.db.add(rating)
            new_state = True
        else:
            rating.es_favorito = not rating.es_favorito
            rating.updated_at = datetime.utcnow()
            new_state = rating.es_favorito

        self.db.commit()
        return new_state

    def delete_rating(self, product_id: int, user_id: str) -> bool:
        """Elimina la valoración del usuario para un producto determinado."""
        rating = self.get_user_rating(product_id, user_id)
        if rating:
            self.db.delete(rating)
            self.db.commit()
            return True
        return False
