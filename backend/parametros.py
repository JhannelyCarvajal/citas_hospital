# archivo parametros.py
from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent

class Config(BaseSettings):
    model_config = SettingsConfigDict(env_file=BASE_DIR / ".env",
                                    env_file_encoding="utf-8")

    app_name:str
    admin_email:str
    items_per_user:int = 50
    
    db_name:str
    db_user:str
    db_pass:str
    db_host:str
    db_port:int = 5432
    jwt_secret:str = Field(min_length=32)
    jwt_expira_minutos:int = 60

config = Config()