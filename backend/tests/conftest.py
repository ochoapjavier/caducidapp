"""Pytest configuration and fixtures for backend testing."""
import os
import pytest
from datetime import date, datetime, timedelta
from typing import Generator
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker, Session
from sqlalchemy.pool import StaticPool

# Ensure test environment
os.environ["TESTING"] = "1"

from database import Base, get_db
import models
from main import app
from auth.firebase_auth import get_current_user_id, get_current_user

# In-memory SQLite engine for tests
SQLALCHEMY_DATABASE_URL = "sqlite:///:memory:"

engine = create_engine(
    SQLALCHEMY_DATABASE_URL,
    connect_args={"check_same_thread": False},
    poolclass=StaticPool,
)
TestingSessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


@pytest.fixture(scope="session", autouse=True)
def setup_database():
    """Create all tables once for the test session."""
    Base.metadata.create_all(bind=engine)
    yield
    Base.metadata.drop_all(bind=engine)


@pytest.fixture
def db_session() -> Generator[Session, None, None]:
    """Provide a transactional database session for each test, rolling back at the end."""
    connection = engine.connect()
    transaction = connection.begin()
    session = TestingSessionLocal(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture
def test_user_id() -> str:
    """Default test Firebase UID."""
    return "test-user-uid-12345"


@pytest.fixture
def test_hogar(db_session: Session, test_user_id: str) -> models.Hogar:
    """Create a default test household with admin membership."""
    hogar = models.Hogar(
        nombre="Casa de Prueba",
        created_by=test_user_id,
        icono="home",
        codigo_invitacion="TEST1234",
    )
    db_session.add(hogar)
    db_session.commit()
    db_session.refresh(hogar)

    miembro = models.HogarMiembro(
        fk_hogar=hogar.id_hogar,
        user_id=test_user_id,
        rol="admin",
        apodo="Admin Tester",
    )
    db_session.add(miembro)
    db_session.commit()
    return hogar


@pytest.fixture
def test_locations(db_session: Session, test_hogar: models.Hogar) -> dict:
    """Create basic locations: fridge, pantry, and freezer."""
    nevera = models.Location(
        nombre="Nevera",
        hogar_id=test_hogar.id_hogar,
        es_congelador=False,
    )
    despensa = models.Location(
        nombre="Despensa",
        hogar_id=test_hogar.id_hogar,
        es_congelador=False,
    )
    congelador = models.Location(
        nombre="Congelador",
        hogar_id=test_hogar.id_hogar,
        es_congelador=True,
    )
    db_session.add_all([nevera, despensa, congelador])
    db_session.commit()
    for loc in [nevera, despensa, congelador]:
        db_session.refresh(loc)

    return {"nevera": nevera, "despensa": despensa, "congelador": congelador}


@pytest.fixture
def test_product(db_session: Session, test_hogar: models.Hogar) -> models.Product:
    """Create a sample master product."""
    product = models.Product(
        barcode="841000000001",
        nombre="Leche Entera",
        marca="Hacendado",
        dias_consumo_abierto=3,
        hogar_id=test_hogar.id_hogar,
        nova_group=1,
        nutriscore_grade="b",
    )
    db_session.add(product)
    db_session.commit()
    db_session.refresh(product)
    return product


@pytest.fixture
def client(db_session: Session, test_user_id: str) -> Generator[TestClient, None, None]:
    """TestClient configured with dependency overrides for DB and Firebase Auth."""
    def override_get_db():
        try:
            yield db_session
        finally:
            pass

    def override_get_current_user_id():
        return test_user_id

    def override_get_current_user():
        return {"uid": test_user_id, "email": "tester@example.com"}

    app.dependency_overrides[get_db] = override_get_db
    app.dependency_overrides[get_current_user_id] = override_get_current_user_id
    app.dependency_overrides[get_current_user] = override_get_current_user

    with TestClient(app) as test_client:
        yield test_client

    app.dependency_overrides.clear()

