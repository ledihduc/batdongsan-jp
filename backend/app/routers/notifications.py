from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session

from app import auth, helpers, models
from app.database import get_db

router = APIRouter(prefix="/api/notifications", tags=["notifications"])


@router.get("")
def list_notifications(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Notifications là per-user. Actor luôn lấy mình từ JWT — không nhận
    userId qua query (chặn IDOR)."""
    user_id = int(claims["sub"])
    items = (
        db.query(models.Notification)
        .filter(models.Notification.user_id == user_id)
        .order_by(models.Notification.created_at.desc())
        .all()
    )
    unread = (
        db.query(models.Notification)
        .filter(models.Notification.user_id == user_id, models.Notification.read == False)
        .count()
    )
    return {
        "notifications": [helpers.notification_to_dict(n) for n in items],
        "unread": unread,
    }


@router.patch("/{notif_id}/read")
def mark_read(
    notif_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    n = db.get(models.Notification, notif_id)
    if not n:
        raise HTTPException(404, "Không tìm thấy")
    # Chặn user A đánh dấu read noti của user B (no enumeration / no
    # silencing-by-attacker).
    auth._ensure_owner_or_admin(claims, n.user_id)
    n.read = True
    db.commit()
    return {"success": True}


@router.patch("/read-all")
def mark_all_read(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    user_id = int(claims["sub"])
    db.query(models.Notification).filter(
        models.Notification.user_id == user_id, models.Notification.read == False
    ).update({"read": True})
    db.commit()
    return {"success": True}
