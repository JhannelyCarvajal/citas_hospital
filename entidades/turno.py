from pydantic import BaseModel
from typing import Optional
from datetime import time

class TurnoBase(BaseModel):
    id_turno: int
    nombre_turno: str
    hora_inicio: time
    hora_fin: time
    activo: bool = True

class TurnoCreate(TurnoBase):
    pass

class TurnoUpdate(BaseModel):
    nombre_turno: Optional[str] = None
    hora_inicio: Optional[time] = None
    hora_fin: Optional[time] = None
    activo: Optional[bool] = None