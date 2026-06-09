"""核心流水线 - Text-to-SQL 执行引擎"""

from dataclasses import dataclass, field

from data_agent.config import Settings, get_settings
from data_agent.db.connection import execute_query
from data_agent.db.schema import get_schema, format_schema_for_llm
from data_agent.llm.client import LLMClient, parse_sql_response
from data_agent.llm.prompts import build_messages
from data_agent.agent.validator import SQLValidator, SQLValidationError


@dataclass
class QueryResult:
    """查询结果"""
    sql: str
    columns: list[str]
    rows: list[list]
    explanation: str = ""
    error: str | None = None


class DataAgent:
    """Text-to-SQL 核心引擎"""

    def __init__(self, settings: Settings | None = None):
        self.settings = settings or get_settings()
        self.llm = LLMClient(self.settings)
        self.validator = SQLValidator(self.settings)

    def query(self, question: str, history: list[dict] | None = None) -> QueryResult:
        """
        自然语言查询数据库。

        Args:
            question: 用户自然语言问题
            history: 历史对话记录

        Returns:
            QueryResult 包含 SQL、列名、数据行、解释
        """
        # 1. 获取 Schema
        schema = get_schema(self.settings)
        schema_text = format_schema_for_llm(schema)

        # 2. 构建消息
        messages = build_messages(schema_text, question, history)

        # 3. 调用 LLM 生成 SQL
        try:
            response = self.llm.chat(messages)
        except Exception as e:
            return QueryResult(
                sql="", columns=[], rows=[],
                error=f"LLM 调用失败: {e}",
            )

        # 4. 解析 SQL
        sql, explanation = parse_sql_response(response)

        if not sql:
            return QueryResult(
                sql="", columns=[], rows=[],
                error=f"无法从模型回复中解析 SQL。原始回复: {response[:200]}",
            )

        # 5. 安全验证
        try:
            sql = self.validator.validate(sql)
        except SQLValidationError as e:
            return QueryResult(
                sql=sql, columns=[], rows=[],
                explanation=explanation,
                error=f"SQL 安全验证失败: {e}",
            )

        # 6. 执行查询
        try:
            columns, rows = execute_query(sql, self.settings)
        except Exception as e:
            return QueryResult(
                sql=sql, columns=[], rows=[],
                explanation=explanation,
                error=f"SQL 执行失败: {e}",
            )

        return QueryResult(
            sql=sql,
            columns=columns,
            rows=rows,
            explanation=explanation,
        )
