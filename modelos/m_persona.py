from asyncpg import Connection
from typing import List, Optional

def _normalizar_genero(genero):
    if genero is None:
        return None
    g = str(genero).strip().upper()
    return g if g in ('M', 'F', 'O') else genero

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tp_personas ORDER BY id_persona")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_persona: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tp_personas WHERE id_persona = $1", id_persona)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    row = await conn.fetchrow(
        """INSERT INTO tp_personas (ci, nombres, apellidos, fecha_nacimiento, genero, telefono, email, direccion, activo)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *""",
        data['ci'], data['nombres'], data.get('apellidos', ''), data.get('fecha_nacimiento'),
        _normalizar_genero(data.get('genero')), data.get('telefono', ''), data.get('email', ''), data.get('direccion'),
        data.get('activo', True)
    )
    return dict(row)

async def update(conn: Connection, id_persona: int, data: dict) -> Optional[dict]:
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            if key == 'genero':
                value = _normalizar_genero(value)
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_persona)
    params.append(id_persona)
    query = f"UPDATE tp_personas SET {', '.join(fields)} WHERE id_persona = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_persona: int) -> bool:
    result = await conn.execute("DELETE FROM tp_personas WHERE id_persona = $1", id_persona)
    return result != "DELETE 0"

async def es_asegurado(conn: Connection, ci: str) -> dict:
    row = await conn.fetchrow(
        "SELECT ci, id_aseguradora, nombre, paterno, materno, nro_poliza FROM tp_asegurado "
        "WHERE ci = $1 AND estado = TRUE",
        ci
    )
    if not row:
        return {
            "ci": ci,
            "es_asegurado": False,
            "nombre": None,
            "id_aseguradora": None,
            "nro_poliza": None,
        }
    nombre_completo = f"{row['nombre']} {row['paterno']} {row['materno']}".strip()
    return {
        "ci": row["ci"],
        "es_asegurado": True,
        "nombre": nombre_completo,
        "id_aseguradora": row["id_aseguradora"],
        "nro_poliza": row["nro_poliza"],
    }