"""CodeMate Webhook Server package."""

from .app import app


def main():
    """Entry point — run with uvicorn."""
    import uvicorn

    from .config import PORT

    uvicorn.run(
        "webhook_server.app:app",
        host="0.0.0.0",
        port=PORT,
        log_level="info",
    )
