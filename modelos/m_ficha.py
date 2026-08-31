from asyncpg import Connection
from datetime import date
from typing import List, Optional

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tc_ficha ORDER BY id_ficha")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_ficha: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tc_ficha WHERE id_ficha = $1", id_ficha)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    id_persona = data['id_persona']
    ci = (data['ci_paciente'] or '').strip()

    # 1) La persona debe existir y tener nombre/apellido registrados
    persona = await conn.fetchrow(
        "SELECT ci, nombres, apellidos FROM tp_personas WHERE id_persona = $1", id_persona
    )
    if not persona:
        raise ValueError("La persona no esta registrada")
    if not (persona['nombres'] or '').strip() and not (persona['apellidos'] or '').strip():
        raise ValueError("La persona debe tener un nombre registrado para ser paciente")
    if ci and persona['ci'] != ci:
        raise ValueError("El CI no corresponde a la persona seleccionada")

    # 2) Un medico no puede ser paciente
    es_medico = await conn.fetchval(
        "SELECT 1 FROM tp_empleados WHERE id_persona = $1 AND LOWER(tipo_empleado) = 'medico'",
        id_persona
    )
    if es_medico:
        raise ValueError("Un medico no puede registrarse como paciente")

    # 3) Verificar si el paciente es asegurado (estado vigente o vencido)
    asegurado = await conn.fetchrow(
        "SELECT ci, fech_fin FROM tp_asegurado WHERE ci = $1 AND estado = TRUE", ci
    )
    como_particular = bool(data.get('como_particular', False))
    if asegurado and not como_particular:
        vencido = asegurado['fech_fin'] is not None and asegurado['fech_fin'] < date.today()
        if vencido:
            raise ValueError(
                "La poliza del paciente esta vencida: acepta registrarse como Particular para crear la ficha"
            )
        tipo_paciente = "Asegurado"
        id_asegurado = asegurado["ci"]
    else:
        tipo_paciente = "Particular"
        id_asegurado = None

    # 4) Coherencia medico <-> especialidad <-> horario:
    #    el medico debe atender esa especialidad y el horario elegido debe
    #    ser de esa misma especialidad.
    atiende = await conn.fetchval(
        "SELECT 1 FROM tp_empleado_especialidades WHERE id_empleado = $1 AND id_especialidad = $2",
        data['id_medico'], data['id_especialidad']
    )
    if not atiende:
        raise ValueError("El medico no atiende la especialidad seleccionada")

    horario = await conn.fetchrow(
        "SELECT dia_semana, hora_inicio, hora_fin, nro_fichas, id_especialidad FROM tc_horario WHERE id_horario = $1",
        data['id_horario']
    )
    if not horario:
        raise ValueError("El horario no existe")
    if horario['id_especialidad'] != data['id_especialidad']:
        raise ValueError("El horario elegido corresponde a otra especialidad del medico")

    fech_cita = data['fech_cita']
    if fech_cita.isoweekday() != horario['dia_semana']:
        raise ValueError(
            f"La fecha {fech_cita} no corresponde al dia {horario['dia_semana']} del horario"
        )

    hora_cita = data['hora_cita']
    h_ini, h_fin = horario['hora_inicio'], horario['hora_fin']
    if h_ini <= h_fin:
        dentro = h_ini <= hora_cita <= h_fin
    else:
        dentro = hora_cita >= h_ini or hora_cita <= h_fin
    if not dentro:
        raise ValueError("La hora de la cita no esta dentro del horario del medico")

    repetida = await conn.fetchval(
        "SELECT 1 FROM tc_ficha WHERE id_medico = $1 AND fech_cita = $2 AND hora_cita = $3 AND estado <> 'Cancelada'",
        data['id_medico'], fech_cita, hora_cita
    )
    if repetida:
        raise ValueError("El medico ya tiene una cita a esa hora en esa fecha")

    ocupadas = await conn.fetchval(
        "SELECT COUNT(*) FROM tc_ficha WHERE id_horario = $1 AND fech_cita = $2 AND estado <> 'Cancelada'",
        data['id_horario'], fech_cita
    )
    if ocupadas >= horario['nro_fichas']:
        raise ValueError(f"El medico ya alcanzo el limite de {horario['nro_fichas']} fichas para ese dia")

    # 5) Calculamos el próximo nro_ficha para la fecha
    nro_ficha = await conn.fetchval(
        "SELECT COALESCE(MAX(nro_ficha), 0) + 1 FROM tc_ficha WHERE fech_cita = $1",
        fech_cita
    )
    row = await conn.fetchrow(
        """INSERT INTO tc_ficha (nro_ficha, id_persona, ci_paciente, tipo_paciente, id_asegurado,
                              id_medico, id_especialidad, id_horario, id_servicio,
                              fech_cita, hora_cita, estado, observacion, usuario_reg)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) RETURNING *""",
        nro_ficha,
        id_persona,
        ci,
        tipo_paciente,
        id_asegurado,
        data['id_medico'],
        data['id_especialidad'],
        data['id_horario'],
        data.get('id_servicio'),
        fech_cita,
        hora_cita,
        data.get('estado', 'Registrada'),
        data.get('observacion', ''),
        data.get('usuario_reg', '')
    )
    return dict(row)

async def update(conn: Connection, id_ficha: int, data: dict) -> Optional[dict]:
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_ficha)
    params.append(id_ficha)
    query = f"UPDATE tc_ficha SET {', '.join(fields)} WHERE id_ficha = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_ficha: int) -> bool:
    result = await conn.execute("DELETE FROM tc_ficha WHERE id_ficha = $1", id_ficha)
    return result != "DELETE 0"