from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List, Optional
from datetime import date

from configuracion.conexion import get_conn
from entidades.e_catalogo import (
    EspecialidadCreate, EspecialidadOut,
    PersonaCreate, PersonaOut,
    EmpleadoCreate, EmpleadoOut,
    ServicioOut, AseguradoOut, AseguradoraOut,
)
from modelos.m_catalogos import (
    listar_especialidades, obtener_especialidad, crear_especialidad,
    listar_personas, obtener_persona, crear_persona,
    listar_empleados, obtener_empleado, crear_empleado,
    listar_medicos, listar_medicos_por_especialidad,
    listar_servicios, buscar_asegurado, listar_aseguradoras,
)

router = APIRouter(prefix="/api/catalogos", tags=["catalogos"])

@router.get("/especialidades", response_model=List[EspecialidadOut])
async def get_especialidades(conn: Connection = Depends(get_conn)):
    try:
        return await listar_especialidades(conn)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/especialidades/{id}", response_model=EspecialidadOut)
async def get_especialidad(id: int, conn: Connection = Depends(get_conn)):
    try:
        row = await obtener_especialidad(conn, id)
        if not row:
            raise HTTPException(status_code=404, detail="Especialidad no encontrada")
        return row
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/especialidades", response_model=EspecialidadOut)
async def post_especialidad(esp: EspecialidadCreate, conn: Connection = Depends(get_conn)):
    try:
        return await crear_especialidad(conn, esp.nombre_especialidad, esp.tipo.value, esp.descripcion)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/personas", response_model=List[PersonaOut])
async def get_personas(conn: Connection = Depends(get_conn)):
    try:
        return await listar_personas(conn)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/personas/{id}", response_model=PersonaOut)
async def get_persona(id: int, conn: Connection = Depends(get_conn)):
    try:
        row = await obtener_persona(conn, id)
        if not row:
            raise HTTPException(status_code=404, detail="Persona no encontrada")
        return row
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/personas", response_model=PersonaOut)
async def post_persona(persona: PersonaCreate, conn: Connection = Depends(get_conn)):
    try:
        return await crear_persona(
            conn, persona.ci, persona.nombres, persona.apellidos, persona.fecha_nacimiento,
            persona.genero, persona.telefono, persona.email, persona.direccion
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/empleados", response_model=List[EmpleadoOut])
async def get_empleados(conn: Connection = Depends(get_conn)):
    try:
        return await listar_empleados(conn)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/empleados/{id}", response_model=EmpleadoOut)
async def get_empleado(id: int, conn: Connection = Depends(get_conn)):
    try:
        row = await obtener_empleado(conn, id)
        if not row:
            raise HTTPException(status_code=404, detail="Empleado no encontrado")
        return row
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/empleados", response_model=EmpleadoOut)
async def post_empleado(empleado: EmpleadoCreate, conn: Connection = Depends(get_conn)):
    try:
        return await crear_empleado(
            conn, empleado.id_persona, empleado.id_area, empleado.tipo_empleado.value,
            empleado.fecha_contratacion, empleado.fecha_terminacion, empleado.id_turno,
            empleado.sueldo_base, empleado.nmp
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/medicos")
async def get_medicos(conn: Connection = Depends(get_conn)):
    try:
        return await listar_medicos(conn)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/medicos/{id_especialidad}")
async def get_medicos_por_especialidad(id_especialidad: int, conn: Connection = Depends(get_conn)):
    try:
        return await listar_medicos_por_especialidad(conn, id_especialidad)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/servicios", response_model=List[ServicioOut])
async def get_servicios(conn: Connection = Depends(get_conn)):
    try:
        return await listar_servicios(conn)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/asegurados/{ci}", response_model=AseguradoOut)
async def get_asegurado(ci: str, conn: Connection = Depends(get_conn)):
    try:
        row = await buscar_asegurado(conn, ci)
        if not row:
            raise HTTPException(status_code=404, detail="Asegurado no encontrado")
        return row
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/aseguradoras", response_model=List[AseguradoraOut])
async def get_aseguradoras(conn: Connection = Depends(get_conn)):
    try:
        return await listar_aseguradoras(conn)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
