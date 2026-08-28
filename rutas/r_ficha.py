from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.ficha import FichaBase, FichaCreate, FichaUpdate
from modelos import m_ficha
from configuracion.conexion import get_conn

router = APIRouter(prefix="/fichas", tags=["Fichas"])

@router.get("/", response_model=List[FichaBase])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_ficha.get_all(conn)

@router.get("/{id}", response_model=FichaBase)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_ficha.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Ficha no encontrada")
    return row

@router.post("/", response_model=FichaBase, status_code=201)
async def create(data: FichaCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_ficha.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=FichaBase)
async def update(id: int, data: FichaUpdate, conn: Connection = Depends(get_conn)):
    row = await m_ficha.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Ficha no encontrada")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_ficha.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Ficha no encontrada")
    return None