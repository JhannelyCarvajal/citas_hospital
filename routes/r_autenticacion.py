from fastapi import APIRouter, HTTPException, Depends
from asyncpg import Connection

from entidades.e_usuario import UsuarioLogin
from modelos import m_autenticacion
from configuracion.conexion import get_conn
from servicios.s_jwt import generar_token
from servicios.s_auth import usuario_actual

router = APIRouter(prefix="/api/auth", tags=["auth"])

# Login: verifica la persona por CI y emite un token JWT
@router.post("/login")
async def login(usuario: UsuarioLogin, conn: Connection = Depends(get_conn)):
    try:
        datos = await m_autenticacion.verifica_usuario(usuario.ci, conn)

        if not datos["resultado"]:
            if datos["motivo"] == "inactivo":
                raise HTTPException(status_code=403, detail=datos["mensaje"])
            raise HTTPException(status_code=401, detail=datos["mensaje"])

        token = generar_token({
            "sub": datos["usuario"],
            "id_persona": datos["id_persona"],
            "nombre": datos["nombre"],
            "tipo_paciente": datos["tipo_paciente"],
        })

        return {
            "mensaje": datos["mensaje"],
            "usuario": datos["usuario"],
            "nombre": datos["nombre"],
            "tipo_paciente": datos["tipo_paciente"],
            "token": token,
            "status": 200,
        }
    except HTTPException:
        raise
    except Exception as e:
        print(f"Error en autenticacion: {e}")
        raise HTTPException(status_code=400, detail="Se presento un problema en la autenticacion")

# Devuelve los datos del usuario logueado (a partir del token)
@router.get("/me")
async def me(usuario: dict = Depends(usuario_actual)):
    return usuario
