from asyncpg import Connection
from typing import List, Optional

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tp_turnos ORDER BY id_turno")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_turno: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tp_turnos WHERE id_turno = $1", id_turno)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    row = await conn.fetchrow(
        """INSERT INTO tp_turnos (id_turno, nombre_turno, hora_inicio, hora_fin, activo)
           VALUES ($1, $2, $3, $4, $5) RETURNING *""",
        data['id_turno'], data['nombre_turno'], data['hora_inicio'], data['hora_fin'],
        data.get('activo', True)
    )
    return dict(row)

async def update(conn: Connection, id_turno: int, data: dict) -> Optional[dict]:
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_turno)
    params.append(id_turno)
    query = f"UPDATE tp_turnos SET {', '.join(fields)} WHERE id_turno = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_turno: int) -> bool:
    result = await conn.execute("DELETE FROM tp_turnos WHERE id_turno = $1", id_turno)
    return result != "DELETE 0"