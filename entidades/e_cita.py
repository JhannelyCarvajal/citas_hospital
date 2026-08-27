from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime, time
from enum import Enum

class TipoPaciente(str, Enum):
    A = "A"
    P = "P"

class EstadoFicha(str, Enum):
    R = "R"
    C = "C"
    A = "A"
    N = "N"
    X = "X"

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
    tipo_paciente: TipoPaciente = TipoPaciente.P
    monto: Optional[float] = None
    metodo_pago: Optional[str] = None
    usuario_reg: str = ""

class FichaUpdate(BaseModel):
    estado: EstadoFicha
    observacion: Optional[str] = None

class CotizacionIn(BaseModel):
    id_especialidad: int
    id_servicio: int
    tipo_paciente: TipoPaciente = TipoPaciente.P
    monto: float

class CotizacionOut(BaseModel):
    id_especialidad: int
    especialidad: Optional[str] = None
    id_servicio: int
    servicio: Optional[str] = None
    tipo_paciente: str
    monto: float
    mensaje: str = ""

class PagoIn(BaseModel):
    metodo_pago: str
    monto: Optional[float] = None
    observacion: Optional[str] = None

class FichaOut(BaseModel):
    id_ficha: int
    nro_ficha: int
    id_persona: int
    ci_paciente: str
    tipo_paciente: Optional[str] = None
    tipo_desc: Optional[str] = None
    paciente: Optional[str] = None
    especialidad: Optional[str] = None
    medico: Optional[str] = None
    servicio: Optional[str] = None
    id_especialidad: Optional[int] = None
    id_medico: Optional[int] = None
    id_horario: Optional[int] = None
    fech_cita: Optional[date] = None
    hora_cita: Optional[time] = None
    estado: Optional[str] = None
    estado_desc: Optional[str] = None
    observacion: Optional[str] = None
    fech_reg: Optional[datetime] = None
    usuario_reg: Optional[str] = None

class HorarioDisponible(BaseModel):
    id_especialidad: int
    especialidad: str
    id_medico: int
    medico: str
    id_horario: int
    dia_semana: str
    turno: str
    hora_inicio: time
    hora_fin: time
    fichas_disponibles: int
