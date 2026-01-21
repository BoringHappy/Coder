FROM docker/sandbox-templates:claude-code

# Install zsh and dependencies
USER root

RUN apt-get update && apt-get install -y \
    zsh \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Oh My Zsh for agent user
USER agent
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Set ys theme in .zshrc
RUN sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /home/agent/.zshrc

# Set zsh as default shell
USER root
RUN chsh -s $(which zsh) agent

# Copy the setup script
COPY setup-git-pr.py /usr/local/bin/setup-git-pr.py
RUN chmod +x /usr/local/bin/setup-git-pr.py

# Create entrypoint wrapper
RUN echo '#!/bin/bash\n\
python3 /usr/local/bin/setup-git-pr.py\n\
exec "$@"' > /usr/local/bin/entrypoint-wrapper.sh && \
    chmod +x /usr/local/bin/entrypoint-wrapper.sh

USER agent

ENTRYPOINT ["/usr/local/bin/entrypoint-wrapper.sh"]
CMD ["claude", "--dangerously-skip-permissions"]
