# Build from source - Ubuntu 25.10 (Questing)
ARG BASE_IMAGE=ubuntu:questing
FROM ${BASE_IMAGE}

# Environment variables
ENV NPM_CONFIG_PREFIX=/usr/local/share/npm-global
ENV PATH=/home/agent/.local/bin:/usr/local/share/npm-global/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

# Create non-root user and configure system
RUN set -ex \
    && userdel ubuntu || true \
    && useradd --create-home --uid 1000 --shell /bin/bash agent \
    && usermod -aG sudo agent \
    && mkdir -p /etc/sudoers.d \
    && chmod 0755 /etc/sudoers.d \
    && echo "agent ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/agent \
    && echo "Defaults:%sudo env_keep += \"http_proxy https_proxy no_proxy HTTP_PROXY HTTPS_PROXY NO_PROXY SSL_CERT_FILE NODE_EXTRA_CA_CERTS REQUESTS_CA_BUNDLE\"" > /etc/sudoers.d/proxyconfig \
    && chown -R agent:agent /home/agent \
    && mkdir -p /usr/local/share/npm-global \
    && chown -R agent:agent /usr/local/share/npm-global

# Install CLI tools, development packages, Node.js LTS, and agent-browser
RUN set -euxo pipefail \
    && apt-get update \
    && apt-get install -yy --no-install-recommends ca-certificates curl gnupg locales \
    && locale-gen C.UTF-8 \
    && update-locale LANG=C.UTF-8 \
    && curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -yy --no-install-recommends \
        bc \
        cron \
        dnsutils \
        gh \
        git \
        golang \
        jq \
        less \
        lsof \
        make \
        man-db \
        nodejs \
        procps \
        psmisc \
        python3 \
        python3-pip \
        ripgrep \
        rsync \
        socat \
        sudo \
        tmux \
        tree \
        unzip \
        zsh \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && chsh -s $(which zsh) agent \
    && npm install -g agent-browser \
    && agent-browser install --with-deps \
    && npm cache clean --force \
    && npx playwright install-deps chromium

# Switch to agent user for user-specific installations
USER agent

# Install Oh My Zsh
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && sed -i 's/ZSH_THEME="robbyrussell"/ZSH_THEME="ys"/g' /home/agent/.zshrc

# Install Playwright browsers and add agent-browser wrapper function
RUN npx playwright install chromium \
    && echo 'agent-browser() { if [ -n "$HTTPS_PROXY" ]; then command agent-browser --proxy "$HTTPS_PROXY" "$@"; else command agent-browser "$@"; fi; }' >> /home/agent/.zshrc

# Install Rust, cargo, and uv
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y \
    && echo 'source $HOME/.cargo/env' >> /home/agent/.zshrc \
    && curl -LsSf https://astral.sh/uv/install.sh | sh \
    && echo 'eval "$(uv generate-shell-completion zsh)"' >> /home/agent/.zshrc

# Install Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash

# Copy setup scripts (as root for proper permissions)
USER root
COPY --chmod=755 setup /usr/local/bin/setup

# Setup cron job for PR monitoring (runs every minute)
# Using /etc/cron.d format which requires user field and is auto-loaded by cron daemon
RUN echo "* * * * * agent REPO_DIR=/home/user/repo /usr/local/bin/setup/shell/monitor-pr.sh >> /tmp/pr-monitor.log 2>&1" > /etc/cron.d/pr-monitor \
    && chmod 0644 /etc/cron.d/pr-monitor

# Switch back to agent user
USER agent

ENTRYPOINT ["/usr/local/bin/setup/setup.sh"]
CMD ["/usr/local/bin/setup/run.sh"]
