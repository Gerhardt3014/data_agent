"""MySQL 连接管理"""

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine

from data_agent.config import Settings, get_settings

_engine: Engine | None = None


def get_engine(settings: Settings | None = None) -> Engine:
    """获取 SQLAlchemy Engine 单例"""
    global _engine
    if _engine is None:
        s = settings or get_settings()
        _engine = create_engine(
            s.mysql_url,
            pool_size=5,
            max_overflow=10,
            pool_recycle=3600,
            echo=False,
        )
    return _engine


def execute_query(sql: str, settings: Settings | None = None) -> tuple[list[str], list[list]]:
    """执行 SQL 查询，返回 (列名列表, 数据行列表)"""
    engine = get_engine(settings)
    with engine.connect() as conn:
        result = conn.execute(text(sql))
        columns = list(result.keys())
        rows = [list(row) for row in result.fetchall()]
        return columns, rows


def test_connection(settings: Settings | None = None) -> bool:
    """测试数据库连接是否正常"""
    try:
        columns, rows = execute_query("SELECT 1 AS ok", settings)
        return len(rows) == 1 and rows[0][0] == 1
    except Exception:
        return False
