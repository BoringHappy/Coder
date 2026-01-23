GIT_REPO_URL ?= $(shell git config --get remote.origin.url 2>/dev/null || echo 'https://github.com/BoringHappy/CodeMate.git')
BRANCH_NAME ?= test-auto-codemate
PR_NUMBER ?=
PR_TITLE ?=
CODEMATE_IMAGE ?=
BASE_IMAGE ?= docker/sandbox-templates:claude-code
LOCAL_IMAGE_TAG ?= codemate:local
CONTAINER_NAME := codemate-$(shell echo $(BRANCH_NAME) | sed 's/[^a-zA-Z0-9_-]/-/g')

# Detect OS for network flag (--network host not supported on macOS)
UNAME_S := $(shell uname -s)
ifeq ($(UNAME_S),Darwin)
    NETWORK_FLAG :=
else
    NETWORK_FLAG := --network host
endif

# Extract repo name from git URL
REPO_NAME := $(shell echo $(GIT_REPO_URL) | sed 's/\.git$$//' | sed 's|.*/||')

# Common docker run command template
# Usage: $(call docker_run,<extra_flags>,<image>)
define docker_run
	set -a && if [ -f .env ]; then . ./.env; fi && set +a && \
	export GITHUB_TOKEN="$$(gh auth token)" && \
	export GIT_USER_NAME="$$(git config user.name)" && \
	export GIT_USER_EMAIL="$$(git config user.email)" && \
	[ -d $(PWD)/.claude_in_docker ] || mkdir -p $(PWD)/.claude_in_docker && \
	[ -f $(PWD)/.claude_in_docker.json ] || echo '{}' > $(PWD)/.claude_in_docker.json && \
	docker run --rm --name $(CONTAINER_NAME) $(1) \
		$(NETWORK_FLAG) \
		-it \
		-v $(PWD)/.claude_in_docker:/home/agent/.claude \
		-v $(PWD)/.claude_in_docker.json:/home/agent/.claude.json \
		-v $(PWD)/skills:/home/agent/.claude/skills \
		-v $(PWD)/settings.json:/home/agent/.claude/settings.json \
		-e GIT_REPO_URL=$(GIT_REPO_URL) \
		-e BRANCH_NAME=$(BRANCH_NAME) \
		-e PR_NUMBER=$(PR_NUMBER) \
		-e "PR_TITLE=$(PR_TITLE)" \
		-e GITHUB_TOKEN \
		-e GIT_USER_NAME \
		-e GIT_USER_EMAIL \
		--env-file .env \
		-w /home/agent/$(REPO_NAME) \
		$(2) $(extra)
endef

# Helper to run or attach to container
# Usage: $(call run_or_attach,<image>,<extra_flags>)
define run_or_attach
	@if docker ps --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
		echo -e "\033[0;32mContainer $(CONTAINER_NAME) is running.\033[0m"; \
		echo -e "\033[0;36mAttaching zsh...\033[0m"; \
		docker exec -it $(CONTAINER_NAME) zsh; \
	else \
		echo -e "\033[0;33mCreating new container $(CONTAINER_NAME)...\033[0m"; \
		$(call docker_run,$(2),$(1)); \
	fi
endef

.PHONY: run build run-local

run:
	$(call run_or_attach,$${CODEMATE_IMAGE:-ghcr.io/boringhappy/codemate:main},--pull always)

build:
	docker build --build-arg BASE_IMAGE=$(BASE_IMAGE) -t $(LOCAL_IMAGE_TAG) .

run-local:
	$(call run_or_attach,$(LOCAL_IMAGE_TAG),)
