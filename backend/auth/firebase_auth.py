# backend/auth/firebase_auth.py

import os
import firebase_admin
from firebase_admin import credentials, auth
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer

# Carga las credenciales de servicio de Firebase.
# DEBES descargar este archivo JSON desde tu proyecto de Firebase
# y asegurarte de que esté disponible para tu backend.
# Es una BUENA PRÁCTICA cargar la ruta desde una variable de entorno.
cred_path = os.getenv("FIREBASE_SERVICE_ACCOUNT_KEY_PATH", "backend/secrets/serviceAccountKey.json")

if os.path.exists(cred_path):
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
else:
    print("ADVERTENCIA: No se encontró el archivo de credenciales de Firebase. La autenticación no funcionará.")

# Este esquema le dice a FastAPI que busque un token en la cabecera "Authorization: Bearer <token>"
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

def get_current_user(token: str = Depends(oauth2_scheme)):
    """
    Dependencia de FastAPI para verificar el token de Firebase y obtener los datos del usuario.
    """
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except auth.InvalidIdTokenError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Token inválido")
    except Exception:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="No se pudo verificar el token")