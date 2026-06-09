"""智谱 GLM-5.1 API 客户端 (Anthropic 兼容接口)"""

import json
import re
import logging

from anthropic import Anthropic

from data_agent.config import Settings, get_settings

logger = logging.getLogger(__name__)


class LLMClient:
    """大模型 API 客户端"""

    def __init__(self, settings: Settings | None = None):
        s = settings or get_settings()
        self.client = Anthropic(
            api_key=s.anthropic_auth_token,
            base_url=s.anthropic_base_url,
        )
        self.model = s.llm_model
        self.temperature = s.llm_temperature

    def chat(self, messages: list[dict], temperature: float | None = None) -> str:
        """
        调用 LLM，返回模型回复文本。

        Args:
            messages: 消息列表，格式 [{"role": "system"|"user"|"assistant", "content": "..."}]
            temperature: 温度参数，不传则使用默认值
        """
        # 分离 system 消息和对话消息
        system_content = ""
        chat_messages = []
        for msg in messages:
            if msg["role"] == "system":
                system_content += msg["content"] + "\n"
            else:
                chat_messages.append({"role": msg["role"], "content": msg["content"]})

        temp = temperature if temperature is not None else self.temperature

        try:
            response = self.client.messages.create(
                model=self.model,
                max_tokens=4096,
                system=system_content.strip() if system_content else None,
                messages=chat_messages,
                temperature=temp,
            )
            return response.content[0].text
        except Exception as e:
            logger.error(f"LLM 调用失败: {e}")
            raise


def parse_sql_response(response_text: str) -> tuple[str, str]:
    """
    从 LLM 回复中解析 SQL 和解释。

    支持两种格式:
    1. JSON: {"sql": "...", "explanation": "..."}
    2. 纯 SQL (可能带有 markdown 代码块)

    Returns:
        (sql, explanation)
    """
    # 尝试 JSON 格式
    try:
        data = json.loads(response_text.strip())
        if isinstance(data, dict) and "sql" in data:
            return data["sql"].strip(), data.get("explanation", "")
    except json.JSONDecodeError:
        pass

    # 尝试从 markdown 代码块中提取 JSON
    json_match = re.search(r"```(?:json)?\s*\n?(.*?)\n?```", response_text, re.DOTALL)
    if json_match:
        try:
            data = json.loads(json_match.group(1).strip())
            if isinstance(data, dict) and "sql" in data:
                return data["sql"].strip(), data.get("explanation", "")
        except json.JSONDecodeError:
            pass

    # 尝试从代码块中提取纯 SQL
    sql_match = re.search(r"```(?:sql)?\s*\n?(.*?)\n?```", response_text, re.DOTALL)
    if sql_match:
        sql = sql_match.group(1).strip()
        # 去掉代码块外的内容作为解释
        explanation = response_text.replace(sql_match.group(0), "").strip()
        return sql, explanation

    # 最后兜底：把整个回复当 SQL
    return response_text.strip(), ""
