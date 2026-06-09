"""SQL 安全验证模块"""

import re

import sqlparse
from sqlparse.sql import Identifier, IdentifierList, Where
from sqlparse.tokens import Keyword, DML

from data_agent.config import Settings, get_settings


class SQLValidationError(Exception):
    """SQL 验证失败异常"""
    pass


# 危险 SQL 关键词 (禁止使用)
FORBIDDEN_KEYWORDS = {
    "INSERT", "UPDATE", "DELETE", "DROP", "CREATE", "ALTER",
    "TRUNCATE", "REPLACE", "RENAME", "GRANT", "REVOKE",
    "LOAD", "CALL", "EXEC", "EXECUTE",
}

# 危险函数
FORBIDDEN_FUNCTIONS = {
    "LOAD_FILE", "INTO OUTFILE", "INTO DUMPFILE",
    "BENCHMARK", "SLEEP", "WAITFOR",
}


class SQLValidator:
    """SQL 安全验证器"""

    def __init__(self, settings: Settings | None = None):
        s = settings or get_settings()
        self.max_rows = s.max_query_rows

    def validate(self, sql: str) -> str:
        """
        验证 SQL 安全性并返回处理后的 SQL。

        Raises:
            SQLValidationError: SQL 不合法
        """
        sql = sql.strip().rstrip(";").strip()

        # 1. 检查空语句
        if not sql:
            raise SQLValidationError("SQL 语句为空")

        # 2. 检查是否包含多条语句 (防注入)
        if ";" in sql:
            raise SQLValidationError("禁止执行多条 SQL 语句")

        # 3. 解析 SQL
        parsed = sqlparse.parse(sql)
        if not parsed:
            raise SQLValidationError("无法解析 SQL 语句")

        stmt = parsed[0]

        # 4. 检查语句类型 - 只允许 SELECT
        first_token = stmt.token_first(skip_ws=True, skip_cm=True)
        if not first_token or first_token.ttype != DML or first_token.value.upper() != "SELECT":
            raise SQLValidationError(
                f"只允许 SELECT 查询，检测到: {first_token.value if first_token else '未知'}"
            )

        # 5. 检查危险关键词
        sql_upper = sql.upper()
        for keyword in FORBIDDEN_KEYWORDS:
            if keyword in sql_upper:
                raise SQLValidationError(f"SQL 中包含禁止的关键词: {keyword}")

        # 6. 检查危险函数
        for func in FORBIDDEN_FUNCTIONS:
            if func in sql_upper:
                raise SQLValidationError(f"SQL 中包含禁止的函数: {func}")

        # 7. 确保有 LIMIT
        sql = self._ensure_limit(sql)

        return sql

    def _ensure_limit(self, sql: str) -> str:
        """确保 SQL 包含 LIMIT 子句，没有则追加"""
        sql_upper = sql.upper()
        if "LIMIT" not in sql_upper:
            return f"{sql} LIMIT {self.max_rows}"

        # 检查现有 LIMIT 值是否超过上限
        limit_match = re.search(r"LIMIT\s+(\d+)", sql, re.IGNORECASE)
        if limit_match:
            limit_val = int(limit_match.group(1))
            if limit_val > self.max_rows:
                sql = re.sub(
                    r"LIMIT\s+\d+",
                    f"LIMIT {self.max_rows}",
                    sql,
                    flags=re.IGNORECASE,
                )
        return sql
