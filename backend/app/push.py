"""Send a push notification through Firebase Cloud Messaging (HTTP v1 API).

Uses the service-account key in backend/firebase-key.json (never committed).
"""

import json
import logging
from pathlib import Path

import google.auth.transport.requests
import requests
from google.oauth2 import service_account

log = logging.getLogger(__name__)

KEY_PATH = Path(__file__).resolve().parents[1] / "firebase-key.json"
SCOPES = ["https://www.googleapis.com/auth/firebase.messaging"]

_credentials = None
_project_id = None


def _load():
    global _credentials, _project_id
    if _credentials is None:
        _credentials = service_account.Credentials.from_service_account_file(
            str(KEY_PATH), scopes=SCOPES
        )
        _project_id = json.loads(KEY_PATH.read_text())["project_id"]
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
    except Exception as exc:  # network, missing key file, bad key...
        log.warning("Push failed: %s", exc)
        return False, str(exc)[:200]
    if response.status_code == 200:
        return True, None
    log.warning("Push rejected: %s %s", response.status_code, response.text[:200])
    return False, f"{response.status_code}: {response.text[:200]}"