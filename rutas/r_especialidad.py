from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.especialidad import EspecialidadBase, EspecialidadCreate, EspecialidadUpdate
from modelos import m_especialidad
from configuracion.conexion import get_conn

router = APIRouter(prefix="/especialidades", tags=["Especialidades"])

@router.get("/", response_model=List[EspecialidadBase])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_especialidad.get_all(conn)

@router.get("/medicos")
async def get_medicos_por_especialidad(conn: Connection = Depends(get_conn)):
    return await m_especialidad.medicos_por_especialidad(conn)

@router.get("/{id}", response_model=EspecialidadBase)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_especialidad.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Especialidad no encontrada")
    return row

@router.post("/", response_model=EspecialidadBase, status_code=201)
async def create(data: EspecialidadCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_especialidad.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=EspecialidadBase)
async def update(id: int, data: EspecialidadUpdate, conn: Connection = Depends(get_conn)):
    row = await m_especialidad.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Especialidad no encontrada")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_especialidad.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Especialidad no encontrada")
    return None