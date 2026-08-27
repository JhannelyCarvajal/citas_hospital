# Archivo seguridad/s_jwt.py
import jwt
from datetime import datetime, timedelta, timezone
from configuracion.parametros import config

ALGORITHM = "HS256"

    ### **************************************************************
    ### Genera un token
    ### **************************************************************
def generar_token(data: dict) -> str:
    print(config)
    payload = data.copy()
    expiracion = datetime.now(timezone.utc) + timedelta(minutes=config.jwt_expira_minutos)
    payload.update({"exp": expiracion})
    return jwt.encode(payload, config.jwt_secret, algorithm=ALGORITHM)

    ### **************************************************************
    ### Verifica y decodifica un token recibido
    ### **************************************************************
def verificar_token(token: str) -> dict:
    try:
        return jwt.decode(token, 
                          config.jwt_secret, 
                          algorithms=[ALGORITHM]
                          )
    except jwt.ExpiredSignatureError:
        raise ValueError("El token ha expirado")
    except jwt.InvalidTokenError:
        raise ValueError("Token inválido")

# NOTA: el archivo tambien tiene codigo comentado que mostraba una version
# anterior usando python-jose (from jose import jwt, JWTError).
# La version activa usa pyjwt (import jwt).
