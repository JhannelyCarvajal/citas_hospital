from pydantic import BaseModel
from typing import Optional
from datetime import time

class HorarioBase(BaseModel):
    id_horario: int
    id_empleado: int
    dia_semana: int  # 1=Lunes, ..., 7=Domingo
    id_turno: int
    hora_inicio: time
    hora_fin: time
    nro_fichas: int = 5
    activo: bool = True

class HorarioCreate(HorarioBase):
    pass

class HorarioUpdate(BaseModel):
    id_empleado: Optional[int] = None
    dia_semana: Optional[int] = None
    id_turno: Optional[int] = None
    hora_inicio: Optional[time] = None
    hora_fin: Optional[time] = None
    nro_fichas: Optional[int] = None
    activo: Optional[bool] = None