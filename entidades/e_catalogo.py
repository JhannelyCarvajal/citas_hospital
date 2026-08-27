from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime
from enum import Enum

class TipoEspecialidad(str, Enum):
    Medica = "Medica"
    Enfermeria = "Enfermeria"
    Apoyo = "Apoyo"
    Administrativa = "Administrativa"

class TipoEmpleado(str, Enum):
    Medico = "Medico"
    Enfermero = "Enfermero"
    Administrativo = "Administrativo"
    Auxiliar = "Auxiliar"
    Otro = "Otro"

class EspecialidadBase(BaseModel):
    nombre_especialidad: str
    tipo: TipoEspecialidad = TipoEspecialidad.Medica
    descripcion: str = ""

class EspecialidadCreate(EspecialidadBase):
    pass

class EspecialidadOut(EspecialidadBase):
    id_especialidad: int
    activo: bool
    class Config:
        from_attributes = True

class PersonaBase(BaseModel):
    ci: str
    nombres: str
    apellidos: str = ""
    fecha_nacimiento: Optional[date] = None
    genero: Optional[str] = None
    telefono: str = ""
    email: str = ""
    direccion: Optional[str] = None

class PersonaCreate(PersonaBase):
    pass

class PersonaOut(PersonaBase):
    id_persona: int
    fecha_creacion: datetime
    activo: bool
    class Config:
        from_attributes = True

class EmpleadoBase(BaseModel):
    id_persona: int
    id_area: Optional[int] = None
    tipo_empleado: TipoEmpleado
    fecha_contratacion: Optional[date] = None
    fecha_terminacion: Optional[date] = None
    id_turno: Optional[int] = None
    sueldo_base: float = 0
    nmp: str = ""

class EmpleadoCreate(EmpleadoBase):
    pass

class EmpleadoOut(EmpleadoBase):
    id_empleado: int
    activo: bool
    class Config:
        from_attributes = True

class ServicioOut(BaseModel):
    id_servicio: int
    nombre_servicio: str
    descripcion: str = ""
    activo: bool
    class Config:
        from_attributes = True

class AseguradoraOut(BaseModel):
    id_aseguradora: int
    nombre: str
    nit: Optional[str] = None
    telefono: Optional[str] = None
    direccion: Optional[str] = None
    activo: bool
    class Config:
        from_attributes = True

class AseguradoOut(BaseModel):
    ci: str
    id_aseguradora: int
    aseguradora: Optional[str] = None
    nombre: str
    paterno: str = ""
    materno: str = ""
    nro_poliza: str = ""
    fech_afiliacion: Optional[date] = None
    estado: bool
    class Config:
        from_attributes = True
