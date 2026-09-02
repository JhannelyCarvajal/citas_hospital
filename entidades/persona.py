from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime

class PersonaBase(BaseModel):
    ci: str
    nombres: str
    apellidos: str = ""
    fecha_nacimiento: Optional[date] = None
    genero: Optional[str] = None  # 'F' o 'M'
    telefono: str = ""
    email: str = ""
    direccion: Optional[str] = None

class PersonaCreate(PersonaBase):
    pass

class PersonaOut(PersonaBase):
    id_persona: int

class PersonaUpdate(BaseModel):
    nombres: Optional[str] = None
    apellidos: Optional[str] = None
    fecha_nacimiento: Optional[date] = None
    genero: Optional[str] = None
    telefono: Optional[str] = None
    email: Optional[str] = None
    direccion: Optional[str] = None
    activo: Optional[bool] = None

class PersonaAseguradoOut(BaseModel):
    ci: str
    es_asegurado: bool
    nombre: Optional[str] = None
    nombre_aseguradora: Optional[str] = None
    nro_poliza: Optional[str] = None
    fech_fin: Optional[date] = None
    vencido: bool = False