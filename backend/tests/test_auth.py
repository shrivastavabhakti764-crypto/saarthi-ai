def make_user(client, **overrides):
    body = {
        "name": "Test Senior",
        "phone": "9876543210",
        "pin": "1234",
        "role": "senior",
    }
    body.update(overrides)
    return client.post("/auth/register", json=body)


def login(client, phone="9876543210", pin="1234"):
    return client.post("/auth/login", json={"phone": phone, "pin": pin})


def test_health_ok(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "database": "connected"}


def test_register_success(client):
    response = make_user(client)
    assert response.status_code == 201
    data = response.json()
    assert "access_token" in data
    assert data["user"]["phone"] == "+919876543210"
    assert data["user"]["role"] == "senior"
    assert "pin" not in data["user"]
    assert "pin_hash" not in data["user"]


def test_register_duplicate_phone_returns_409(client):
    assert make_user(client).status_code == 201
    assert make_user(client).status_code == 409


def test_register_same_phone_different_format_returns_409(client):
    assert make_user(client).status_code == 201
    assert make_user(client, phone="+91 98765 43210").status_code == 409


def test_register_rejects_short_pin(client):
    assert make_user(client, pin="12").status_code == 422


def test_register_rejects_bad_phone(client):
    assert make_user(client, phone="123").status_code == 422


def test_login_success(client):
    make_user(client)
    response = login(client)
    assert response.status_code == 200
    assert "access_token" in response.json()


def test_login_wrong_pin_returns_401(client):
    make_user(client)
    response = login(client, pin="9999")
    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect phone number or PIN"


def test_login_unknown_phone_returns_401(client):
    response = login(client, phone="9123456789")
    assert response.status_code == 401
    assert response.json()["detail"] == "Incorrect phone number or PIN"


def test_login_locks_after_five_failures(client):
    make_user(client)
    for _ in range(5):
        assert login(client, pin="9999").status_code == 401
    locked = login(client, pin="9999")
    assert locked.status_code == 429
    assert "Retry-After" in locked.headers
    # even the correct PIN is refused while locked
    assert login(client, pin="1234").status_code == 429


def test_me_without_token_returns_401(client):
    assert client.get("/me").status_code == 401


def test_me_with_valid_token_returns_200(client):
    token = make_user(client).json()["access_token"]
    response = client.get("/me", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["name"] == "Test Senior"


def test_me_with_fake_token_returns_401(client):
    response = client.get("/me", headers={"Authorization": "Bearer abc.def.ghi"})
    assert response.status_code == 401