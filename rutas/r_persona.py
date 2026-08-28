from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import List
from entidades.persona import PersonaOut, PersonaCreate, PersonaUpdate, PersonaAseguradoOut
from modelos import m_persona
from configuracion.conexion import get_conn

router = APIRouter(prefix="/personas", tags=["Personas"])

@router.get("/", response_model=List[PersonaOut])
async def get_all(conn: Connection = Depends(get_conn)):
    return await m_persona.get_all(conn)

@router.get("/{ci}/asegurado", response_model=PersonaAseguradoOut)
async def get_asegurado(ci: str, conn: Connection = Depends(get_conn)):
    return await m_persona.es_asegurado(conn, ci)

@router.get("/{id}", response_model=PersonaOut)
async def get_by_id(id: int, conn: Connection = Depends(get_conn)):
    row = await m_persona.get_by_id(conn, id)
    if not row:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    return row

@router.post("/", response_model=PersonaOut, status_code=201)
async def create(data: PersonaCreate, conn: Connection = Depends(get_conn)):
    try:
        return await m_persona.create(conn, data.dict())
    except Exception as e:
        raise HTTPException(status_code=400, detail=str(e))

@router.put("/{id}", response_model=PersonaOut)
async def update(id: int, data: PersonaUpdate, conn: Connection = Depends(get_conn)):
    row = await m_persona.update(conn, id, data.dict(exclude_unset=True))
    if not row:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    return row

@router.delete("/{id}", status_code=204)
async def delete(id: int, conn: Connection = Depends(get_conn)):
    deleted = await m_persona.delete(conn, id)
    if not deleted:
        raise HTTPException(status_code=404, detail="Persona no encontrada")
    return None