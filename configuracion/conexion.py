from contextlib import asynccontextmanager
import asyncpg
from fastapi import FastAPI, Request
from configuracion.parametros import config

DB_CONFIG = f"postgresql://{config.db_user}:{config.db_pass}@{config.db_host}:{config.db_port}/{config.db_name}"

@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(dsn=DB_CONFIG, min_size=5, max_size=20)
    yield
    await app.state.pool.close()

async def get_conn(request: Request):
    async with request.app.state.pool.acquire() as conn:
        yield conn
