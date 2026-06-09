"""配置管理模块 - 从 .env 文件加载所有配置"""

from pathlib import Path

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    """应用配置，自动从 .env 文件加载"""

    model_config = SettingsConfigDict(
        env_file=str(Path(__file__).resolve().parent.parent.parent / ".env"),
        env_file_encoding="utf-8",
        extra="ignore",
    )

    # 智谱 GLM-5.1 (Anthropic 兼容接口)
    anthropic_auth_token: str
    anthropic_base_url: str = "https://open.bigmodel.cn/api/anthropic"
    llm_model: str = "glm-5.1"
    llm_temperature: float = 0.1

    # MySQL 数据库
    mysql_host: str = "localhost"
    mysql_port: int = 3306
    mysql_user: str = "root"
    mysql_password: str = ""
    mysql_database: str = ""

    # 查询限制
    max_query_rows: int = 100

    @property
    def mysql_url(self) -> str:
        """构建 MySQL 连接 URL"""
        return (
            f"mysql+pymysql://{self.mysql_user}:{self.mysql_password}"
            f"@{self.mysql_host}:{self.mysql_port}/{self.mysql_database}"
            f"?charset=utf8mb4"
        )


# 全局单例
_settings: Settings | None = None


def get_settings() -> Settings:
    """获取全局配置单例"""
    global _settings
    if _settings is None:
        _settings = Settings()
    return _settings
