BRANCH_NAME ?= test-auto-coder
PR_TITLE ?=

.PHONY: run

run:
	docker run --rm --pull always \
		-it \
		-v ~/.claude_in_docker:/home/agent/.claude \
		-e GIT_REPO_URL=$${GIT_REPO_URL:-https://github.com/BoringHappy/Coder.git} \
		-e BRANCH_NAME=$(BRANCH_NAME) \
		-e PR_NUMBER=$${PR_NUMBER:-} \
		-e "PR_TITLE=$(PR_TITLE)" \
		-e "GITHUB_TOKEN=$$(gh auth token)" \
		-e "GIT_USER_NAME=$$(git config user.name)" \
		-e "GIT_USER_EMAIL=$$(git config user.email)" \
		--env-file .env \
		-w /home/agent/workspace \
		$${CODER_IMAGE:-boringhappy/coder:main} $(extra)
