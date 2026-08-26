from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from backend.conexion import get_conn
from backend.models.schemas import (
    FichaCreate, FichaUpdate, FichaResponse,
    HorarioDisponible, ApiResponse
)
from typing import List, Optional
from datetime import date

router = APIRouter(prefix="/api/citas", tags=["citas"])

@router.get("/horarios-disponibles/{id_especialidad}")
async def get_horarios_disponibles(
    id_especialidad: int,
    fecha: Optional[date] = None,
    conn: Connection = Depends(get_conn)
):
    try:
        query = """
            SELECT * FROM fhorarios_disponibles($1, $2)
        """
        if fecha is None:
            fecha = date.today()
        
        rows = await conn.fetch(query, id_especialidad, fecha)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/fichas", response_model=dict)
async def crear_ficha(
    ficha: FichaCreate,
    conn: Connection = Depends(get_conn)
):
    try:
        query = """
            CALL pficha(
                1, 0, $1, $2, $3, $4, $5, $6, $7, 'R', $8, $9, NULL
            )
        """
        result = await conn.fetchval(
            query,
            ficha.id_persona,
            ficha.ci_paciente,
            ficha.id_especialidad,
            ficha.id_medico,
            ficha.id_horario,
            ficha.fech_cita,
            ficha.hora_cita,
            ficha.usuario_reg,
            ficha.observacion
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/fichas/{id_ficha}/estado")
async def cambiar_estado_ficha(
    id_ficha: int,
    update: FichaUpdate,
    conn: Connection = Depends(get_conn)
):
    try:
        query = """
            CALL pficha(
                2, $1, 0, '', 0, 0, 0, NULL, NULL, $2, '', $3, NULL
            )
        """
        result = await conn.fetchval(
            query,
            id_ficha,
            update.estado.value,
            update.observacion or ""
        )
        return result
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/fichas")
async def listar_fichas(
    fecha: Optional[date] = None,
    estado: Optional[str] = None,
    id_especialidad: Optional[int] = None,
    conn: Connection = Depends(get_conn)
):
    try:
        query = "SELECT * FROM v_fichas_dia WHERE 1=1"
        params = []
        param_count = 0
        
        if fecha:
            param_count += 1
            query += f" AND fech_cita = ${param_count}"
            params.append(fecha)
        
        if estado:
            param_count += 1
            query += f" AND estado = ${param_count}"
            params.append(estado)
        
        if id_especialidad:
            param_count += 1
            query += f" AND id_especialidad = ${param_count}"
            params.append(id_especialidad)
        
        query += " ORDER BY fech_cita DESC, hora_cita ASC"
        
        rows = await conn.fetch(query, *params)
        return [dict(row) for row in rows]
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/fichas/{id_ficha}")
async def obtener_ficha(
    id_ficha: int,
    conn: Connection = Depends(get_conn)
):
    try:
        query = "SELECT * FROM v_fichas_dia WHERE id_ficha = $1"
        row = await conn.fetchrow(query, id_ficha)
        if not row:
            raise HTTPException(status_code=404, detail="Ficha no encontrada")
        return dict(row)
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))