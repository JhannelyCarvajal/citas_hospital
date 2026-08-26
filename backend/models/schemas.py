from pydantic import BaseModel, Field
from typing import Optional
from datetime import datetime, date, time
from enum import Enum

class TipoPaciente(str, Enum):
    A = "A"  # Asegurado
    P = "P"  # Particular

class EstadoFicha(str, Enum):
    R = "R"  # Registrada
    C = "C"  # Confirmada
    A = "A"  # Atendida
    N = "N"  # No asistio
    X = "X"  # Cancelada

class TipoEspecialidad(str, Enum):
    medica = "medica"
    enfermeria = "enfermeria"
    apoyo = "apoyo"
    administrativa = "administrativa"

class TipoEmpleado(str, Enum):
    medico = "medico"
    enfermero = "enfermero"
    administrativo = "administrativo"
    auxiliar = "auxiliar"
    otro = "otro"

# Modelos para Fichas (Citas)
class FichaBase(BaseModel):
    ci_paciente: str
    id_especialidad: int
    id_medico: int
    id_horario: int
    id_servicio: Optional[int] = None
    fech_cita: date
    hora_cita: time
    observacion: str = ""

class FichaCreate(FichaBase):
    id_persona: int
    usuario_reg: str = ""

class FichaUpdate(BaseModel):
    estado: EstadoFicha
    observacion: Optional[str] = None

class FichaResponse(FichaBase):
    id_ficha: int
    nro_ficha: int
    tipo_paciente: TipoPaciente
    id_asegurado: Optional[str] = None
    estado: EstadoFicha
    fech_reg: datetime
    usuario_reg: str

    class Config:
        from_attributes = True

# Modelos para Horarios
class HorarioBase(BaseModel):
    id_empleado: int
    dia_semana: int = Field(..., ge=1, le=7)
    id_turno: int
    hora_inicio: time
    hora_fin: time
    nro_fichas: int = 5

class HorarioCreate(HorarioBase):
    pass

class HorarioResponse(HorarioBase):
    id_horario: int
    activo: bool

    class Config:
        from_attributes = True

# Modelos para Personas
class PersonaBase(BaseModel):
    ci: str
    nombre: str
    apellidos: str = ""
    fecha_nacimiento: Optional[date] = None
    genero: Optional[str] = None
    telefono: str = ""
    email: str = ""
    direccion: Optional[str] = None

class PersonaCreate(PersonaBase):
    pass

class PersonaResponse(PersonaBase):
    id_persona: int
    fecha_creacion: datetime
    activo: bool

    class Config:
        from_attributes = True

# Modelos para Empleados
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

class EmpleadoResponse(EmpleadoBase):
    id_empleado: int
    activo: bool

    class Config:
        from_attributes = True

# Modelos para Especialidades
class EspecialidadBase(BaseModel):
    nombre_especialidad: str
    tipo: TipoEspecialidad = TipoEspecialidad.medica
    descripcion: str = ""

class EspecialidadCreate(EspecialidadBase):
    id_especialidad: int

class EspecialidadResponse(EspecialidadBase):
    id_especialidad: int
    activo: bool

    class Config:
        from_attributes = True

# Modelos para respuesta generica
class ApiResponse(BaseModel):
    success: bool
    message: str
    data: Optional[dict] = None

# Modelo para horarios disponibles
class HorarioDisponible(BaseModel):
    id_especialidad: int
    especialidad: str
    id_medico: int
    medico: str
    nmp: str
    id_horario: int
    dia_semana: str
    turno: str
    hora_inicio: time
    hora_fin: time
    fichas_disponibles: int