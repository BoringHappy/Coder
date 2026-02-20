# CodeMate - Docker environment for Claude Code with automated Git/PR setup
# Uses the base image which contains system packages and development tools
ARG BASE_IMAGE=ghcr.io/boringhappy/codemate-base:latest
FROM ${BASE_IMAGE}

# Switch to root for setup operations
USER root

# Copy setup scripts as root (755 allows agent user to read/execute)
COPY --chmod=755 setup /usr/local/bin/setup

# Setup cron job for PR monitoring (runs every minute)
# Using /etc/cron.d format which requires user field and is auto-loaded by cron daemon
# Note: Environment variables are read from /proc/1/environ by monitor-pr.sh
RUN echo "* * * * * agent /usr/local/bin/setup/shell/monitor-pr.sh >> /tmp/pr-monitor.log 2>&1" > /etc/cron.d/pr-monitor \
    && chmod 0644 /etc/cron.d/pr-monitor

# Environment variables for plugin configuration
ENV DEFAULT_MARKETPLACES="vercel-labs/agent-browser,BoringHappy/CodeMate"
ENV DEFAULT_PLUGINS="agent-browser@agent-browser,git@codemate,pr@codemate,dev@codemate,issue@codemate,workspace@codemate,pm@codemate"

# Switch to agent user and install Claude Code
USER agent
RUN curl -fsSL https://claude.ai/install.sh | bash

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]
CMD ["/usr/local/bin/setup/run.sh"]
