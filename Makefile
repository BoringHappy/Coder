GIT_REPO_URL ?= $(shell git config --get remote.origin.url 2>/dev/null || echo 'https://github.com/BoringHappy/CodeMate.git')
BRANCH_NAME ?= test-auto-codemate
PR_NUMBER ?=
PR_TITLE ?=
CODEMATE_IMAGE ?=

# Extract repo name from git URL
REPO_NAME := $(shell echo $(GIT_REPO_URL) | sed 's/\.git$$//' | sed 's|.*/||')

.PHONY: run

run:
	set -a && if [ -f .env ]; then . ./.env; fi && set +a && \
	export GITHUB_TOKEN="$$(gh auth token)" && \
	export GIT_USER_NAME="$$(git config user.name)" && \
	export GIT_USER_EMAIL="$$(git config user.email)" && \
	[ -f ~/.claude_in_docker.json ] || echo '{}' > ~/.claude_in_docker.json && \
	docker run --rm --pull always \
		--network host \
		-it \
		-v ~/.claude_in_docker:/home/agent/.claude \
		-v ~/.claude_in_docker.json:/home/agent/.claude.json \
		-e GIT_REPO_URL=$(GIT_REPO_URL) \
		-e BRANCH_NAME=$(BRANCH_NAME) \
		-e PR_NUMBER=$(PR_NUMBER) \
		-e "PR_TITLE=$(PR_TITLE)" \
		-e GITHUB_TOKEN \
		-e GIT_USER_NAME \
		-e GIT_USER_EMAIL \
		--env-file .env \
		-w /home/agent/$(REPO_NAME) \
		$${CODEMATE_IMAGE:-ghcr.io/boringhappy/codemate:main} $(extra)
