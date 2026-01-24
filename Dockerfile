ARG BASE_IMAGE=docker/sandbox-templates:claude-code
FROM ${BASE_IMAGE}

# Install zsh and dependencies
USER root

RUN apt-get update && apt-get install -y \
    zsh \
    git \
    curl \
    tree \
    && rm -rf /var/lib/apt/lists/*

# Install Node.js (required for agent-browser)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Install agent-browser globally
RUN npm install -g agent-browser \
    && agent-browser install --with-deps

# Install Playwright system dependencies as root
RUN npx playwright install-deps chromium

# Install Oh My Zsh for agent user
USER agent

# Install Playwright browsers as agent user (user-specific cache)
RUN npx playwright install chromium
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set ys theme in .zshrc
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /home/agent/.zshrc

# Add agent-browser wrapper function to use proxy from environment variable when set
RUN echo 'agent-browser() { if [ -n "$HTTPS_PROXY" ]; then command agent-browser --proxy "$HTTPS_PROXY" "$@"; else command agent-browser "$@"; fi; }' >> /home/agent/.zshrc

# Set zsh as default shell
USER root
RUN chsh -s $(which zsh) agent

# Copy setup scripts
COPY setup /usr/local/bin/setup
RUN chmod +x /usr/local/bin/setup/setup.sh \
    && chmod +x /usr/local/bin/setup/shell/*.sh \
    && chmod +x /usr/local/bin/setup/python/*.py

# Copy skills directory to setup location (will be conditionally copied to .claude/skills by setup.sh)
COPY skills /usr/local/bin/setup/skills

# Switch to agent user for remaining operations
USER agent

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]
CMD ["sh", "-c", "claude --dangerously-skip-permissions --append-system-prompt \"$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""]
