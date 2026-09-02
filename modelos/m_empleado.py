from asyncpg import Connection
from datetime import date
from typing import List, Optional

TIPOS_EMPLEADO = {
    'medico': 'Medico', 'enfermero': 'Enfermero', 'administrativo': 'Administrativo',
    'auxiliar': 'Auxiliar', 'otro': 'Otro',
}

def _normalizar_tipo_empleado(tipo_empleado: str) -> str:
    return TIPOS_EMPLEADO.get(str(tipo_empleado).strip().lower(), tipo_empleado)

async def get_all(conn: Connection) -> List[dict]:
    rows = await conn.fetch("SELECT * FROM tp_empleados ORDER BY id_empleado")
    return [dict(r) for r in rows]

async def get_by_id(conn: Connection, id_empleado: int) -> Optional[dict]:
    row = await conn.fetchrow("SELECT * FROM tp_empleados WHERE id_empleado = $1", id_empleado)
    return dict(row) if row else None

async def create(conn: Connection, data: dict) -> dict:
    if not data.get('id_turno'):
        raise ValueError("El turno es obligatorio")
    row = await conn.fetchrow(
        """INSERT INTO tp_empleados (id_persona, id_area, tipo_empleado, fecha_contratacion, fecha_terminacion, id_turno, sueldo_base, nmp, activo)
           VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9) RETURNING *""",
        data['id_persona'], data.get('id_area'), _normalizar_tipo_empleado(data['tipo_empleado']), data.get('fecha_contratacion') or date.today(),
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
            if key == 'tipo_empleado':
                value = _normalizar_tipo_empleado(value)
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