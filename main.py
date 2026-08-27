from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from configuracion.conexion import lifespan

app = FastAPI(
    title="Hospital Citas API",
    description="API para gestion de citas medicas - Hospital Prototipo",
    version="1.0.0",
    lifespan=lifespan,
)

# CORS (para que el frontend pueda consumir la API)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/")
async def root():
    return {
        "message": "Hospital Citas API",
        "docs": "/docs",
        "version": "1.0.0",
    }

@app.get("/health")
async def health():
    return {"status": "healthy"}
