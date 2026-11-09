from datetime import datetime, timedelta, timezone

from tests.test_links import (
    NOMINEE_PHONE,
    OTHER_NOMINEE_PHONE,
    SENIOR_PHONE,
    auth,
    make_code,
    redeem,
    register,
)

OTHER_SENIOR_PHONE = "9876543299"


def medicine(**overrides):
    body = {
        "kind": "medicine",
        "title": "BP tablet",
        "dosage": "1 tablet",
        "reminder_times": ["20:00", "08:00"],
    }
    body.update(overrides)
    return body


def appointment(**overrides):
    body = {
        "kind": "appointment",
        "title": "Doctor visit",
        "one_off_at": (datetime.now(timezone.utc) + timedelta(days=2)).isoformat(),
    }
    body.update(overrides)
    return body


def create(client, token, body):
    return client.post("/reminders", json=body, headers=auth(token))


def user_id(client, token):
    return client.get("/me", headers=auth(token)).json()["id"]


def link(client, senior_token, nominee_token):
    assert redeem(client, nominee_token, make_code(client, senior_token)).status_code == 201


def test_reminders_require_login(client):
    assert client.get("/reminders").status_code == 401


def test_senior_creates_a_medicine_reminder(client):
    senior = register(client, "senior", SENIOR_PHONE)

    response = create(client, senior, medicine())

    assert response.status_code == 201
    data = response.json()
    assert data["title"] == "BP tablet"
    assert data["dosage"] == "1 tablet"
    assert data["reminder_times"] == ["08:00:00", "20:00:00"]
    assert data["days_of_week"] == [1, 2, 3, 4, 5, 6, 7]
    assert data["is_active"] is True
    assert data["one_off_at"] is None


def test_duplicate_times_and_days_are_cleaned_up(client):
    senior = register(client, "senior", SENIOR_PHONE)

    response = create(
        client,
        senior,
        medicine(reminder_times=["08:00", "08:00:30"], days_of_week=[3, 1, 3]),
    )

    assert response.status_code == 201
    assert response.json()["reminder_times"] == ["08:00:00"]
    assert response.json()["days_of_week"] == [1, 3]


def test_medicine_needs_at_least_one_time(client):
    senior = register(client, "senior", SENIOR_PHONE)
    assert create(client, senior, medicine(reminder_times=[])).status_code == 422


def test_medicine_cannot_have_a_one_off_time(client):
    senior = register(client, "senior", SENIOR_PHONE)
    body = medicine(one_off_at=appointment()["one_off_at"])
    assert create(client, senior, body).status_code == 422


def test_appointment_rules(client):
    senior = register(client, "senior", SENIOR_PHONE)

    no_date = appointment()
    del no_date["one_off_at"]
    assert create(client, senior, no_date).status_code == 422
    assert create(client, senior, appointment(reminder_times=["08:00"])).status_code == 422
    assert (
        create(client, senior, appointment(one_off_at="2026-12-01T10:00:00")).status_code
        == 422
    )  # no time zone

    response = create(client, senior, appointment())
    assert response.status_code == 201
    assert response.json()["reminder_times"] == []
    assert response.json()["one_off_at"] is not None


def test_bad_values_are_rejected(client):
    senior = register(client, "senior", SENIOR_PHONE)
    for overrides in (
        {"days_of_week": [0]},
        {"days_of_week": [8]},
        {"days_of_week": []},
        {"reminder_times": ["25:00"]},
        {"title": "   "},
    ):
        assert create(client, senior, medicine(**overrides)).status_code == 422


def test_a_senior_sees_only_their_own_reminders(client):
    senior = register(client, "senior", SENIOR_PHONE)
    other = register(client, "senior", OTHER_SENIOR_PHONE)
    create(client, senior, medicine(title="Mine"))
    create(client, other, medicine(title="Theirs"))

    response = client.get("/reminders", headers=auth(senior))

    assert [r["title"] for r in response.json()] == ["Mine"]


