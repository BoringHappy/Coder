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

# Install Oh My Zsh for agent user
USER agent
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set ys theme in .zshrc
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /home/agent/.zshrc

# Set zsh as default shell
USER root
RUN chsh -s $(which zsh) agent

# Copy skills directory and move to .claude/skills
COPY skills /usr/local/share/skills
RUN mkdir -p /home/agent/.claude/skills && \
    mv /usr/local/share/skills/* /home/agent/.claude/skills/ && \
    rmdir /usr/local/share/skills

# Copy setup scripts
COPY setup /usr/local/bin/setup
RUN chmod +x /usr/local/bin/setup/setup.sh \
    && chmod +x /usr/local/bin/setup/shell/*.sh \
    && chmod +x /usr/local/bin/setup/python/*.py

USER agent

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]
CMD ["claude", "--dangerously-skip-permissions", "--append-system-prompt", "/usr/local/bin/setup/prompt/system_prompt.txt"]
