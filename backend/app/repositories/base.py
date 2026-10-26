"""HostScopedRepository — D6 sealed: Repository pattern auto-inject host_id filter.

Usage:
    class HouseRepository(HostScopedRepository[House]):
        model_class = House
        host_field_name = "host_id"

    repo = HouseRepository(db, host_id=claims["sub"])
    houses = repo.list()           # automatically filtered by host_id
    house = repo.get(house_id)     # 404-safe, filtered by host_id
"""

from __future__ import annotations

from typing import Generic, Optional, Type, TypeVar

from sqlalchemy.orm import Query, Session

T = TypeVar("T")


class HostScopedRepository(Generic[T]):
    """Base repository that auto-injects host_id filter on every query.

    Subclass per model. Prevents cross-host data leakage by construction.
    """

    model_class: Type[T]
    host_field_name: str = "host_id"

    def __init__(self, db: Session, host_id: int) -> None:
        self.db = db
        self.host_id = host_id

    def _base_query(self) -> Query:  # type: ignore[type-arg]
        """Return a query pre-filtered by host_id."""
        return self.db.query(self.model_class).filter(
            getattr(self.model_class, self.host_field_name) == self.host_id
        )

    def get(self, entity_id: int) -> Optional[T]:
        """Fetch a single entity by PK — only if it belongs to this host.

        Returns None (not raises) when not found or belongs to another host.
        Callers should raise HTTPException(404) on None.
        """
        return (
            self._base_query()
            .filter(self.model_class.id == entity_id)  # type: ignore[attr-defined]
            .first()
        )

    def list(self, **filters: object) -> list[T]:
        """List all entities belonging to this host, with optional extra filters."""
        q = self._base_query()
        for key, value in filters.items():
            q = q.filter(getattr(self.model_class, key) == value)
        return q.all()

    def exists(self, entity_id: int) -> bool:
        """Return True if entity_id exists AND belongs to this host."""
        return self.get(entity_id) is not None
