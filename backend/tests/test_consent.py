def register(client, role="senior", phone="9876543210"):
    response = client.post(
        "/auth/register",
        json={"name": "Test", "phone": phone, "pin": "1234", "role": role},
    )
    assert response.status_code == 201
    return response.json()["access_token"]


def auth(token):
    return {"Authorization": f"Bearer {token}"}


def test_consent_requires_login(client):
    assert client.post("/me/consent").status_code == 401


def test_senior_can_give_consent(client):
    token = register(client)
    assert client.get("/me", headers=auth(token)).json()["consent_accepted_at"] is None

    response = client.post("/me/consent", headers=auth(token))

    assert response.status_code == 200
    assert response.json()["consent_accepted_at"] is not None
    assert client.get("/me", headers=auth(token)).json()["consent_accepted_at"] is not None


def test_consent_is_recorded_only_once(client):
    token = register(client)
    first = client.post("/me/consent", headers=auth(token)).json()["consent_accepted_at"]
    second = client.post("/me/consent", headers=auth(token)).json()["consent_accepted_at"]
    assert first == second


def test_nominee_cannot_give_consent(client):
    token = register(client, role="nominee")
    response = client.post("/me/consent", headers=auth(token))
    assert response.status_code == 403