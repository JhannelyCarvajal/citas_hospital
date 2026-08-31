from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from configuracion.conexion import lifespan
from rutas import r_especialidad, r_persona, r_empleado, r_horario, r_ficha, r_servicio, r_turno, r_emergencia

app = FastAPI(
    title="Módulo de Citas - API",
    description="API básica para gestión de citas médicas (sin autenticación)",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir routers
app.include_router(r_especialidad.router)
app.include_router(r_persona.router)
app.include_router(r_empleado.router)
app.include_router(r_horario.router)
app.include_router(r_ficha.router)
app.include_router(r_servicio.router)
app.include_router(r_turno.router)
app.include_router(r_emergencia.router)

@app.get("/health")
async def health():
    return {"status": "ok"}

# Frontend estatico (una sola pagina SPA) servido desde la raiz
app.mount("/", StaticFiles(directory="frontend", html=True), name="frontend")