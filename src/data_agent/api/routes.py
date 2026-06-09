"""REST API 路由"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from data_agent.agent.pipeline import DataAgent, QueryResult
from data_agent.config import get_settings
from data_agent.db.schema import get_schema, format_schema_for_llm
from data_agent.db.connection import test_connection

router = APIRouter(prefix="/api/v1")


class QueryRequest(BaseModel):
    """查询请求"""
    question: str
    conversation_id: str | None = None


class QueryResponse(BaseModel):
    """查询响应"""
    sql: str
    columns: list[str]
    rows: list[list]
    explanation: str = ""
    row_count: int = 0
    error: str | None = None


class HealthResponse(BaseModel):
    """健康检查响应"""
    status: str
    database: str


class SchemaResponse(BaseModel):
    """Schema 响应"""
    database: str
    schema_text: str


def _get_agent() -> DataAgent:
    """获取 DataAgent 实例"""
    return DataAgent(get_settings())


@router.post("/query", response_model=QueryResponse)
async def query(req: QueryRequest):
    """自然语言查询数据库"""
    agent = _get_agent()
    result: QueryResult = agent.query(req.question)

    if result.error and not result.sql:
        raise HTTPException(status_code=400, detail=result.error)

    return QueryResponse(
        sql=result.sql,
        columns=result.columns,
        rows=result.rows,
        explanation=result.explanation,
        row_count=len(result.rows),
        error=result.error,
    )


@router.get("/schema", response_model=SchemaResponse)
async def schema():
    """获取数据库结构"""
    settings = get_settings()
    db_schema = get_schema(settings)
    text = format_schema_for_llm(db_schema)
    return SchemaResponse(database=settings.mysql_database, schema_text=text)


@router.get("/health", response_model=HealthResponse)
async def health():
    """健康检查"""
    settings = get_settings()
    connected = test_connection(settings)
    return HealthResponse(
        status="ok" if connected else "error",
        database="connected" if connected else "disconnected",
    )
