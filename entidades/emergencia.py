from pydantic import BaseModel
from typing import Optional
from datetime import date, datetime

class EmergenciaOut(BaseModel):
    id: int
    id_paciente: int
    ci_paciente: str
    paciente: str
    tipo_seguro: str
    id_medico: int
    medico: str
    id_enfermero: int
    registrado_por: str
    tipo_ingreso: str
    estado: str
    prioridad_color: str
    id_trazabilidad: Optional[str] = None
    fecha_apertura: Optional[datetime] = None
    fecha_evaluacion: Optional[datetime] = None
    fecha_cierre: Optional[datetime] = None
    presion_sistolica: Optional[int] = None
    presion_diastolica: Optional[int] = None
    frecuencia_cardiaca: Optional[int] = None
    frecuencia_respiratoria: Optional[int] = None
    saturacion_oxigeno: Optional[int] = None
    temperatura: Optional[float] = None
    escala_glasgow: Optional[int] = None
    nivel_dolor: Optional[int] = None
    tiempo_espera_max_min: Optional[int] = None

class EmergenciaCreate(BaseModel):
    ci_paciente: str
    id_medico: int
    id_enfermero: int
    tipo_ingreso: str = "Urgencias"
    estado: str = "Admisión"
    prioridad_color: str
    fecha: Optional[date] = None
    hora: Optional[str] = None
    presion_sistolica: int
    presion_diastolica: int
    frecuencia_cardiaca: int
    frecuencia_respiratoria: int
    saturacion_oxigeno: int
    temperatura: float
    escala_glasgow: int
    nivel_dolor: int
    tiempo_espera_max_min: int = 0

class EmergenciaUpdate(BaseModel):
    estado: Optional[str] = None
    fecha_cierre: Optional[datetime] = None