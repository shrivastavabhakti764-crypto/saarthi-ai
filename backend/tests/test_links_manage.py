from tests.test_links import (
    NOMINEE_PHONE,
    OTHER_NOMINEE_PHONE,
    SENIOR_PHONE,
    auth,
    make_code,
    redeem,
    register,
)


def linked_pair(client):
    """A senior and a nominee who are already linked."""
    senior = register(client, "senior", SENIOR_PHONE, name="Asha")
    nominee = register(client, "nominee", NOMINEE_PHONE, name="Rohan")
    response = redeem(client, nominee, make_code(client, senior))
    assert response.status_code == 201
    return senior, nominee, response.json()["id"]


def test_links_require_login(client):
    assert client.get("/links").status_code == 401


def test_new_user_has_no_links(client):
    senior = register(client, "senior", SENIOR_PHONE)
    response = client.get("/links", headers=auth(senior))
    assert response.status_code == 200
    assert response.json() == []


def test_both_sides_see_the_link(client):
    senior, nominee, _ = linked_pair(client)

    seen_by_senior = client.get("/links", headers=auth(senior)).json()
    seen_by_nominee = client.get("/links", headers=auth(nominee)).json()

    assert len(seen_by_senior) == 1
    assert seen_by_senior[0]["nominee_name"] == "Rohan"
    assert len(seen_by_nominee) == 1
    assert seen_by_nominee[0]["senior_name"] == "Asha"


def test_an_unlinked_nominee_sees_nothing(client):
    linked_pair(client)
    stranger = register(client, "nominee", OTHER_NOMINEE_PHONE)
    assert client.get("/links", headers=auth(stranger)).json() == []


def test_senior_can_unlink(client):
    senior, nominee, link_id = linked_pair(client)

    response = client.delete(f"/links/{link_id}", headers=auth(senior))

    assert response.status_code == 204
    assert client.get("/links", headers=auth(senior)).json() == []
    assert client.get("/links", headers=auth(nominee)).json() == []


def test_nominee_can_unlink(client):
    senior, nominee, link_id = linked_pair(client)
    assert client.delete(f"/links/{link_id}", headers=auth(nominee)).status_code == 204
    assert client.get("/links", headers=auth(senior)).json() == []


def test_a_stranger_cannot_unlink(client):
    senior, _, link_id = linked_pair(client)
    stranger = register(client, "nominee", OTHER_NOMINEE_PHONE)

    response = client.delete(f"/links/{link_id}", headers=auth(stranger))

    assert response.status_code == 404
    assert len(client.get("/links", headers=auth(senior)).json()) == 1


def test_unknown_link_returns_404(client):
    senior = register(client, "senior", SENIOR_PHONE)
    assert client.delete("/links/999", headers=auth(senior)).status_code == 404


def test_can_link_again_after_unlinking(client):
    senior, nominee, link_id = linked_pair(client)
    client.delete(f"/links/{link_id}", headers=auth(senior))

    response = redeem(client, nominee, make_code(client, senior))

    assert response.status_code == 201