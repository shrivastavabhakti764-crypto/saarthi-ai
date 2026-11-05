import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

from app import models  # noqa: F401  (registers all tables on Base.metadata)
from app import rate_limit
from app.config import settings
from app.db import Base, get_db
from app.main import app

# Tests ALWAYS run on a separate database, never on the real "saarthi" one.
TEST_DB_NAME = "saarthi_test"
test_engine = create_engine(
    settings.database_url.set(database=TEST_DB_NAME), pool_pre_ping=True
)
assert test_engine.url.database == TEST_DB_NAME

TestingSession = sessionmaker(bind=test_engine, autoflush=False, autocommit=False)


@pytest.fixture(autouse=True)
def fresh_database():
    """Before every test: empty tables and a clean login-attempt counter."""
    Base.metadata.drop_all(test_engine)
    Base.metadata.create_all(test_engine)
    rate_limit._failures.clear()
    yield


@pytest.fixture
def client():
    def override_get_db():
        db = TestingSession()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as test_client:
        yield test_client
    app.dependency_overrides.clear()