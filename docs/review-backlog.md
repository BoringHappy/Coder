# Webhook Server — Review Backlog

Findings from a three-angle review (security, architecture, ops) of PR #156.
The comment queue consumer has been implemented. All remaining items are
recorded here for future work.

---

## Critical

### Webhook signature bypass when secret is unset
- **File:** `webhook_server/security.py:11-13`
- When `GITHUB_WEBHOOK_SECRET` is not set, `verify_signature()` returns `True`
  unconditionally, accepting any payload from any source.
- **Action:** Make the webhook secret required, or at minimum log a loud
  startup warning and refuse to start in production mode without it.

### Synchronous blocking in async FastAPI handlers
- **File:** `webhook_server/app.py:85-112`, `webhook_server/services.py`
- `handle_new_issue()` and `handle_issue_comment()` perform git clone, push,
  PR creation, and `time.sleep()` directly on the asyncio event loop. This
  blocks all other requests during processing.
- **Action:** Run handlers via `asyncio.to_thread()` or
  `loop.run_in_executor()`.

### In-memory session state lost on restart
- **File:** `webhook_server/services.py:16`
- The `sessions` dict is purely in-memory. On restart, all tracking is lost
  and orphaned tmux sessions cannot be rediscovered.
- **Action:** Persist session state to disk (JSON file or SQLite) and
  reconcile with running tmux sessions on startup.

---

## High

### Shell injection surface via `shell=True`
- **File:** `webhook_server/services.py:22-27`
- `run()` uses `subprocess.run(cmd, shell=True)`. While callers use
  `shlex.quote()`, the pattern is fragile — any missed quoting is an
  injection vector.
- **Action:** Refactor `run()` to accept argument lists and use
  `shell=False` where possible.

### Private key in environment variable
- **File:** `docker-compose.yml:14`, `webhook_server/github_auth.py`
- `GITHUB_APP_PRIVATE_KEY` as an inline env var is visible in `docker
  inspect`, `/proc/environ`, and logs.
- **Action:** Prefer file-based key loading (`GITHUB_APP_PRIVATE_KEY_FILE`)
  and document that the inline env var should only be used for development.

### `--dangerously-skip-permissions` on untrusted content
- **File:** `webhook_server/services.py:252`
- Claude Code runs without permission prompts. Combined with the signature
  bypass, an attacker can trigger arbitrary code execution via crafted issue
  content.
- **Action:** Ensure webhook secret is always required. Consider sandboxing
  the Claude session further (network policy, read-only mounts).

### Global PR status file race
- **File:** `webhook_server/services.py:237`
- `_write_pr_status` writes to a single `/tmp/.pr_status` file. Concurrent
  issues overwrite each other's PR URL.
- **Action:** Use per-session PR status files (similar to the session data
  directory pattern).

### `send_command_to_session` always returns True
- **File:** `webhook_server/services.py:79-103`
- Even when all retry attempts fail, the function returns `True`. Callers
  cannot detect delivery failure.
- **Action:** Return `False` on exhausted retries and handle the failure in
  callers.

### No resource limits on webhook container
- **File:** `docker-compose.yml`
- No CPU or memory limits. A burst of issues could exhaust the host.
- **Action:** Add `deploy.resources.limits` in docker-compose.

---

## Medium

### SSRF via installation ID from webhook payload
- **File:** `webhook_server/github_auth.py:64, 167-173`
- A forged webhook could set `installation_id` to a path-traversal value,
  causing authenticated requests to arbitrary GitHub API paths.
- **Action:** Validate that `installation_id` is a positive integer.

### Token leakage in error messages
- **File:** `webhook_server/github_auth.py:77-81`
- HTTP error bodies from the token exchange are included in exceptions and
  may appear in logs.
- **Action:** Sanitize error messages before logging.

### Health endpoint exposes session metadata
- **File:** `webhook_server/app.py:38-54`
- Unauthenticated `/health` reveals repo names, issue numbers, and PR URLs.
- **Action:** Add optional auth or reduce the detail level for
  unauthenticated callers.

### No subprocess timeouts
- **Files:** `webhook_server/services.py:24`, `webhook_server/github_auth.py`
- No `timeout` parameter on `subprocess.run()` calls. A hung git operation
  blocks the event loop indefinitely.
- **Action:** Add reasonable timeouts (e.g., 120s for clone, 30s for auth).

### Token refresh buffer may be insufficient
- **File:** `webhook_server/github_auth.py:35`
- The 5-minute buffer may not cover long-running operations like clone + PR
  creation.
- **Action:** Increase buffer or re-check token validity before each
  subprocess call.

### Health endpoint iterates mutable dict
- **File:** `webhook_server/app.py:41-48`
- If handlers move to threads, iterating `sessions.items()` concurrently
  with mutations raises `RuntimeError`.
- **Action:** Use a lock or `dict.copy()` before iteration.

### Zombie tmux sessions accumulate
- **File:** `webhook_server/services.py`
- Sessions are created but never cleaned up. No TTL, max count, or reaper.
- **Action:** Add a periodic cleanup task or handle `issues.closed` events.

### `SESSION_DATA_DIR` not persisted via volume
- **File:** `docker-compose.yml`
- Session data files live inside the container and are lost on restart.
- **Action:** Add a named volume for `SESSION_DATA_DIR`.

### No `uv.lock` committed
- Dependencies resolve fresh on every build, making builds non-reproducible.
- **Action:** Run `uv lock` and commit `uv.lock`.

### Missing env vars in `.env.example`
- `GITHUB_TOKEN` and `ANTHROPIC_API_KEY` are not in `.env.example`.
- **Action:** Add them as commented entries.

### `env_file` and `environment` overlap
- **File:** `docker-compose.yml`
- Explicit `environment:` entries override `.env` file values, which can
  confuse users.
- **Action:** Document the precedence or consolidate to one approach.

### No log rotation
- Loguru outputs to stdout with no rotation config in docker-compose.
- **Action:** Add `logging:` options in compose or document Docker daemon
  log rotation requirements.

---

## Low

### Webhook port exposed on all interfaces
- **File:** `docker-compose.yml:7`
- Port binds to `0.0.0.0`. Should be `127.0.0.1` when behind a proxy.

### No `.dockerignore`
- Build context includes `.git/`, `tests/`, `.env`, etc.

### `cloudflared` image not version-pinned
- **File:** `docker-compose.yml:24`
- Uses `:latest` tag.

### No healthcheck in docker-compose
- The `/health` endpoint exists but no `healthcheck:` directive is defined.

### `SESSION_DATA_DIR` not in env var docs
- **File:** `docs/webhook-server.md`

### No graceful shutdown for tmux sessions
- Running sessions are not cleaned up on container stop.

### No rate limiting on webhook endpoint
- A misconfigured webhook or replay attack could spawn many sessions.

### Hardcoded branch naming convention
- **File:** `webhook_server/services.py:148`
- Branch names are `issue-{N}` with no configurability.
