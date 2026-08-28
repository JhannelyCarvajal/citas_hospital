from asyncpg import Connection
from typing import List, Optional

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tc_horario ORDER BY id_horario")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_horario: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tc_horario WHERE id_horario = $1", id_horario)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    row = await conn.fetchrow(
        """INSERT INTO tc_horario (id_horario, id_empleado, dia_semana, id_turno, hora_inicio, hora_fin, nro_fichas, activo)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *""",
        data['id_horario'], data['id_empleado'], data['dia_semana'], data['id_turno'],
        data['hora_inicio'], data['hora_fin'], data.get('nro_fichas', 5), data.get('activo', True)
    )
    return dict(row)

async def update(conn: Connection, id_horario: int, data: dict) -> Optional[dict]:
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_horario)
    params.append(id_horario)
    query = f"UPDATE tc_horario SET {', '.join(fields)} WHERE id_horario = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_horario: int) -> bool:
    result = await conn.execute("DELETE FROM tc_horario WHERE id_horario = $1", id_horario)
    return result != "DELETE 0"