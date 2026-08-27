from fastapi import APIRouter, Depends, HTTPException
from asyncpg import Connection
from typing import Optional
from datetime import date

from configuracion.conexion import get_conn
from servicios.s_auth import usuario_actual
from entidades.e_cita import (
    FichaCreate, FichaUpdate, FichaOut, HorarioDisponible,
    CotizacionIn, CotizacionOut, PagoIn,
)
from modelos.m_citas import (
    horarios_disponibles, crear_ficha, cambiar_estado_ficha,
    listar_fichas, obtener_ficha, cotizar, pagar_ficha,
)

router = APIRouter(prefix="/api/citas", tags=["citas"])

@router.get("/horarios-disponibles/{id_especialidad}")
async def get_horarios_disponibles(
    id_especialidad: int,
    fecha: Optional[date] = None,
    conn: Connection = Depends(get_conn),
):
    try:
        if fecha is None:
            fecha = date.today()
        rows = await horarios_disponibles(conn, id_especialidad, fecha)
        return rows
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/fichas")
async def post_ficha(ficha: FichaCreate, usuario: dict = Depends(usuario_actual), conn: Connection = Depends(get_conn)):
    try:
        resultado = await crear_ficha(conn, ficha, ficha.usuario_reg)
        return resultado
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.put("/fichas/{id_ficha}/estado")
async def put_estado_ficha(id_ficha: int, update: FichaUpdate, usuario: dict = Depends(usuario_actual), conn: Connection = Depends(get_conn)):
    try:
        resultado = await cambiar_estado_ficha(conn, id_ficha, update.estado.value, update.observacion)
        return resultado
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/cotizar", response_model=CotizacionOut)
async def post_cotizar(c: CotizacionIn, usuario: dict = Depends(usuario_actual), conn: Connection = Depends(get_conn)):
    try:
        return await cotizar(conn, c.id_especialidad, c.id_servicio, c.monto, c.tipo_paciente.value)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/fichas/{id_ficha}/pagar")
async def post_pagar_ficha(id_ficha: int, pago: PagoIn, usuario: dict = Depends(usuario_actual), conn: Connection = Depends(get_conn)):
    try:
        return await pagar_ficha(conn, id_ficha, pago.metodo_pago, pago.monto, pago.observacion)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/fichas", response_model=Optional[list])
async def get_fichas(
    fecha: Optional[date] = None,
    estado: Optional[str] = None,
    id_especialidad: Optional[int] = None,
    conn: Connection = Depends(get_conn),
):
    try:
        return await listar_fichas(conn, fecha, estado, id_especialidad)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get("/fichas/{id_ficha}", response_model=FichaOut)
async def get_ficha(id_ficha: int, conn: Connection = Depends(get_conn)):
    try:
        row = await obtener_ficha(conn, id_ficha)
        if not row:
            raise HTTPException(status_code=404, detail="Ficha no encontrada")
        return row
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
