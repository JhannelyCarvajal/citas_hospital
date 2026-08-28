from asyncpg import Connection
from typing import List, Optional

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tp_empleados ORDER BY id_empleado")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_empleado: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tp_empleados WHERE id_empleado = $1", id_empleado)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    row = await conn.fetchrow(
        """INSERT INTO tp_empleados (id_persona, id_area, tipo_empleado, fecha_contratacion, fecha_terminacion, id_turno, sueldo_base, nmp, activo)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *""",
        data['id_persona'], data.get('id_area'), data['tipo_empleado'], data.get('fecha_contratacion'),
        data.get('fecha_terminacion'), data.get('id_turno'), data.get('sueldo_base', 0.0),
        data.get('nmp', ''), data.get('activo', True)
    )
    return dict(row)

async def update(conn: Connection, id_empleado: int, data: dict) -> Optional[dict]:
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_empleado)
    params.append(id_empleado)
    query = f"UPDATE tp_empleados SET {', '.join(fields)} WHERE id_empleado = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_empleado: int) -> bool:
    result = await conn.execute("DELETE FROM tp_empleados WHERE id_empleado = $1", id_empleado)
    return result != "DELETE 0"