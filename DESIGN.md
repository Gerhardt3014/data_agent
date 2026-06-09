# Data Agent 设计方案

> Text-to-SQL 数据智能代理，用户用自然语言提问，Agent 自动生成 SQL 查询 MySQL 数据库并返回结果。

## 技术选型

| 组件 | 选择 | 说明 |
|------|------|------|
| 语言 | Python 3.10+ | 生态丰富，开发效率高 |
| API 框架 | FastAPI | 异步、自带 API 文档、性能好 |
| CLI 框架 | Typer + Rich | 现代命令行框架，美化输出 |
| 数据库 | MySQL (已有) | SQLAlchemy + pymysql |
| LLM | 智谱 GLM-5.1 (Anthropic 兼容接口) | anthropic Python SDK |
| SQL 解析 | sqlparse | 安全验证 |
| 配置管理 | pydantic-settings + .env | 类型安全的配置 |

---

## 项目目录结构

```
data_agent/
├── .env.example                # 环境变量模板
├── .gitignore
├── README.md
├── pyproject.toml              # 项目依赖管理
├── src/
│   └── data_agent/
│       ├── __init__.py
│       ├── main.py             # 入口: CLI 命令 + FastAPI app
│       ├── config.py           # 配置管理 (读取 .env)
│       ├── db/
│       │   ├── __init__.py
│       │   ├── connection.py   # MySQL 连接管理 (SQLAlchemy)
│       │   └── schema.py       # Schema 提取 (表名/列/类型/注释/外键/样例)
│       ├── llm/
│       │   ├── __init__.py
│       │   ├── client.py       # 智谱 GLM-4 API 封装
│       │   └── prompts.py      # System Prompt 模板
│       ├── agent/
│       │   ├── __init__.py
│       │   ├── pipeline.py     # 核心流水线: NL → SQL → 结果
│       │   └── validator.py    # SQL 安全验证
│       └── api/
│           ├── __init__.py
│           └── routes.py       # REST API 路由定义
└── tests/
    └── ...
```

---

## 核心数据流

```
┌─────────────┐
│ 用户自然语言  │  "查询每个部门有多少员工"
└──────┬──────┘
       ▼
┌──────────────────────────────┐
│ 1. Schema 提取 (schema.py)   │  从 MySQL information_schema
│    提取表结构 + 样例数据       │  获取表名、列、类型、注释、外键
└──────┬───────────────────────┘
       ▼
┌──────────────────────────────┐
│ 2. Prompt 构建 (prompts.py)  │  System Prompt = Schema信息 + 规则
│    拼装 LLM 请求消息          │  User Message = 用户问题
└──────┬───────────────────────┘
       ▼
┌──────────────────────────────┐
│ 3. LLM 调用 (client.py)     │  调用智谱 GLM-5.1 (Anthropic 兼容)
│    生成 SQL                   │  temperature=0.1 (低，保证稳定)
└──────┬───────────────────────┘
       ▼
┌──────────────────────────────┐
│ 4. SQL 安全验证 (validator)  │  ✅ 仅允许 SELECT
│    解析 + 校验                │  ✅ 自动追加 LIMIT
│                               │  ❌ 拒绝 INSERT/UPDATE/DELETE/DROP
└──────┬───────────────────────┘
       ▼
┌──────────────────────────────┐
│ 5. 执行查询 (connection.py)  │  SQLAlchemy 执行 SQL
│    返回结果集                 │  获取列名 + 数据行
└──────┬───────────────────────┘
       ▼
┌──────────────┐
│ 查询结果      │  SQL + 列名 + 数据行 + 解释
│ 表格形式展示   │
└──────────────┘
```

---

## 各模块详细设计

### 1. config.py — 配置管理

通过 `.env` 文件管理所有敏感配置，使用 pydantic-settings 做类型校验。

**`.env` 文件内容:**

