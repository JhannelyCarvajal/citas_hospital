from pydantic import BaseModel

class UsuarioLogin(BaseModel):
    ci: str

class UsuarioPass(BaseModel):
    usuario: str
    clave_actual: str
    clave_nueva: str
