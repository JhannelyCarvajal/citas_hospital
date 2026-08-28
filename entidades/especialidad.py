from pydantic import BaseModel
from typing import Optional

class EspecialidadBase(BaseModel):
    id_especialidad: int
    nombre_especialidad: str
    tipo: str  # 'medica', 'enfermeria', etc.
    descripcion: Optional[str] = ""
    activo: bool = True

class EspecialidadCreate(BaseModel):
    id_especialidad: int
    nombre_especialidad: str
    tipo: str
    descripcion: Optional[str] = ""

class EspecialidadUpdate(BaseModel):
    nombre_especialidad: Optional[str] = None
    tipo: Optional[str] = None
    descripcion: Optional[str] = None
    activo: Optional[bool] = None