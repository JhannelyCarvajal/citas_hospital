from asyncpg import Connection
from typing import List, Optional
from datetime import date, time

from entidades.e_cita import FichaCreate

async def horarios_disponibles(conn: Connection, id_especialidad: int, fecha: date) -> List[dict]:
    rows = await conn.fetch(
        "SELECT * FROM fhorarios_disponibles($1, $2)",
        id_especialidad, fecha
    )
    return [dict(r) for r in rows]

async def _validar_horario(conn: Connection, ficha: FichaCreate):
    h = await conn.fetchrow(
        "SELECT hora_inicio, hora_fin, nro_fichas, dia_semana, id_empleado, activo "
        "FROM tc_horario WHERE id_horario = $1",
        ficha.id_horario
    )
    if not h or not h["activo"]:
        raise ValueError("El horario no existe o esta inactivo")
    if h["id_empleado"] != ficha.id_medico:
        raise ValueError("El horario no pertenece al medico indicado")
    if h["dia_semana"] != (ficha.fech_cita.isoweekday()):
        raise ValueError("El medico no atiende el dia de la fecha solicitada")
    if h["hora_inicio"] < h["hora_fin"]:
        if not (h["hora_inicio"] <= ficha.hora_cita <= h["hora_fin"]):
            raise ValueError(f"La hora {ficha.hora_cita} no esta dentro del horario {h['hora_inicio']} - {h['hora_fin']}")
    else:
        if not (ficha.hora_cita >= h["hora_inicio"] or ficha.hora_cita <= h["hora_fin"]):
            raise ValueError(f"La hora {ficha.hora_cita} no esta dentro del horario nocturno {h['hora_inicio']} - {h['hora_fin']}")
    ocupadas = await conn.fetchval(
        "SELECT COUNT(*) FROM tc_ficha WHERE id_horario = $1 AND fech_cita = $2 AND estado <> 'X'",
        ficha.id_horario, ficha.fech_cita
    )
    if ocupadas >= h["nro_fichas"]:
        raise ValueError(f"No hay fichas disponibles para ese horario (cupo {h['nro_fichas']})")

async def crear_ficha(conn: Connection, ficha: FichaCreate, usuario_reg: str) -> dict:
    await _validar_horario(conn, ficha)

    ci_aseg = await conn.fetchval(
        "SELECT ci FROM tp_asegurado WHERE ci = $1 AND estado = TRUE", ficha.ci_paciente
    )
    tipo = "A" if ci_aseg else "P"
    # Asegurado: ficha valida de inmediato. Particular: pendiente de pago.
    estado = "C" if tipo == "A" else "R"

    nro_ficha = await conn.fetchval(
        "SELECT COALESCE(MAX(nro_ficha), 0) + 1 FROM tc_ficha WHERE fech_cita = $1",
        ficha.fech_cita
    )

    observacion = ficha.observacion or ""
    if tipo == "P":
        monto = ficha.monto if ficha.monto is not None else 0
        observacion = f"MONTO:{monto}|PAGO:PENDIENTE|{observacion}".rstrip("|")

    id_ficha = await conn.fetchval(
        "INSERT INTO tc_ficha (nro_ficha, id_persona, ci_paciente, tipo_paciente, id_asegurado, "
        "id_medico, id_especialidad, id_horario, id_servicio, fech_cita, hora_cita, "
        "estado, observacion, usuario_reg) "
        "VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) "
        "RETURNING id_ficha",
        nro_ficha, ficha.id_persona, ficha.ci_paciente, tipo, ci_aseg,
        ficha.id_medico, ficha.id_especialidad, ficha.id_horario, ficha.id_servicio,
        ficha.fech_cita, ficha.hora_cita, estado, observacion, usuario_reg
    )

    mensaje = "Ficha registrada correctamente"
    if tipo == "P":
        mensaje = "Ficha registrada. Envie al paciente a pagar para validarla."
    return {
        "success": True,
        "id_ficha": id_ficha,
        "nro_ficha": nro_ficha,
        "tipo_paciente": tipo,
        "estado": estado,
        "mensaje": mensaje,
    }

