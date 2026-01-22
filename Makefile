GIT_REPO_URL ?= $(shell git config --get remote.origin.url 2>/dev/null || echo 'https://github.com/BoringHappy/Coder.git')
BRANCH_NAME ?= test-auto-coder
PR_NUMBER ?=
PR_TITLE ?=

.PHONY: run

run:
	set -a && [ -f .env ] && . .env; set +a && \
	export GITHUB_TOKEN="$$(gh auth token)" && \
	export GIT_USER_NAME="$$(git config user.name)" && \
	export GIT_USER_EMAIL="$$(git config user.email)" && \
	docker run --rm --pull always \
		-it \
		-v ~/.claude_in_docker:/home/agent/.claude \
		-e GIT_REPO_URL=$(GIT_REPO_URL) \
		-e BRANCH_NAME=$(BRANCH_NAME) \
		-e PR_NUMBER=$(PR_NUMBER) \
		-e "PR_TITLE=$(PR_TITLE)" \
		-e GITHUB_TOKEN \
		-e GIT_USER_NAME \
		-e GIT_USER_EMAIL \
		--env-file .env \
		-w /home/agent/workspace \
		$${CODER_IMAGE:-$$(grep -s '^CODER_IMAGE=' .env | cut -d= -f2- || echo 'boringhappy/coder:main')} $(extra)