```bash
# 智谱 GLM-5.1 (Anthropic 兼容接口)
ANTHROPIC_AUTH_TOKEN=4819d0407032441ea06ed32ecd37a8dc.SR7R7hU5NsO2PIB1
ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic
LLM_MODEL=glm-5.1

# MySQL 数据库
MYSQL_HOST=localhost
MYSQL_PORT=3306
MYSQL_USER=hgh
MYSQL_PASSWORD=32420
MYSQL_DATABASE=student_db

# 查询限制
MAX_QUERY_ROWS=100
LLM_TEMPERATURE=0.1
```

**配置项:**

| 变量名 | 类型 | 默认值 | 说明 |
|--------|------|--------|------|
| `ANTHROPIC_AUTH_TOKEN` | str | 必填 | 智谱 Anthropic 兼容 API Key |
| `ANTHROPIC_BASE_URL` | str | `https://open.bigmodel.cn/api/anthropic` | API 基础地址 |
| `LLM_MODEL` | str | glm-5.1 | 使用的模型名称 |
| `MYSQL_HOST` | str | localhost | MySQL 主机 |
| `MYSQL_PORT` | int | 3306 | MySQL 端口 |
| `MYSQL_USER` | str | hgh | MySQL 用户名 |
| `MYSQL_PASSWORD` | str | 必填 | MySQL 密码 |
| `MYSQL_DATABASE` | str | 必填 | 数据库名 |
| `MAX_QUERY_ROWS` | int | 100 | 查询最大返回行数 |
| `LLM_TEMPERATURE` | float | 0.1 | LLM 温度参数 |

---

### 2. db/connection.py — MySQL 连接管理

- 使用 SQLAlchemy Engine + Session 管理连接
- 提供 `execute_query(sql) -> (columns, rows)` 函数
- 自动为没有 LIMIT 的查询追加 `LIMIT {MAX_QUERY_ROWS}`
- 连接池管理

---

### 3. db/schema.py — Schema 提取

**从 MySQL `information_schema` 提取:**
- 表名 + 表注释
- 列名 + 列类型 + 列注释 + 是否主键
- 外键关系 (哪张表的哪列引用哪张表的哪列)
- 每张表取 3 条样例数据

**格式化为 LLM 友好的文本:**

```
数据库: mydb

表: users (用户表)
列:
  - id: BIGINT, 主键, 自增
  - name: VARCHAR(100), 用户姓名
  - email: VARCHAR(200), 邮箱地址
  - department_id: BIGINT, 所属部门, 外键 → departments.id
  - created_at: DATETIME, 创建时间

样例数据 (3条):
  1. {id: 1, name: "张三", email: "zhangsan@example.com", department_id: 2, created_at: "2024-01-15"}
  2. {id: 2, name: "李四", email: "lisi@example.com", department_id: 1, created_at: "2024-02-20"}
  3. {id: 3, name: "王五", email: "wangwu@example.com", department_id: 2, created_at: "2024-03-10"}

表: departments (部门表)
列:
  - id: BIGINT, 主键, 自增
  - name: VARCHAR(100), 部门名称
  ...
```

**缓存策略:** 首次提取后缓存到内存，提供 `--refresh` 参数强制刷新。

---

### 4. llm/client.py — 智谱 GLM-5.1 API 封装 (Anthropic 兼容接口)

智谱提供 Anthropic 兼容 API，可直接使用 `anthropic` Python SDK 调用。

```python
from anthropic import Anthropic

class LLMClient:
    def __init__(self, api_key: str, base_url: str, model: str = "glm-5.1"):
        self.client = Anthropic(api_key=api_key, base_url=base_url)
        self.model = model

    def chat(self, messages: list[dict], temperature: float = 0.1) -> str:
        """调用 GLM-5.1，返回模型回复文本"""
        # 从 messages 中分离出 system 和其他消息
        system_msg = ""
        chat_msgs = []
        for m in messages:
            if m["role"] == "system":
                system_msg = m["content"]
            else:
                chat_msgs.append(m)

        response = self.client.messages.create(
            model=self.model,
            max_tokens=4096,
            system=system_msg,
            messages=chat_msgs,
            temperature=temperature,
        )
        return response.content[0].text
```

