from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from servicios.s_jwt import verificar_token

bearer_scheme = HTTPBearer()

### **************************************************************
### Dependencia que valida el token y devuelve los datos del usuario
### Úsala en cualquier endpoint que requiera estar logueado
### **************************************************************
async def usuario_actual(credenciales: HTTPAuthorizationCredentials = Depends(bearer_scheme)) -> dict:
    token = credenciales.credentials
    try:
        payload = verificar_token(token)
        return payload  # contiene: sub, id_usuario, id_grupo
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e),
            headers={"WWW-Authenticate": "Bearer"},
        )
