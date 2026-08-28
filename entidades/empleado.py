from pydantic import BaseModel
from typing import Optional
from datetime import date

class EmpleadoBase(BaseModel):
    id_persona: int
    id_area: Optional[int] = None
    tipo_empleado: str  # 'medico', 'enfermero', etc.
    fecha_contratacion: Optional[date] = None
    fecha_terminacion: Optional[date] = None
    id_turno: Optional[int] = None
    sueldo_base: float = 0.0
    nmp: str = ""  # número de matrícula profesional

class EmpleadoCreate(EmpleadoBase):
    pass

class EmpleadoUpdate(BaseModel):
    id_area: Optional[int] = None
    tipo_empleado: Optional[str] = None
    fecha_contratacion: Optional[date] = None
    fecha_terminacion: Optional[date] = None
    id_turno: Optional[int] = None
    sueldo_base: Optional[float] = None
    nmp: Optional[str] = None
    activo: Optional[bool] = None