from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from backend.conexion import get_conn
from backend.models.schemas import (
    PersonaCreate, PersonaResponse,
    EmpleadoCreate, EmpleadoResponse,
    EspecialidadCreate, EspecialidadResponse,
    HorarioCreate, HorarioResponse
)
from typing import List

router = APIRouter(prefix="/api/catalogos", tags=["catalogos"])

# ==================== ESPECIALIDADES ====================

@router.get("/especialidades", response_model=List[EspecialidadResponse])
async def listar_especialidades(conn: Connection = Depends(get_conn)):
    try:
        rows = await conn.fetch(
            "SELECT id_especialidad, nombre_especialidad, tipo, descripcion, activo "
            "FROM tespecialidad WHERE activo = TRUE ORDER BY nombre_especialidad"
        )
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/especialidades/{id}", response_model=EspecialidadResponse)
async def obtener_especialidad(id: int, conn: Connection = Depends(get_conn)):
    try:
        row = await conn.fetchrow(
            "SELECT id_especialidad, nombre_especialidad, tipo, descripcion, activo "
            "FROM tespecialidad WHERE id_especialidad = $1", id
        )
        if not row:
            raise HTTPException(status_code=404, detail="Especialidad no encontrada")
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/especialidades", response_model=EspecialidadResponse)
async def crear_especialidad(esp: EspecialidadCreate, conn: Connection = Depends(get_conn)):
    try:
        row = await conn.fetchrow(
            "INSERT INTO tespecialidad (id_especialidad, nombre_especialidad, tipo, descripcion) "
            "VALUES ($1, $2, $3, $4) RETURNING id_especialidad, nombre_especialidad, tipo, descripcion, activo",
            esp.id_especialidad, esp.nombre_especialidad, esp.tipo.value, esp.descripcion
        )
        return dict(row)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== PERSONAS ====================

@router.get("/personas", response_model=List[PersonaResponse])
async def listar_personas(conn: Connection = Depends(get_conn)):
    try:
        rows = await conn.fetch(
            "SELECT id_persona, ci, nombre, apellidos, fecha_nacimiento, genero, "
            "telefono, email, direccion, foto_url, fecha_creacion, activo "
            "FROM tpersonas WHERE activo = TRUE ORDER BY nombre, apellidos"
        )
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/personas/{id}", response_model=PersonaResponse)
async def obtener_persona(id: int, conn: Connection = Depends(get_conn)):
    try:
        row = await conn.fetchrow(
            "SELECT id_persona, ci, nombre, apellidos, fecha_nacimiento, genero, "
            "telefono, email, direccion, foto_url, fecha_creacion, activo "
            "FROM tpersonas WHERE id_persona = $1", id
        )
        if not row:
            raise HTTPException(status_code=404, detail="Persona no encontrada")
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/personas", response_model=PersonaResponse)
async def crear_persona(persona: PersonaCreate, conn: Connection = Depends(get_conn)):
    try:
        row = await conn.fetchrow(
            "INSERT INTO tpersonas (ci, nombre, apellidos, fecha_nacimiento, genero, telefono, email, direccion) "
            "VALUES ($1, $2, $3, $4, $5, $6, $7, $8) "
            "RETURNING id_persona, ci, nombre, apellidos, fecha_nacimiento, genero, "
            "telefono, email, direccion, foto_url, fecha_creacion, activo",
            persona.ci, persona.nombre, persona.apellidos, persona.fecha_nacimiento,
            persona.genero, persona.telefono, persona.email, persona.direccion
        )
        return dict(row)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== EMPLEADOS ====================

@router.get("/empleados", response_model=List[EmpleadoResponse])
async def listar_empleados(conn: Connection = Depends(get_conn)):
    try:
        rows = await conn.fetch(
            "SELECT id_empleado, id_persona, id_area, tipo_empleado, fecha_contratacion, "
            "fecha_terminacion, id_turno, sueldo_base, nmp, activo "
            "FROM templeados WHERE activo = TRUE ORDER BY id_empleado"
        )
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/empleados/{id}", response_model=EmpleadoResponse)
async def obtener_empleado(id: int, conn: Connection = Depends(get_conn)):
    try:
        row = await conn.fetchrow(
            "SELECT id_empleado, id_persona, id_area, tipo_empleado, fecha_contratacion, "
            "fecha_terminacion, id_turno, sueldo_base, nmp, activo "
            "FROM templeados WHERE id_empleado = $1", id
        )
        if not row:
            raise HTTPException(status_code=404, detail="Empleado no encontrado")
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/empleados", response_model=EmpleadoResponse)
async def crear_empleado(empleado: EmpleadoCreate, conn: Connection = Depends(get_conn)):
    try:
        row = await conn.fetchrow(
            "INSERT INTO templeados (id_persona, id_area, tipo_empleado, fecha_contratacion, "
            "fecha_terminacion, id_turno, sueldo_base, nmp) "
            "VALUES ($1, $2, $3, $4, $5, $6, $7, $8) "
            "RETURNING id_empleado, id_persona, id_area, tipo_empleado, fecha_contratacion, "
            "fecha_terminacion, id_turno, sueldo_base, nmp, activo",
            empleado.id_persona, empleado.id_area, empleado.tipo_empleado.value,
            empleado.fecha_contratacion, empleado.fecha_terminacion,
            empleado.id_turno, empleado.sueldo_base, empleado.nmp
        )
        return dict(row)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# ==================== MEDICOS (filtros) ====================

@router.get("/medicos")
async def listar_medicos(conn: Connection = Depends(get_conn)):
    try:
        rows = await conn.fetch(
            "SELECT e.id_empleado, p.nombre || ' ' || p.apellidos AS medico, "
            "e.nmp, e.tipo_empleado "
            "FROM templeados e "
            "JOIN tpersonas p ON p.id_persona = e.id_persona "
            "WHERE e.tipo_empleado = 'medico' AND e.activo = TRUE "
            "ORDER BY medico"
        )
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/medicos/{id_especialidad}")
async def listar_medicos_por_especialidad(id_especialidad: int, conn: Connection = Depends(get_conn)):
    try:
        rows = await conn.fetch(
            "SELECT e.id_empleado, p.nombre || ' ' || p.apellidos AS medico, "
            "e.nmp, esp.nombre_especialidad "
            "FROM templeados e "
            "JOIN tpersonas p ON p.id_persona = e.id_persona "
            "JOIN templeado_especialidades re ON re.id_empleado = e.id_empleado "
            "JOIN tespecialidad esp ON esp.id_especialidad = re.id_especialidad "
            "WHERE e.tipo_empleado = 'medico' AND e.activo = TRUE "
            "AND re.id_especialidad = $1 "
            "ORDER BY medico",
            id_especialidad
        )
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))