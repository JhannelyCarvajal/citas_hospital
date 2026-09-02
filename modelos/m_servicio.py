from asyncpg import Connection
from typing import List, Optional

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tc_servicios WHERE activo = TRUE ORDER BY id_servicio")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_servicio: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tc_servicios WHERE id_servicio = $1", id_servicio)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    row = await conn.fetchrow(
        """INSERT INTO tc_servicios (nombre_servicio, descripcion, activo)
           VALUES ($1, $2, $3) RETURNING *""",
        data['nombre_servicio'], data.get('descripcion', ''), data.get('activo', True)
    )
    return dict(row)

async def update(conn: Connection, id_servicio: int, data: dict) -> Optional[dict]:
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_servicio)
    params.append(id_servicio)
    query = f"UPDATE tc_servicios SET {', '.join(fields)} WHERE id_servicio = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_servicio: int) -> bool:
    result = await conn.execute("DELETE FROM tc_servicios WHERE id_servicio = $1", id_servicio)
    return result != "DELETE 0"