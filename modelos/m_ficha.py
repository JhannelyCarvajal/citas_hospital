from asyncpg import Connection
from typing import List, Optional

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tc_ficha ORDER BY id_ficha")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_ficha: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tc_ficha WHERE id_ficha = $1", id_ficha)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    ci = data['ci_paciente']

    # 1) El paciente debe estar registrado en tp_personas
    persona = await conn.fetchrow(
        "SELECT ci FROM tp_personas WHERE ci = $1", ci
    )
    if not persona:
        raise ValueError("El paciente no esta registrado")

    # 2) Verificar si el paciente es asegurado
    asegurado = await conn.fetchrow(
        "SELECT ci FROM tp_asegurado WHERE ci = $1 AND estado = TRUE", ci
    )
    tipo_paciente = "Asegurado" if asegurado else "Particular"
    id_asegurado = asegurado["ci"] if asegurado else None

    # 3) Calculamos el próximo nro_ficha para la fecha
    nro_ficha = await conn.fetchval(
        "SELECT COALESCE(MAX(nro_ficha), 0) + 1 FROM tc_ficha WHERE fech_cita = $1",
        data['fech_cita']
    )
    row = await conn.fetchrow(
        """INSERT INTO tc_ficha (nro_ficha, id_persona, ci_paciente, tipo_paciente, id_asegurado,
                              id_medico, id_especialidad, id_horario, id_servicio,
                              fech_cita, hora_cita, estado, observacion, usuario_reg)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14) RETURNING *""",
        nro_ficha,
        data['id_persona'],
        ci,
        tipo_paciente,
        id_asegurado,
        data['id_medico'],
        data['id_especialidad'],
        data['id_horario'],
        data.get('id_servicio'),
        data['fech_cita'],
        data['hora_cita'],
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