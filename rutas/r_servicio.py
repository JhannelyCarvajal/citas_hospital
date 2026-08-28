from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.servicio import ServicioBase, ServicioCreate, ServicioUpdate
from modelos import m_servicio
from configuracion.conexion import get_conn

router = APIRouter(prefix="/servicios", tags=["Servicios"])

@router.get("/", response_model=List[ServicioBase])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_servicio.get_all(conn)

@router.get("/{id}", response_model=ServicioBase)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_servicio.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    return row

@router.post("/", response_model=ServicioBase, status_code=201)
async def create(data: ServicioCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_servicio.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=ServicioBase)
async def update(id: int, data: ServicioUpdate, conn: Connection = Depends(get_conn)):
    row = await m_servicio.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_servicio.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Servicio no encontrado")
    return None