async def cambiar_estado_ficha(conn: Connection, id_ficha: int, estado: str, observacion: Optional[str] = None):
    if observacion is None:
        filas = await conn.execute(
            "UPDATE tc_ficha SET estado = $1 WHERE id_ficha = $2",
            estado, id_ficha
        )
    else:
        filas = await conn.execute(
            "UPDATE tc_ficha SET estado = $1, observacion = $2 WHERE id_ficha = $3",
            estado, observacion, id_ficha
        )
    if filas == "UPDATE 0":
        return {"success": False, "mensaje": "Ficha no encontrada"}
    return {"success": True, "mensaje": "Estado de ficha actualizado"}

async def cotizar(conn: Connection, id_especialidad: int, id_servicio: int,
                  monto: float, tipo_paciente: str) -> dict:
    serv = await conn.fetchrow(
        "SELECT nombre_servicio FROM tc_servicios WHERE id_servicio = $1 AND activo = TRUE", id_servicio
    )
    esp = await conn.fetchrow(
        "SELECT nombre_especialidad FROM tp_especialidades WHERE id_especialidad = $1", id_especialidad
    )
    if not serv:
        raise ValueError("Servicio no encontrado o inactivo")
    if not esp:
        raise ValueError("Especialidad no encontrada")
    return {
        "id_especialidad": id_especialidad,
        "especialidad": esp["nombre_especialidad"],
        "id_servicio": id_servicio,
        "servicio": serv["nombre_servicio"],
        "tipo_paciente": tipo_paciente,
        "monto": monto,
        "mensaje": "Cotizacion generada",
    }

async def pagar_ficha(conn: Connection, id_ficha: int, metodo_pago: str,
                      monto: Optional[float] = None, observacion: Optional[str] = None) -> dict:
    f = await obtener_ficha(conn, id_ficha)
    if not f:
        raise ValueError("Ficha no encontrada")
    if f.get("tipo_paciente") != "P":
        raise ValueError("Solo las fichas de particulares requieren registro de pago")
    if f.get("estado") == "C":
        return {"success": True, "id_ficha": id_ficha, "estado": "C", "mensaje": "Ficha ya pagada/valida"}

    obs_actual = f.get("observacion") or ""
    obs_nueva = obs_actual.replace("PAGO:PENDIENTE", f"PAGO:OK|METODO:{metodo_pago}")
    if monto is not None and "MONTO:" not in obs_nueva:
        obs_nueva = obs_nueva + f"|MONTO:{monto}"
    if observacion:
        obs_nueva = obs_nueva + f"|{observacion}"
    obs_nueva = obs_nueva.rstrip("|")

    await conn.execute(
        "UPDATE tc_ficha SET estado = 'C', observacion = $1 WHERE id_ficha = $2",
        obs_nueva, id_ficha
    )
    return {
        "success": True,
        "id_ficha": id_ficha,
        "estado": "C",
        "mensaje": "Pago registrado. Ficha valida para atencion.",
    }

async def listar_fichas(conn: Connection, fecha: Optional[date] = None,
                        estado: Optional[str] = None,
                        id_especialidad: Optional[int] = None) -> List[dict]:
    query = "SELECT * FROM v_fichas_dia WHERE 1=1"
    params = []
    i = 0
    if fecha:
        i += 1
        query += f" AND fech_cita = ${i}"
        params.append(fecha)
    if estado:
        i += 1
        query += f" AND estado = ${i}"
        params.append(estado)
    if id_especialidad:
        i += 1
        query += f" AND id_especialidad = ${i}"
        params.append(id_especialidad)
    query += " ORDER BY fech_cita DESC, hora_cita ASC"
    rows = await conn.fetch(query, *params)
    return [dict(r) for r in rows]

async def obtener_ficha(conn: Connection, id_ficha: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM v_fichas_dia WHERE id_ficha = $1", id_ficha)
    return dict(row) if row else None
