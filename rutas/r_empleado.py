from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.empleado import EmpleadoBase, EmpleadoCreate, EmpleadoUpdate
from modelos import m_empleado
from configuracion.conexion import get_conn

router = APIRouter(prefix="/empleados", tags=["Empleados"])

@router.get("/", response_model=List[EmpleadoBase])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_empleado.get_all(conn)

@router.get("/{id}", response_model=EmpleadoBase)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_empleado.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return row

@router.post("/", response_model=EmpleadoBase, status_code=201)
async def create(data: EmpleadoCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_empleado.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=EmpleadoBase)
async def update(id: int, data: EmpleadoUpdate, conn: Connection = Depends(get_conn)):
    row = await m_empleado.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_empleado.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Empleado no encontrado")
    return None