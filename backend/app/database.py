from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, DeclarativeBase, Session

from app.config import settings


# SQLite cần connect_args đặc biệt khi share connection giữa threads (FastAPI sẽ làm vậy)
connect_args = {"check_same_thread": False} if settings.database_url.startswith("sqlite") else {}

engine = create_engine(
    settings.database_url,
    connect_args=connect_args,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(bind=engine, autoflush=False, autocommit=False)


class Base(DeclarativeBase):
    pass


# Queue every newly-created notification and publish it only after a successful
# transaction commit. This covers both helper.push_notification() and direct
# db.add(Notification(...)) call sites without emitting events on rollback.
_NOTIFICATION_OBJECTS = "_realtime_notification_objects"
_NOTIFICATION_EVENTS = "_realtime_notification_events"


def _notification_payload(notification) -> dict:
    created_at = getattr(notification, "created_at", None)
    return {
        "id": notification.id,
        "user_id": notification.user_id,
        "type": notification.type,
        "title": notification.title,
        "body": notification.body,
        "related_id": notification.related_id,
        "read": bool(notification.read),
        "created_at": created_at.isoformat() if created_at else None,
    }


@event.listens_for(Session, "before_flush")
def _queue_new_notifications(session, _flush_context, _instances):
    from app.models.messaging import Notification

    objects = session.info.setdefault(_NOTIFICATION_OBJECTS, {})
    for obj in session.new:
        if isinstance(obj, Notification):
            objects[id(obj)] = obj


@event.listens_for(Session, "after_flush_postexec")
def _capture_flushed_notifications(session, _flush_context):
    objects = session.info.get(_NOTIFICATION_OBJECTS, {})
    if not objects:
        return
    events = session.info.setdefault(_NOTIFICATION_EVENTS, [])
    for key, notification in list(objects.items()):
        if notification.id is not None:
            events.append(_notification_payload(notification))
        objects.pop(key, None)


@event.listens_for(Session, "after_commit")
def _publish_committed_notifications(session):
    events = session.info.pop(_NOTIFICATION_EVENTS, [])
    session.info.pop(_NOTIFICATION_OBJECTS, None)
    if not events:
        return
    # Lazy import avoids database ↔ model ↔ hub import cycles during startup.
    from app.chat_hub import hub

    for payload in events:
        hub.send_to_sync(payload["user_id"], "notification:new", payload)


@event.listens_for(Session, "after_rollback")
def _discard_rolled_back_notifications(session):
    session.info.pop(_NOTIFICATION_OBJECTS, None)
    session.info.pop(_NOTIFICATION_EVENTS, None)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()


