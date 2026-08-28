from pydantic import BaseModel
from typing import Optional
from datetime import date, time

class FichaBase(BaseModel):
    id_ficha: int
    nro_ficha: int
    id_persona: int
    ci_paciente: str
    tipo_paciente: str = "Particular"  # 'Asegurado' o 'Particular'
    id_asegurado: Optional[str] = None
    id_medico: int
    id_especialidad: int
    id_horario: int
    id_servicio: Optional[int] = None
    fech_cita: date
    hora_cita: time
    estado: str = "Registrada"
    observacion: str = ""
    usuario_reg: str = ""

class FichaCreate(BaseModel):
    id_persona: int
    ci_paciente: str
    id_medico: int
    id_especialidad: int
    id_horario: int
    id_servicio: Optional[int] = None
    fech_cita: date
    hora_cita: time
    observacion: str = ""
    usuario_reg: str = ""
    como_particular: bool = False

class FichaUpdate(BaseModel):
    estado: Optional[str] = None
    observacion: Optional[str] = None