from asyncpg import Connection
from datetime import date, datetime, time
from typing import List, Optional

_BASE = """
SELECT a.id,
       a.paciente_id AS id_paciente,
       p.ci AS ci_paciente,
       p.nombre || ' ' || p.apellidos AS paciente,
       CASE WHEN a2.ci IS NOT NULL AND a2.fech_fin IS NOT NULL AND a2.fech_fin < CURRENT_DATE THEN 'Asegurado vencido'
            WHEN a2.ci IS NOT NULL THEN 'Asegurado'
            ELSE 'Particular' END AS tipo_seguro,
       a.medico_id AS id_medico,
       a.id_trazabilidad,
       a.tipo_ingreso,
       a.estado,
       a.fecha_apertura,
       a.fecha_cierre,
       t.enfermero_id AS id_enfermero,
       t.prioridad_color,
       t.fecha_evaluacion,
       t.presion_sistolica,
       t.presion_diastolica,
       t.frecuencia_cardiaca,
       t.frecuencia_respiratoria,
       t.saturacion_oxigeno,
       t.temperatura,
       t.escala_glasgow,
       t.nivel_dolor,
       t.tiempo_espera_max_min,
       COALESCE(mp.nombres || ' ' || mp.apellidos, '') AS medico,
       COALESCE(ep.nombres || ' ' || ep.apellidos, '') AS registrado_por
  FROM ta_atenciones_medicas a
  JOIN ta_pacientes p ON p.id = a.paciente_id
  LEFT JOIN ta_triajes t ON t.atencion_id = a.id
  LEFT JOIN tp_empleados m ON m.id_empleado = a.medico_id
  LEFT JOIN tp_personas mp ON mp.id_persona = m.id_persona
  LEFT JOIN tp_empleados e2 ON e2.id_empleado = t.enfermero_id
  LEFT JOIN tp_personas ep ON ep.id_persona = e2.id_persona
  LEFT JOIN tp_asegurado a2 ON a2.ci = p.ci AND a2.estado = TRUE
"""

async def _conexion_por_id(conn: Connection, id_atencion: int) -> Optional[dict]:
    row = await conn.fetchrow(_BASE + "WHERE a.id = $1", id_atencion)
    return dict(row) if row else None

async def get_all(
    conn: Connection,
    desde: Optional[date] = None,
    hasta: Optional[date] = None,
    tipo_ingreso: Optional[str] = None,
    prioridad: Optional[str] = None,
    estado: Optional[str] = None,
    medico: Optional[int] = None,
) -> List[dict]:
    sql = _BASE + "WHERE 1 = 1"
    params = []

    if desde:
        params.append(datetime.combine(desde, time.min))
        sql += " AND a.fecha_apertura >= $" + str(len(params))
    if hasta:
        params.append(datetime.combine(hasta, time.max))
        sql += " AND a.fecha_apertura <= $" + str(len(params))
    if tipo_ingreso:
        params.append(tipo_ingreso)
        sql += " AND a.tipo_ingreso = $" + str(len(params))
    if prioridad:
        params.append(prioridad)
        sql += " AND t.prioridad_color = $" + str(len(params))
    if estado:
        params.append(estado)
        sql += " AND a.estado = $" + str(len(params))
    if medico:
        params.append(medico)
        sql += " AND a.medico_id = $" + str(len(params))

    sql += " ORDER BY a.fecha_apertura DESC, a.id DESC"
    rows = await conn.fetch(sql, *params)
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_atencion: int) -> Optional[dict]:
    return await _conexion_por_id(conn, id_atencion)

async def create(conn: Connection, data: dict) -> dict:
    ci = (data['ci_paciente'] or '').strip()
    if not ci:
        raise ValueError("El CI del paciente es obligatorio")

    persona = await conn.fetchrow(
        "SELECT ci, nombres, apellidos, fecha_nacimiento, genero, telefono FROM tp_personas WHERE ci = $1",
        ci
    )
    if not persona:
        raise ValueError("La persona no esta registrada")

    medico = await conn.fetchrow(
        "SELECT id_empleado FROM tp_empleados WHERE id_empleado = $1", data['id_medico']
    )
    if not medico:
        raise ValueError("El medico indicado no existe")

    reg = await conn.fetchrow(
        "SELECT id_empleado FROM tp_empleados WHERE id_empleado = $1", data['id_enfermero']
    )
    if not reg:
        raise ValueError("El encargado que registra no existe")

    fecha = data.get('fecha') or date.today()
    hora = data.get('hora')
    if hora:
        hh, mm = [int(x) for x in str(hora).split(':')[:2]]
        apertura = datetime.combine(fecha, time(hh, mm))
    else:
        apertura = datetime.now()

    async with conn.transaction():
        paciente = await conn.fetchrow("SELECT id FROM ta_pacientes WHERE ci = $1", ci)
        if not paciente:
            paciente = await conn.fetchrow(
                """INSERT INTO ta_pacientes (ci, nombre, apellidos, fecha_nacimiento, genero, tipo_seguro, telefono)
                   VALUES ($1, $2, $3, $4, $5, 'Particular', $6) RETURNING id""",
                ci,
                (persona['nombres'] or ''),
                (persona['apellidos'] or ''),
                persona['fecha_nacimiento'],
                persona['genero'] or 'O',
                persona['telefono'] or '',
            )

        trazabilidad = "EM-" + datetime.now().strftime("%Y%m%d%H%M%S")
        atencion = await conn.fetchrow(
            """INSERT INTO ta_atenciones_medicas (medico_id, id_trazabilidad, tipo_ingreso, estado, fecha_apertura, paciente_id)
               VALUES ($1, $2, $3, $4, $5, $6) RETURNING id""",
            data['id_medico'],
            trazabilidad,
            data.get('tipo_ingreso', 'Urgencias'),
            data.get('estado', 'Admisión'),
            apertura,
            paciente['id'],
        )

        await conn.execute(
            """INSERT INTO ta_triajes (enfermero_id,
                   presion_sistolica, presion_diastolica, frecuencia_cardiaca,
                   frecuencia_respiratoria, saturacion_oxigeno, temperatura,
                   escala_glasgow, nivel_dolor, prioridad_color,
                   tiempo_espera_max_min, fecha_evaluacion, atencion_id)
               VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)""",
            data['id_enfermero'],
            data['presion_sistolica'],
            data['presion_diastolica'],
            data['frecuencia_cardiaca'],
            data['frecuencia_respiratoria'],
            data['saturacion_oxigeno'],
            data['temperatura'],
            data['escala_glasgow'],
            data['nivel_dolor'],
            data['prioridad_color'],
            data.get('tiempo_espera_max_min', 0),
            apertura,
            atencion['id'],
        )

    return await _conexion_por_id(conn, atencion['id'])

async def update_estado(conn: Connection, id_atencion: int, estado: Optional[str]) -> Optional[dict]:
    if not estado:
        return await _conexion_por_id(conn, id_atencion)

    if estado in ("Finalizado",):
        await conn.execute(
            "UPDATE ta_atenciones_medicas SET estado = $1, fecha_cierre = NOW() WHERE id = $2",
            estado, id_atencion,
        )
    else:
        await conn.execute(
            "UPDATE ta_atenciones_medicas SET estado = $1 WHERE id = $2",
            estado, id_atencion,
        )
    return await _conexion_por_id(conn, id_atencion)