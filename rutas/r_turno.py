from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.turno import TurnoBase, TurnoCreate, TurnoUpdate
from modelos import m_turno
from configuracion.conexion import get_conn

router = APIRouter(prefix="/turnos", tags=["Turnos"])

@router.get("/", response_model=List[TurnoBase])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_turno.get_all(conn)

@router.get("/{id}", response_model=TurnoBase)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_turno.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    return row

@router.post("/", response_model=TurnoBase, status_code=201)
async def create(data: TurnoCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_turno.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=TurnoBase)
async def update(id: int, data: TurnoUpdate, conn: Connection = Depends(get_conn)):
    row = await m_turno.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_turno.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Turno no encontrado")
    return None