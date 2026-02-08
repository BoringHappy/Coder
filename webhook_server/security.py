"""Webhook signature verification."""

import hashlib
import hmac

from .config import WEBHOOK_SECRET, logger


def verify_signature(payload_body: bytes, signature_header: str) -> bool:
    """Verify the GitHub webhook HMAC-SHA256 signature."""
    if not WEBHOOK_SECRET:
        logger.warning("GITHUB_WEBHOOK_SECRET not set, skipping signature verification")
        return True

    if not signature_header:
        logger.error("No X-Hub-Signature-256 header present")
        return False

    hash_algorithm, _, signature = signature_header.partition("=")
    if hash_algorithm != "sha256":
        logger.error(f"Unexpected hash algorithm: {hash_algorithm}")
        return False

    expected = hmac.new(
        WEBHOOK_SECRET.encode("utf-8"),
        payload_body,
        hashlib.sha256,
    ).hexdigest()

    return hmac.compare_digest(signature, expected)
