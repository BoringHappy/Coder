"""
Claude Code Agent - Python-controlled loop for automated PR comment handling.

This package provides a Python agent that implements the functionality of
`claude --dangerously-skip-permissions` with automated GitHub PR monitoring
and comment resolution.
"""

from .claude_agent import ClaudeCodeAgent, GitHubPRMonitor, main

__version__ = "0.1.0"
__all__ = ["ClaudeCodeAgent", "GitHubPRMonitor", "main"]
