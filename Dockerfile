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

# Install Node.js and agent-browser in one layer (required for agent-browser)
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g agent-browser \
    && agent-browser install --with-deps \
    && npm cache clean --force \
    && npx playwright install-deps chromium

# Install Playwright browsers and configure Oh My Zsh for agent user
USER agent
RUN npx playwright install chromium \
    && sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /home/agent/.zshrc \
    && echo 'agent-browser() { if [ -n "$HTTPS_PROXY" ]; then command agent-browser --proxy "$HTTPS_PROXY" "$@"; else command agent-browser "$@"; fi; }' >> /home/agent/.zshrc

# Set zsh as default shell, copy setup scripts, and set permissions
USER root
RUN chsh -s $(which zsh) agent
COPY setup /usr/local/bin/setup
COPY skills /usr/local/bin/setup/skills
RUN chmod +x /usr/local/bin/setup/setup.sh \
    && chmod +x /usr/local/bin/setup/shell/*.sh \
    && chmod +x /usr/local/bin/setup/python/*.py

# Switch to agent user for remaining operations
USER agent

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]
CMD ["sh", "-c", "claude --dangerously-skip-permissions --append-system-prompt \"$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""]
