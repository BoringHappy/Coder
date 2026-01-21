FROM registry-proxy.datalake.vip/docker/sandbox-templates:claude-code

# Copy the setup script
USER root

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
