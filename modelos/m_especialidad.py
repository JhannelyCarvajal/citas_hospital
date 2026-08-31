from asyncpg import Connection
from typing import List, Optional

TIPOS_ESPECIALIDAD = {
    'medica': 'Medica', 'enfermeria': 'Enfermeria',
    'apoyo': 'Apoyo', 'administrativa': 'Administrativa',
}

def _normalizar_tipo(tipo: str) -> str:
    return TIPOS_ESPECIALIDAD.get(str(tipo).strip().lower(), tipo)

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tp_especialidades ORDER BY id_especialidad")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_especialidad: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tp_especialidades WHERE id_especialidad = $1", id_especialidad)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    row = await conn.fetchrow(
        """INSERT INTO tp_especialidades (id_especialidad, nombre_especialidad, tipo, descripcion, activo)
           VALUES ($1, $2, $3, $4, $5) RETURNING *""",
        data['id_especialidad'], data['nombre_especialidad'], _normalizar_tipo(data['tipo']), data.get('descripcion', ''), data.get('activo', True)
    )
    return dict(row)

async def update(conn: Connection, id_especialidad: int, data: dict) -> Optional[dict]:
    # Construir SET dinámicamente
    fields = []
    params = []
    i = 1
    for key, value in data.items():
        if value is not None:
            if key == 'tipo':
                value = _normalizar_tipo(value)
            fields.append(f"{key} = ${i}")
            params.append(value)
            i += 1
    if not fields:
        return await get_by_id(conn, id_especialidad)
    params.append(id_especialidad)
    query = f"UPDATE tp_especialidades SET {', '.join(fields)} WHERE id_especialidad = ${i} RETURNING *"
    row = await conn.fetchrow(query, *params)
    return dict(row) if row else None

async def delete(conn: Connection, id_especialidad: int) -> bool:
    result = await conn.execute("DELETE FROM tp_especialidades WHERE id_especialidad = $1", id_especialidad)
    return result != "DELETE 0"

async def medicos_por_especialidad(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        """SELECT ee.id_especialidad, ee.id_empleado
           FROM tp_empleado_especialidades ee
           JOIN tp_empleados e ON e.id_empleado = ee.id_empleado
           WHERE LOWER(e.tipo_empleado) = 'medico' AND e.activo IS NOT FALSE
           ORDER BY ee.id_especialidad, ee.id_empleado"""
    )
    return [dict(r) for r in rows]