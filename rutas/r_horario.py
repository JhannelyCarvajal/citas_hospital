from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.horario import HorarioBase, HorarioCreate, HorarioUpdate
from modelos import m_horario
from configuracion.conexion import get_conn

router = APIRouter(prefix="/horarios", tags=["Horarios"])

@router.get("/", response_model=List[HorarioBase])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_horario.get_all(conn)

@router.get("/{id}", response_model=HorarioBase)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_horario.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Horario no encontrado")
    return row

@router.post("/", response_model=HorarioBase, status_code=201)
async def create(data: HorarioCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_horario.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=HorarioBase)
async def update(id: int, data: HorarioUpdate, conn: Connection = Depends(get_conn)):
    row = await m_horario.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Horario no encontrado")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_horario.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Horario no encontrado")
    return None