from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List, Optional
from datetime import date
from entidades.emergencia import EmergenciaOut, EmergenciaCreate, EmergenciaUpdate
from modelos import m_emergencia
from configuracion.conexion import get_conn

router = APIRouter(prefix="/emergencias", tags=["Emergencias"])

@router.get("/", response_model=List[EmergenciaOut])
async def get_all(
    desde: Optional[date] = None,
    hasta: Optional[date] = None,
    tipo_ingreso: Optional[str] = None,
    prioridad: Optional[str] = None,
    estado: Optional[str] = None,
    medico: Optional[int] = None,
    conn: Connection = Depends(get_conn),
):
    return await m_emergencia.get_all(conn, desde, hasta, tipo_ingreso, prioridad, estado, medico)

@router.get("/{id}", response_model=EmergenciaOut)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_emergencia.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")
    return row

@router.post("/", response_model=EmergenciaOut, status_code=201)
async def create(data: EmergenciaCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_emergencia.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=EmergenciaOut)
async def update(id: int, data: EmergenciaUpdate, conn: Connection = Depends(get_conn)):
    row = await m_emergencia.update_estado(conn, id, data.estado)
    if not row:
        raise HTTPException(status_code=404, detail="Emergencia no encontrada")
    return row