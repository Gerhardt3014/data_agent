"""数据库 Schema 提取模块"""

from dataclasses import dataclass, field

from data_agent.config import Settings, get_settings
from data_agent.db.connection import execute_query


@dataclass
class ColumnInfo:
    """列信息"""
    name: str
    type: str
    comment: str = ""
    is_primary_key: bool = False
    is_auto_increment: bool = False
    foreign_key: str | None = None  # 格式: "table.column"


@dataclass
class TableInfo:
    """表信息"""
    name: str
    comment: str = ""
    columns: list[ColumnInfo] = field(default_factory=list)
    sample_rows: list[dict] = field(default_factory=list)


@dataclass
class DatabaseSchema:
    """数据库完整 Schema"""
    database: str
    tables: list[TableInfo] = field(default_factory=list)


# 缓存
_schema_cache: DatabaseSchema | None = None


def get_schema(settings: Settings | None = None, refresh: bool = False) -> DatabaseSchema:
    """获取数据库 Schema，带缓存"""
    global _schema_cache
    if _schema_cache is not None and not refresh:
        return _schema_cache

    s = settings or get_settings()
    schema = DatabaseSchema(database=s.mysql_database)

    # 1. 获取所有表名
    table_names = _get_table_names(s.mysql_database)

    # 2. 逐表提取详细信息
    for table_name in table_names:
        table = _get_table_info(table_name, s.mysql_database)
        schema.tables.append(table)

    _schema_cache = schema
    return schema


def _get_table_names(database: str) -> list[str]:
    """获取数据库中所有表名"""
    sql = """
        SELECT TABLE_NAME
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '{}' AND TABLE_TYPE = 'BASE TABLE'
        ORDER BY TABLE_NAME
    """.format(database)
    _, rows = execute_query(sql)
    return [row[0] for row in rows]


def _get_table_info(table_name: str, database: str) -> TableInfo:
    """获取单张表的完整信息"""
    # 表注释
    sql = """
        SELECT TABLE_COMMENT
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '{}' AND TABLE_NAME = '{}'
    """.format(database, table_name)
    _, rows = execute_query(sql)
    comment = rows[0][0] if rows else ""

    table = TableInfo(name=table_name, comment=comment)

    # 列信息
    table.columns = _get_columns(table_name, database)

    # 样例数据
    table.sample_rows = _get_sample_rows(table_name)

    return table


def _get_columns(table_name: str, database: str) -> list[ColumnInfo]:
    """获取表的所有列信息"""
    sql = """
        SELECT
            c.COLUMN_NAME,
            c.COLUMN_TYPE,
            c.COLUMN_COMMENT,
            c.COLUMN_KEY,
            c.EXTRA
        FROM information_schema.COLUMNS c
        WHERE c.TABLE_SCHEMA = '{}' AND c.TABLE_NAME = '{}'
        ORDER BY c.ORDINAL_POSITION
    """.format(database, table_name)
    _, rows = execute_query(sql)

    # 获取外键信息
    fk_map = _get_foreign_keys(table_name, database)

    columns = []
    for row in rows:
        col = ColumnInfo(
            name=row[0],
            type=row[1],
            comment=row[2],
            is_primary_key=(row[3] == "PRI"),
            is_auto_increment=("auto_increment" in (row[4] or "")),
            foreign_key=fk_map.get(row[0]),
        )
        columns.append(col)
    return columns


def _get_foreign_keys(table_name: str, database: str) -> dict[str, str]:
    """获取表的外键映射 {column_name: 'ref_table.ref_column'}"""
    sql = """
        SELECT
            kcu.COLUMN_NAME,
            kcu.REFERENCED_TABLE_NAME,
            kcu.REFERENCED_COLUMN_NAME
        FROM information_schema.KEY_COLUMN_USAGE kcu
        WHERE kcu.TABLE_SCHEMA = '{}'
          AND kcu.TABLE_NAME = '{}'
          AND kcu.REFERENCED_TABLE_NAME IS NOT NULL
    """.format(database, table_name)
    _, rows = execute_query(sql)
    return {row[0]: f"{row[1]}.{row[2]}" for row in rows}


def _get_sample_rows(table_name: str, limit: int = 3) -> list[dict]:
    """获取表的样例数据"""
    sql = f"SELECT * FROM `{table_name}` LIMIT {limit}"
    columns, rows = execute_query(sql)
    return [dict(zip(columns, row)) for row in rows]


def format_schema_for_llm(schema: DatabaseSchema) -> str:
    """将 Schema 格式化为 LLM 友好的文本"""
    lines = [f"数据库: {schema.database}\n"]

    for table in schema.tables:
        header = f"表: {table.name}"
        if table.comment:
            header += f" ({table.comment})"
        lines.append(header)
        lines.append("列:")

        for col in table.columns:
            parts = [f"  - {col.name}: {col.type}"]
            if col.is_primary_key:
                parts.append("主键")
            if col.is_auto_increment:
                parts.append("自增")
            if col.comment:
                parts.append(col.comment)
            if col.foreign_key:
                parts.append(f"外键 → {col.foreign_key}")
            lines.append(", ".join(parts))

        if table.sample_rows:
            lines.append(f"\n样例数据 ({len(table.sample_rows)}条):")
            for i, row in enumerate(table.sample_rows, 1):
                # 截断过长的值
                short = {k: (str(v)[:50] + "..." if v and len(str(v)) > 50 else v) for k, v in row.items()}
                lines.append(f"  {i}. {short}")

        lines.append("")  # 表之间空行

    return "\n".join(lines)
