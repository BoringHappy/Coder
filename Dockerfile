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
# Note: agent-browser installation is skipped on ARM64 due to QEMU emulation issues with npm
# The npm security check fails under QEMU with: "Security violation: Requested utility `env` does not match executable name"
# ARM64 users can install agent-browser manually inside the container if needed
RUN if [ "$(uname -m)" = "x86_64" ]; then \
        npm install -g agent-browser && agent-browser install --with-deps; \
    else \
        echo "Skipping agent-browser installation on $(uname -m) architecture"; \
    fi

# Install Oh My Zsh for agent user
USER agent
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set ys theme in .zshrc
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /home/agent/.zshrc

# Set zsh as default shell
USER root
RUN chsh -s $(which zsh) agent

# Copy setup scripts
COPY setup /usr/local/bin/setup
RUN chmod +x /usr/local/bin/setup/setup.sh \
    && chmod +x /usr/local/bin/setup/shell/*.sh \
    && chmod +x /usr/local/bin/setup/python/*.py

# Switch to agent user for remaining operations
USER agent

# Copy skills directory to .claude/skills
COPY skills /home/agent/.claude/skills

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]
CMD ["sh", "-c", "claude --dangerously-skip-permissions --append-system-prompt \"$(cat /usr/local/bin/setup/prompt/system_prompt.txt)\""]