def test_a_senior_cannot_create_for_someone_else(client):
    senior = register(client, "senior", SENIOR_PHONE)
    other = register(client, "senior", OTHER_SENIOR_PHONE)
    other_id = user_id(client, other)
    assert create(client, senior, medicine(senior_id=other_id)).status_code == 403


def test_a_linked_nominee_creates_a_reminder_for_the_senior(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    link(client, senior, nominee)
    senior_id = user_id(client, senior)

    response = create(client, nominee, medicine(senior_id=senior_id))

    assert response.status_code == 201
    assert response.json()["senior_id"] == senior_id
    assert len(client.get("/reminders", headers=auth(senior)).json()) == 1


def test_a_nominee_must_say_which_senior(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    link(client, senior, nominee)
    assert create(client, nominee, medicine()).status_code == 400


def test_an_unlinked_nominee_has_no_access(client):
    senior = register(client, "senior", SENIOR_PHONE)
    stranger = register(client, "nominee", OTHER_NOMINEE_PHONE)
    senior_id = user_id(client, senior)
    reminder_id = create(client, senior, medicine()).json()["id"]

    assert create(client, stranger, medicine(senior_id=senior_id)).status_code == 404
    assert client.get("/reminders", headers=auth(stranger)).json() == []
    assert (
        client.get(f"/reminders?senior_id={senior_id}", headers=auth(stranger)).status_code
        == 404
    )
    assert (
        client.put(
            f"/reminders/{reminder_id}", json=medicine(), headers=auth(stranger)
        ).status_code
        == 404
    )
    assert client.delete(f"/reminders/{reminder_id}", headers=auth(stranger)).status_code == 404
    assert len(client.get("/reminders", headers=auth(senior)).json()) == 1


def test_a_nominee_lists_all_linked_seniors_and_can_filter(client):
    senior_a = register(client, "senior", SENIOR_PHONE)
    senior_b = register(client, "senior", OTHER_SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    link(client, senior_a, nominee)
    link(client, senior_b, nominee)
    create(client, senior_a, medicine(title="A's tablet"))
    create(client, senior_b, medicine(title="B's tablet"))

    everything = client.get("/reminders", headers=auth(nominee)).json()
    only_a = client.get(
        f"/reminders?senior_id={user_id(client, senior_a)}", headers=auth(nominee)
    ).json()

    assert sorted(r["title"] for r in everything) == ["A's tablet", "B's tablet"]
    assert [r["title"] for r in only_a] == ["A's tablet"]


def test_a_reminder_can_be_updated_and_paused(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine()).json()["id"]

    response = client.put(
        f"/reminders/{reminder_id}",
        json=medicine(title="Sugar tablet", reminder_times=["09:30"], is_active=False),
        headers=auth(senior),
    )

    assert response.status_code == 200
    data = response.json()
    assert data["title"] == "Sugar tablet"
    assert data["reminder_times"] == ["09:30:00"]
    assert data["is_active"] is False
    assert client.get("/reminders", headers=auth(senior)).json()[0]["title"] == "Sugar tablet"


def test_a_reminder_can_be_deleted(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine()).json()["id"]

    assert client.delete(f"/reminders/{reminder_id}", headers=auth(senior)).status_code == 204
    assert client.get("/reminders", headers=auth(senior)).json() == []


def test_a_linked_nominee_can_edit_and_delete(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    link(client, senior, nominee)
    reminder_id = create(client, senior, medicine()).json()["id"]

    edited = client.put(
        f"/reminders/{reminder_id}",
        json=medicine(title="Changed by family"),
        headers=auth(nominee),
    )
    assert edited.status_code == 200
    assert edited.json()["title"] == "Changed by family"

    assert client.delete(f"/reminders/{reminder_id}", headers=auth(nominee)).status_code == 204
    assert client.get("/reminders", headers=auth(senior)).json() == []