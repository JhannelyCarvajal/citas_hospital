from asyncpg import Connection
from typing import Optional

async def verifica_usuario(ci: str, conn: Connection) -> dict:
    persona = await conn.fetchrow(
        "SELECT id_persona, ci, nombres, apellidos, email, telefono, activo "
        "FROM tp_personas WHERE ci = $1",
        ci
    )

    if not persona:
        return {"resultado": False, "motivo": "no_existe", "mensaje": "Persona no registrada"}

    if not persona["activo"]:
        return {"resultado": False, "motivo": "inactivo", "mensaje": "La persona se encuentra inactiva"}

    asegurado = await conn.fetchrow(
        "SELECT ci FROM tp_asegurado WHERE ci = $1 AND estado = TRUE",
        ci
    )
    tipo = "Asegurado" if asegurado else "Particular"

    return {
        "resultado": True,
        "motivo": "",
        "mensaje": "Autenticacion exitosa",
        "usuario": persona["ci"],
        "id_persona": persona["id_persona"],
        "nombre": f"{persona['nombres']} {persona['apellidos']}",
        "tipo_paciente": tipo,
    }
