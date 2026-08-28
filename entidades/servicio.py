from pydantic import BaseModel
from typing import Optional

class ServicioBase(BaseModel):
    id_servicio: int
    nombre_servicio: str
    descripcion: str = ""
    activo: bool = True

class ServicioCreate(ServicioBase):
    pass

class ServicioUpdate(BaseModel):
    nombre_servicio: Optional[str] = None
    descripcion: Optional[str] = None
    activo: Optional[bool] = None