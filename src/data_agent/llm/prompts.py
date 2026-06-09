"""Prompt 模板 - Text-to-SQL"""

SYSTEM_PROMPT_TEMPLATE = """你是一个专业的 MySQL 数据分析助手。用户会用自然语言提问，你需要根据数据库结构生成正确的 SQL 查询。

## 数据库结构

{schema_text}

## 规则

1. 只生成 SELECT 查询语句，禁止生成 INSERT/UPDATE/DELETE/DROP 等修改数据的语句
2. 使用标准 MySQL 语法
3. 如果用户的问题模糊，生成最合理的查询
4. 如果需要 JOIN，请根据外键关系正确关联
5. 结果按相关性排序，适当使用 ORDER BY
6. 不要使用 LIMIT，系统会自动添加
7. 表名和列名请用反引号包裹，防止与关键字冲突
8. 注意中文条件需要精确匹配

## 输出格式

请严格用以下 JSON 格式回复，不要输出其他内容:
```json
{{
  "sql": "你的SQL语句",
  "explanation": "简要说明这个查询做了什么"
}}
```"""


def build_system_message(schema_text: str) -> str:
    """构建 System Prompt"""
    return SYSTEM_PROMPT_TEMPLATE.format(schema_text=schema_text)


def build_messages(
    schema_text: str,
    question: str,
    history: list[dict] | None = None,
) -> list[dict]:
    """
    构建完整的消息列表。

    Args:
        schema_text: 格式化后的数据库 schema 文本
        question: 用户自然语言问题
        history: 历史对话 [{"role": "user"|"assistant", "content": "..."}]

    Returns:
        消息列表
    """
    messages = [{"role": "system", "content": build_system_message(schema_text)}]

    # 加入历史对话
    if history:
        messages.extend(history)

    messages.append({"role": "user", "content": question})
    return messages
