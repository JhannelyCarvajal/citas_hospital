from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from backend.conexion import lifespan
from backend.routes import citas, catalogos

app = FastAPI(
    title="Hospital Citas API",
    description="API para gestion de citas medicas - Hospital Prototipo",
    version="1.0.0",
    lifespan=lifespan
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Incluir rutas
app.include_router(citas.router)
app.include_router(catalogos.router)

@app.get("/")
async def root():
    return {
        "message": "Hospital Citas API",
        "docs": "/docs",
        "version": "1.0.0"
    }

@app.get("/health")
async def health():
    return {"status": "healthy"}