**特点:**
- temperature=0.1 → SQL 生成稳定性优先
- 支持传入多轮对话历史 (messages 列表)
- 错误重试 (网络异常、API 限流)

---

### 5. llm/prompts.py — Prompt 模板

**System Prompt 结构:**

```
你是一个专业的 MySQL 数据分析助手。用户会用自然语言提问，你需要根据数据库结构生成正确的 SQL 查询。

## 数据库结构

{schema_text}

## 规则

1. 只生成 SELECT 查询语句，不要生成 INSERT/UPDATE/DELETE/DROP 等修改数据的语句
2. 使用标准 MySQL 语法
3. 如果用户的问题模糊，生成最合理的查询
4. 如果需要 JOIN，请根据外键关系正确关联
5. 结果按相关性排序，适当使用 ORDER BY
6. 不要使用 LIMIT，系统会自动添加

## 输出格式

请用以下 JSON 格式回复:
```json
{
  "sql": "你的SQL语句",
  "explanation": "简要说明这个查询做了什么"
}
```
```

---

### 6. agent/validator.py — SQL 安全验证

**验证规则:**

| 检查项 | 规则 | 处理 |
|--------|------|------|
| 语句类型 | 只允许 SELECT | 其他类型直接拒绝 |
| LIMIT | 必须存在 | 不存在则自动追加 |
| 多语句 | 禁止 (防注入) | 包含 `;` 则拒绝 |
| 危险函数 | 禁止 LOAD_FILE, INTO OUTFILE 等 | 检测到则拒绝 |
| 行数上限 | LIMIT N ≤ MAX_QUERY_ROWS | 超过则调整为 MAX |

**实现:** 使用 `sqlparse` 解析 SQL 语句，检查 token 类型。

---

### 7. agent/pipeline.py — 核心流水线

```python
class DataAgent:
    """Text-to-SQL 核心引擎"""

    def query(self, question: str, history: list = None) -> QueryResult:
        """
        输入: 自然语言问题 (可选: 历史对话)
        输出: QueryResult(sql, columns, rows, explanation)
        """
        # 1. 获取缓存的 schema
        schema = self.schema_extractor.get_schema()

        # 2. 构建消息
        system_msg = build_system_message(schema)
        user_msg = question
        messages = [system_msg] + (history or []) + [{"role": "user", "content": user_msg}]

        # 3. 调用 LLM
        response = self.llm.chat(messages)
        sql, explanation = parse_response(response)

        # 4. 验证 SQL 安全性
        sql = self.validator.validate(sql)

        # 5. 执行查询
        columns, rows = self.db.execute_query(sql)

        # 6. 返回结果
        return QueryResult(
            sql=sql,
            columns=columns,
            rows=rows,
            explanation=explanation,
        )
```

**多轮对话支持:** 通过 `history` 参数传入之前的对话记录，LLM 能理解上下文做追问。

---

### 8. api/routes.py — REST API

**端点设计:**

#### POST `/api/v1/query` — 自然语言查询

```json
// 请求
{
  "question": "查询每个部门有多少员工",
  "conversation_id": "optional-conversation-id"
}

// 响应
{
  "sql": "SELECT d.name AS department, COUNT(u.id) AS employee_count FROM users u JOIN departments d ON u.department_id = d.id GROUP BY d.name ORDER BY employee_count DESC",
  "columns": ["department", "employee_count"],
  "rows": [["技术部", 15], ["市场部", 8], ["人事部", 5]],
  "explanation": "按部门分组统计员工数量，按人数降序排列",
  "row_count": 3
}
```

#### GET `/api/v1/schema` — 获取数据库结构

