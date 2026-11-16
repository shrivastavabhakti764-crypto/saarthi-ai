"""Send a push notification through Firebase Cloud Messaging (HTTP v1 API).

The service-account key comes from the FIREBASE_KEY_JSON environment variable
(used on Render) or, if that is not set, from backend/firebase-key.json
(local development). The key is never committed.
"""

import json
import logging
import os
from pathlib import Path

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

log = logging.getLogger(__name__)

KEY_PATH = Path(__file__).resolve().parents[1] / "firebase-key.json"
SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]

_credentials = None
_project_id = None


def _load_key_info() -> dict:
    raw = os.environ.get("FIREBASE_KEY_JSON")
    if raw:
        return json.loads(raw)
    return json.loads(KEY_PATH.read_text(encoding="utf-8"))


def _load():
    global _credentials, _project_id
    if _credentials is None:
        info = _load_key_info()
        _credentials = service_account.Credentials.from_service_account_info(
            info, scopes=SCOPES
        )
        _project_id = info["project_id"]
    if not _credentials.valid:
        _credentials.refresh(google.auth.transport.requests.Request())
    return _credentials, _project_id


def send_push(fcm_token: str, title: str, body: str) -> tuple[bool, str | None]:
    """Returns (sent, error). Never raises, so a push problem cannot break a request."""
    try:
        creds, project_id = _load()
        response = requests.post(
            f"https://fcm.googleapis.com/v1/projects/{project_id}/messages:send",
            headers={"Authorization": f"Bearer {creds.token}"},
            json={
                "message": {
                    "token": fcm_token,
                    "notification": {"title": title, "body": body},
                    "android": {"priority": "HIGH"},
                }
            },
            timeout=10,
        )
    except Exception as exc:  # network, missing key, bad key...
        log.warning("Push failed: %s", exc)
        return False, str(exc)[:200]
    if response.status_code == 200:
        return True, None
    log.warning("Push rejected: %s %s", response.status_code, response.text[:200])
    return False, f"{response.status_code}: {response.text[:200]}"