from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import settings

# pool_pre_ping checks a connection is alive before using it (avoids stale-connection errors)
engine = create_engine(settings.database_url, pool_pre_ping=True)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    """All SQLAlchemy models will inherit from this."""


def get_db():
    """FastAPI dependency: gives each request its own DB session and always closes it."""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()