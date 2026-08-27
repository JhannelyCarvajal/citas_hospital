from asyncpg import Connection
from typing import List, Optional
from datetime import date

async def listar_especialidades(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        "SELECT id_especialidad, nombre_especialidad, tipo, descripcion, activo "
        "FROM tp_especialidades WHERE activo = TRUE ORDER BY nombre_especialidad"
    )
    return [dict(r) for r in rows]

async def obtener_especialidad(conn: Connection, id_especialidad: int) -> Optional[dict]:
    return dict(await conn.fetchrow(
        "SELECT id_especialidad, nombre_especialidad, tipo, descripcion, activo "
        "FROM tp_especialidades WHERE id_especialidad = $1", id_especialidad
    )) if await conn.fetchrow(
        "SELECT 1 FROM tp_especialidades WHERE id_especialidad = $1", id_especialidad
    ) else None

async def crear_especialidad(conn: Connection, nombre_especialidad: str, tipo: str, descripcion: str) -> dict:
    return dict(await conn.fetchrow(
        "INSERT INTO tp_especialidades (nombre_especialidad, tipo, descripcion) "
        "VALUES ($1, $2, $3) "
        "RETURNING id_especialidad, nombre_especialidad, tipo, descripcion, activo",
        nombre_especialidad, tipo, descripcion
    ))

async def listar_personas(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        "SELECT id_persona, ci, nombres, apellidos, fecha_nacimiento, genero, "
        "telefono, email, direccion, foto_url, fecha_creacion, activo "
        "FROM tp_personas WHERE activo = TRUE ORDER BY nombres, apellidos"
    )
    return [dict(r) for r in rows]

async def obtener_persona(conn: Connection, id_persona: int) -> Optional[dict]:
    return dict(await conn.fetchrow(
        "SELECT id_persona, ci, nombres, apellidos, fecha_nacimiento, genero, "
        "telefono, email, direccion, foto_url, fecha_creacion, activo "
        "FROM tp_personas WHERE id_persona = $1", id_persona
    )) if await conn.fetchrow("SELECT 1 FROM tp_personas WHERE id_persona = $1", id_persona) else None

async def crear_persona(conn: Connection, ci: str, nombres: str, apellidos: str,
                        fecha_nacimiento, genero, telefono: str, email: str, direccion) -> dict:
    return dict(await conn.fetchrow(
        "INSERT INTO tp_personas (ci, nombres, apellidos, fecha_nacimiento, genero, telefono, email, direccion) "
        "VALUES ($1, $2, $3, $4, $5, $6, $7, $8) "
        "RETURNING id_persona, ci, nombres, apellidos, fecha_nacimiento, genero, "
        "telefono, email, direccion, foto_url, fecha_creacion, activo",
        ci, nombres, apellidos, fecha_nacimiento, genero, telefono, email, direccion
    ))

async def listar_empleados(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        "SELECT id_empleado, id_persona, id_area, tipo_empleado, fecha_contratacion, "
        "fecha_terminacion, id_turno, sueldo_base, activo, nmp "
        "FROM tp_empleados WHERE activo = TRUE ORDER BY id_empleado"
    )
    return [dict(r) for r in rows]

async def obtener_empleado(conn: Connection, id_empleado: int) -> Optional[dict]:
    return dict(await conn.fetchrow(
        "SELECT id_empleado, id_persona, id_area, tipo_empleado, fecha_contratacion, "
        "fecha_terminacion, id_turno, sueldo_base, activo, nmp "
        "FROM tp_empleados WHERE id_empleado = $1", id_empleado
    )) if await conn.fetchrow("SELECT 1 FROM tp_empleados WHERE id_empleado = $1", id_empleado) else None

async def crear_empleado(conn: Connection, id_persona: int, id_area, tipo_empleado: str,
                         fecha_contratacion, fecha_terminacion, id_turno, sueldo_base: float, nmp: str) -> dict:
    return dict(await conn.fetchrow(
        "INSERT INTO tp_empleados (id_persona, id_area, tipo_empleado, fecha_contratacion, "
        "fecha_terminacion, id_turno, sueldo_base, nmp) "
        "VALUES ($1, $2, $3, $4, $5, $6, $7, $8) "
        "RETURNING id_empleado, id_persona, id_area, tipo_empleado, fecha_contratacion, "
        "fecha_terminacion, id_turno, sueldo_base, activo, nmp",
        id_persona, id_area, tipo_empleado, fecha_contratacion, fecha_terminacion, id_turno, sueldo_base, nmp
    ))

async def listar_medicos(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        "SELECT e.id_empleado, p.nombres || ' ' || p.apellidos AS medico, "
        "e.tipo_empleado, e.nmp "
        "FROM tp_empleados e "
        "JOIN tp_personas p ON p.id_persona = e.id_persona "
        "WHERE e.tipo_empleado = 'Medico' AND e.activo = TRUE "
        "ORDER BY medico"
    )
    return [dict(r) for r in rows]

async def listar_medicos_por_especialidad(conn: Connection, id_especialidad: int) -> List[dict]:
    rows = await conn.fetch(
        "SELECT e.id_empleado, p.nombres || ' ' || p.apellidos AS medico, "
        "esp.nombre_especialidad "
        "FROM tp_empleados e "
        "JOIN tp_personas p ON p.id_persona = e.id_persona "
        "JOIN tp_empleado_especialidades re ON re.id_empleado = e.id_empleado "
        "JOIN tp_especialidades esp ON esp.id_especialidad = re.id_especialidad "
        "WHERE e.tipo_empleado = 'Medico' AND e.activo = TRUE "
        "AND re.id_especialidad = $1 "
        "ORDER BY medico",
        id_especialidad
    )
    return [dict(r) for r in rows]

async def listar_servicios(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        "SELECT id_servicio, nombre_servicio, descripcion, activo "
        "FROM tc_servicios WHERE activo = TRUE ORDER BY nombre_servicio"
    )
    return [dict(r) for r in rows]

async def buscar_asegurado(conn: Connection, ci: str) -> Optional[dict]:
    row = await conn.fetchrow(
        "SELECT a.ci, a.id_aseguradora, ag.nombre AS aseguradora, a.nombre, "
        "a.paterno, a.materno, a.nro_poliza, a.fech_afiliacion, a.estado "
        "FROM tp_asegurado a "
        "LEFT JOIN tc_aseguradora ag ON ag.id_aseguradora = a.id_aseguradora "
        "WHERE a.ci = $1",
        ci
    )
    return dict(row) if row else None

async def listar_aseguradoras(conn: Connection) -> List[dict]:
    rows = await conn.fetch(
        "SELECT id_aseguradora, nombre, nit, telefono, direccion, activo "
        "FROM tc_aseguradora WHERE activo = TRUE ORDER BY nombre"
    )
    return [dict(r) for r in rows]
