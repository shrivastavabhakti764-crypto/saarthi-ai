from datetime import datetime, timedelta, timezone

from sqlalchemy import update

from app.models import LinkCode
from tests.conftest import TestingSession

SENIOR_PHONE = "9876543210"
NOMINEE_PHONE = "9123456780"
OTHER_NOMINEE_PHONE = "9123456781"


def register(client, role, phone, name="Test"):
    response = client.post(
        "/auth/register",
        json={"name": name, "phone": phone, "pin": "1234", "role": role},
    )
    assert response.status_code == 201
    return response.json()["access_token"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def make_code(client, senior_token):
    response = client.post("/links/code", headers=auth(senior_token))
    assert response.status_code == 201
    return response.json()["code"]


def redeem(client, nominee_token, code, **overrides):
    body = {"code": code, "relationship": "son"}
    body.update(overrides)
    return client.post("/links/redeem", json=body, headers=auth(nominee_token))


def test_code_requires_login(client):
    assert client.post("/links/code").status_code == 401


def test_senior_gets_a_six_digit_code(client):
    senior = register(client, "senior", SENIOR_PHONE)
    response = client.post("/links/code", headers=auth(senior))
    assert response.status_code == 201
    data = response.json()
    assert len(data["code"]) == 6 and data["code"].isdigit()
    assert data["expires_at"]


def test_nominee_cannot_create_a_code(client):
    nominee = register(client, "nominee", NOMINEE_PHONE)
    assert client.post("/links/code", headers=auth(nominee)).status_code == 403


def test_new_code_replaces_the_old_one(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    first = make_code(client, senior)
    second = make_code(client, senior)
    if first != second:
        assert redeem(client, nominee, first).status_code == 400
    assert redeem(client, nominee, second).status_code == 201


def test_nominee_links_with_a_code(client):
    senior = register(client, "senior", SENIOR_PHONE, name="Asha")
    nominee = register(client, "nominee", NOMINEE_PHONE, name="Rohan")
    code = make_code(client, senior)

    response = redeem(client, nominee, code, relationship="son")

    assert response.status_code == 201
    data = response.json()
    assert data["senior_name"] == "Asha"
    assert data["nominee_name"] == "Rohan"
    assert data["relationship"] == "son"
    assert data["whatsapp_number"] is None
    assert data["whatsapp_opt_in"] is False


def test_whatsapp_number_is_normalised_and_opt_in_saved(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    code = make_code(client, senior)

    response = redeem(
        client, nominee, code, whatsapp_number="98765 43211", whatsapp_opt_in=True
    )

    assert response.status_code == 201
    assert response.json()["whatsapp_number"] == "+919876543211"
    assert response.json()["whatsapp_opt_in"] is True


def test_opt_in_without_a_number_is_rejected(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    code = make_code(client, senior)
    assert redeem(client, nominee, code, whatsapp_opt_in=True).status_code == 422


def test_code_can_only_be_used_once(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    other = register(client, "nominee", OTHER_NOMINEE_PHONE)
    code = make_code(client, senior)

    assert redeem(client, nominee, code).status_code == 201
    assert redeem(client, other, code).status_code == 400


def test_expired_code_is_rejected(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    code = make_code(client, senior)

    with TestingSession() as db:
        db.execute(
            update(LinkCode).values(
                expires_at=datetime.now(timezone.utc) - timedelta(minutes=1)
            )
        )
        db.commit()

    response = redeem(client, nominee, code)
    assert response.status_code == 400
    assert response.json()["detail"] == "This code is not valid or has expired"


def test_wrong_code_is_rejected(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    code = make_code(client, senior)
    wrong = "000000" if code != "000000" else "000001"
    assert redeem(client, nominee, wrong).status_code == 400


def test_senior_cannot_use_a_code(client):
    senior = register(client, "senior", SENIOR_PHONE)
    code = make_code(client, senior)
    assert redeem(client, senior, code).status_code == 403


def test_linking_twice_to_the_same_senior_returns_409(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    assert redeem(client, nominee, make_code(client, senior)).status_code == 201
    assert redeem(client, nominee, make_code(client, senior)).status_code == 409


def test_five_wrong_codes_lock_the_nominee(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    code = make_code(client, senior)
    wrong = "000000" if code != "000000" else "000001"

    for _ in range(5):
        assert redeem(client, nominee, wrong).status_code == 400

    locked = redeem(client, nominee, code)
    assert locked.status_code == 429
    assert "Retry-After" in locked.headers