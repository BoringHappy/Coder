.PHONY: run

run:
	-GIT_USER_NAME="$$(git config user.name)" \
	GIT_USER_EMAIL="$$(git config user.email)" \
	GITHUB_TOKEN="$$(gh auth token)" \
	docker compose run --rm --pull always claude ${extra}
