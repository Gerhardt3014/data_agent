"""Data Agent 入口 - CLI 命令 + FastAPI 应用"""

import typer
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.syntax import Syntax

from data_agent.config import get_settings
from data_agent.db.schema import get_schema, format_schema_for_llm
from data_agent.db.connection import test_connection
from data_agent.agent.pipeline import DataAgent

console = Console()
app = typer.Typer(name="data-agent", help="Text-to-SQL 数据智能代理", no_args_is_help=True)


@app.command()
def chat():
    """启动交互式对话模式"""
    settings = get_settings()

    # 检查数据库连接
    if not test_connection(settings):
        console.print("[red]✗ 数据库连接失败，请检查 .env 配置[/red]")
        raise typer.Exit(1)

    console.print(Panel.fit(
        f"[bold green]🤖 Data Agent 已就绪[/bold green]\n"
        f"数据库: [cyan]{settings.mysql_database}[/cyan]\n"
        f"输入自然语言问题查询，输入 [bold]exit[/bold] 或 [bold]quit[/bold] 退出",
    ))

    agent = DataAgent(settings)
    history: list[dict] = []

    while True:
        try:
            question = console.input("\n[bold cyan]> [/bold cyan]").strip()
        except (EOFError, KeyboardInterrupt):
            console.print("\n[dim]再见！[/dim]")
            break

        if not question:
            continue
        if question.lower() in ("exit", "quit", "q"):
            console.print("[dim]再见！[/dim]")
            break

        # 执行查询
        with console.status("[bold green]思考中...[/bold green]"):
            result = agent.query(question, history=history if history else None)

        # 显示结果
        if result.error and not result.sql:
            console.print(f"[red]✗ {result.error}[/red]")
            continue

        # 显示 SQL
        console.print()
        syntax = Syntax(result.sql, "sql", theme="monokai", line_numbers=False)
        console.print(Panel(syntax, title="📝 生成 SQL", border_style="blue"))

        # 显示查询结果
        if result.columns and result.rows:
            table = Table(title="📊 查询结果", show_lines=True)
            for col in result.columns:
                table.add_column(col, style="cyan")
            for row in result.rows:
                table.add_row(*[str(v) if v is not None else "NULL" for v in row])
            console.print(table)
            console.print(f"[dim]共 {len(result.rows)} 行[/dim]")
        else:
            console.print("[yellow]查询无结果[/yellow]")

        # 显示解释
        if result.explanation:
            console.print(f"[dim]💡 {result.explanation}[/dim]")

        # 显示错误 (SQL 有但执行失败的情况)
        if result.error:
            console.print(f"[red]⚠ {result.error}[/red]")

        # 更新历史
        history.append({"role": "user", "content": question})
        history.append({"role": "assistant", "content": result.sql})


@app.command()
def query(question: str):
    """单次自然语言查询"""
    settings = get_settings()
    agent = DataAgent(settings)
    result = agent.query(question)

    if result.error and not result.sql:
        console.print(f"[red]✗ {result.error}[/red]")
        raise typer.Exit(1)

    # SQL
    syntax = Syntax(result.sql, "sql", theme="monokai", line_numbers=False)
    console.print(Panel(syntax, title="SQL", border_style="blue"))

    # 结果表格
    if result.columns and result.rows:
        table = Table(show_lines=True)
        for col in result.columns:
            table.add_column(col, style="cyan")
        for row in result.rows:
            table.add_row(*[str(v) if v is not None else "NULL" for v in row])
        console.print(table)
        console.print(f"[dim]共 {len(result.rows)} 行[/dim]")

    if result.explanation:
        console.print(f"[dim]💡 {result.explanation}[/dim]")

    if result.error:
        console.print(f"[red]⚠ {result.error}[/red]")


@app.command()
def schema():
    """查看数据库结构"""
    settings = get_settings()

    if not test_connection(settings):
        console.print("[red]✗ 数据库连接失败[/red]")
        raise typer.Exit(1)

    db_schema = get_schema(settings)
    text = format_schema_for_llm(db_schema)
    console.print(Panel(text, title=f"数据库: {settings.mysql_database}", border_style="green"))


@app.command()
def serve(host: str = "0.0.0.0", port: int = 8000):
    """启动 REST API 服务"""
    import uvicorn
    from fastapi import FastAPI
    from data_agent.api.routes import router

    api_app = FastAPI(
        title="Data Agent API",
        description="Text-to-SQL 数据智能代理 API",
        version="0.1.0",
    )
    api_app.include_router(router)

    console.print(f"[bold green]🚀 Data Agent API 启动: http://{host}:{port}[/bold green]")
    console.print(f"[dim]API 文档: http://{host}:{port}/docs[/dim]")
    uvicorn.run(api_app, host=host, port=port)


if __name__ == "__main__":
    app()
