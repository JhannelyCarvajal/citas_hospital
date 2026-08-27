import asyncio, asyncpg, json, urllib.request
from datetime import date

BASE = "http://127.0.0.1:8011"

def req(method, path, body=None):
    url = BASE + path
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(url, data=data, method=method,
                               headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(r) as resp:
            return resp.status, json.loads(resp.read().decode())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode())

async def main():
    conn = await asyncpg.connect("postgresql://postgres:123456@localhost:5432/bd_hospital")
    ci_aseg = await conn.fetchval("SELECT ci FROM tp_asegurado WHERE estado=TRUE LIMIT 1")
    await conn.close()

    print("== catalogos ==")
    s, esp = req("GET", "/api/catalogos/especialidades")
    print("especialidades:", s, "count=", len(esp))
    s, serv = req("GET", "/api/catalogos/servicios")
    print("servicios:", s, "count=", len(serv))
    s, aseg = req("GET", "/api/catalogos/aseguradoras")
    print("aseguradoras:", s, "count=", len(aseg))
    s, a = req("GET", f"/api/catalogos/asegurados/{ci_aseg}")
    print("asegurado lookup:", s, a.get("nombre") if isinstance(a, dict) else a)
    s, nf = req("GET", f"/api/catalogos/asegurados/00000000")
    print("asegurado 404:", s)

    print("\n== horarios (today) ==")
    hoy = date.today().isoformat()
    s, hor = req("GET", f"/api/citas/horarios-disponibles/1?fecha={hoy}")
    print("horarios:", s, "count=", len(hor))
    if not hor:
        print("NO HAY HORARIOS PARA HOY; abortando ficha"); return
    h = hor[0]
    id_persona = esp[0]["id_especialidad"]  # placeholder; get real persona
    s, pers = req("GET", "/api/catalogos/personas")
    idp = pers[0]["id_persona"]
    serv0 = serv[0]["id_servicio"]

    print("\n== cotizar (particular) ==")
    s, cot = req("POST", "/api/citas/cotizar", {
        "id_especialidad": h["id_especialidad"], "id_servicio": serv0,
        "tipo_paciente": "P", "monto": 150.0})
    print("cotizar:", s, cot)

    print("\n== crear ficha PARTICULAR ==")
    s, f = req("POST", "/api/citas/fichas", {
        "id_persona": idp, "ci_paciente": "99999999", "tipo_paciente": "P",
        "id_especialidad": h["id_especialidad"], "id_medico": h["id_medico"],
        "id_horario": h["id_horario"], "id_servicio": serv0,
        "fech_cita": hoy, "hora_cita": str(h["hora_inicio"]),
        "monto": 150.0, "usuario_reg": "tester"})
    print("crear ficha P:", s, f)
    idf = f.get("id_ficha")

    print("\n== pagar ficha ==")
    s, p = req("POST", f"/api/citas/fichas/{idf}/pagar", {"metodo_pago": "EFECTIVO", "monto": 150.0})
    print("pagar:", s, p)

    print("\n== ver ficha ==")
    s, vf = req("GET", f"/api/citas/fichas/{idf}")
    print("ficha:", s, "estado=", vf.get("estado"), "obs=", vf.get("observacion"))

    print("\n== crear ficha ASEGURADO (CI ficticio; tp_asegurado vacio => sera P) ==")
    s, fa = req("POST", "/api/citas/fichas", {
        "id_persona": idp, "ci_paciente": "12345678", "tipo_paciente": "A",
        "id_especialidad": h["id_especialidad"], "id_medico": h["id_medico"],
        "id_horario": h["id_horario"], "id_servicio": serv0,
        "fech_cita": hoy, "hora_cita": str(h["hora_inicio"]), "usuario_reg": "tester"})
    print("crear ficha A:", s, "estado=", fa.get("estado"), "tipo=", fa.get("tipo_paciente"))

asyncio.run(main())
