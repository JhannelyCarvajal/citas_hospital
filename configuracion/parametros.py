from pydantic_settings import BaseSettings, SettingsConfigDict
from pydantic import Field
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

class Config(BaseSettings):
    model_config = SettingsConfigDict(env_file=BASE_DIR / ".env",
                                      env_file_encoding="utf-8")

    db_name: str
    db_user: str
    db_pass: str
    db_host: str
    db_port: int = 5432

config = Config()