```json
// 响应
{
  "database": "mydb",
  "tables": [
    {
      "name": "users",
      "comment": "用户表",
      "columns": [
        {"name": "id", "type": "BIGINT", "comment": "主键"},
        ...
      ]
    }
  ]
}
```

#### GET `/api/v1/health` — 健康检查

```json
{ "status": "ok", "database": "connected" }
```

---

### 9. CLI 命令设计

```bash
# 交互模式 (多轮对话)
$ data-agent chat
🤖 Data Agent 已就绪 (数据库: mydb)
> 查询销售额最高的前10个客户

📝 生成 SQL:
SELECT c.name, SUM(o.amount) AS total_amount
FROM customers c JOIN orders o ON c.id = o.customer_id
GROUP BY c.name ORDER BY total_amount DESC LIMIT 10

📊 查询结果:
┌──────────┬──────────────┐
│ name     │ total_amount │
├──────────┼──────────────┤
│ 客户A    │     158000.00│
│ 客户B    │     132500.00│
│ ...      │         ...  │
└──────────┴──────────────┘
💡 说明: 按销售额降序排列的前10个客户

> 追问: 其中北京的有多少？
...

# 单次查询
$ data-agent query "查询上个月的订单总量"

# 查看数据库结构
$ data-agent schema

# 启动 API 服务
$ data-agent serve --host 0.0.0.0 --port 8000
```

---

## 依赖清单

```toml
[project]
name = "data-agent"
version = "0.1.0"
requires-python = ">=3.10"
dependencies = [
    # Web API
    "fastapi>=0.110",
    "uvicorn>=0.29",
    # CLI
    "typer>=0.12",
    "rich>=13.0",
    # 数据库
    "sqlalchemy>=2.0",
    "pymysql>=1.1",
    # LLM (智谱 Anthropic 兼容接口)
    "anthropic>=0.30",
    # 配置
    "pydantic>=2.0",
    "pydantic-settings>=2.0",
    "python-dotenv>=1.0",
    # 工具
    "sqlparse>=0.5",
]
```

---

## 安全设计

1. **只读原则**: 默认只允许 SELECT 查询，禁止任何数据修改操作
2. **SQL 注入防护**: 使用 sqlparse 解析，禁止多语句、危险函数
3. **结果集限制**: 自动追加 LIMIT，防止返回海量数据
4. **密钥管理**: 所有敏感信息通过 .env 文件管理，不硬编码
5. **API 认证** (可选扩展): 可加 API Key 认证中间件

---

## 实施顺序

| 步骤 | 内容 | 依赖 |
|------|------|------|
| 1 | 项目初始化: 目录结构、pyproject.toml、.env.example | 无 |
| 2 | config.py: 配置加载 | 步骤 1 |
| 3 | db/connection.py: MySQL 连接 | 步骤 2 |
| 4 | db/schema.py: Schema 提取 | 步骤 3 |
| 5 | llm/client.py: GLM-5.1 封装 (Anthropic SDK) | 步骤 2 |
| 6 | llm/prompts.py: Prompt 模板 | 步骤 4 |
| 7 | agent/validator.py: SQL 验证 | 步骤 1 |
| 8 | agent/pipeline.py: 核心流水线 | 步骤 3-7 |
| 9 | api/routes.py: REST API | 步骤 8 |
| 10 | main.py: CLI 入口 | 步骤 8 |
| 11 | 端到端测试 | 全部 |

---

## 验证方式

1. **连接测试**: `data-agent schema` 能正确输出 MySQL 表结构
2. **CLI 测试**: `data-agent chat` → 输入自然语言 → 验证 SQL 正确 + 结果合理
3. **API 测试**: `data-agent serve` → curl 调用 `/api/v1/query` → 验证 JSON 响应
4. **安全测试**: 输入 "删除所有用户" → 验证被拒绝
5. **多轮测试**: 连续追问 → 验证上下文理解正确
