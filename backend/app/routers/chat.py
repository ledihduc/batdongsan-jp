from fastapi import (
    APIRouter,
    Body,
    Depends,
    HTTPException,
    Query,
    WebSocket,
    WebSocketDisconnect,
)
from sqlalchemy import or_, and_
from sqlalchemy.orm import Session
from starlette.concurrency import run_in_threadpool

from app import auth, helpers, models
from app.chat_hub import hub
from app.database import get_db

router = APIRouter(prefix="/api/chats", tags=["chat"])


@router.get("")
def conversations(
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Conversation list của chính actor. Actor luôn lấy từ JWT — chặn user A
    đọc trộm conversation list của user B."""
    user_id = int(claims["sub"])
    msgs = (
        db.query(models.ChatMessage)
        .filter(
            or_(
                models.ChatMessage.sender_id == user_id,
                models.ChatMessage.receiver_id == user_id,
            )
        )
        .order_by(models.ChatMessage.created_at.desc())
        .all()
    )
    peer_data: dict[int, dict] = {}
    for m in msgs:
        peer = m.receiver_id if m.sender_id == user_id else m.sender_id
        if peer not in peer_data:
            peer_data[peer] = {"last": m, "unread": 0}
        if m.receiver_id == user_id and not m.read:
            peer_data[peer]["unread"] += 1

    convs = []
    for pid, pd in peer_data.items():
        u = db.get(models.User, pid)
        if not u:
            continue
        m = pd["last"]
        convs.append(
            {
                "peer_id": pid,
                "peer_name": u.name,
                "peer_avatar": u.avatar_path,
                "last_body": m.body,
                "last_at": m.created_at.isoformat(),
                "unread": pd["unread"],
                "online": hub.is_online(pid),
                "last": helpers.chat_message_to_dict(m),
            }
        )
    convs.sort(key=lambda c: c["last_at"], reverse=True)
    return {"conversations": convs}


@router.get("/{peer_id}/messages")
def history(
    peer_id: int,
    limit: int = 50,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Lịch sử chat giữa actor và peer. Actor lấy từ JWT — không cho user A
    đọc trộm conversation giữa B↔C bằng cách truyền userId=B."""
    user_id = int(claims["sub"])
    if peer_id == 0:
        raise HTTPException(400, "Thiếu peerId")
    limit = max(1, min(200, limit))
    msgs = (
        db.query(models.ChatMessage)
        .filter(
            or_(
                and_(
                    models.ChatMessage.sender_id == user_id,
                    models.ChatMessage.receiver_id == peer_id,
                ),
                and_(
                    models.ChatMessage.sender_id == peer_id,
                    models.ChatMessage.receiver_id == user_id,
                ),
            )
        )
        .order_by(models.ChatMessage.created_at.asc())
        .limit(limit)
        .all()
    )
    return {"messages": [helpers.chat_message_to_dict(m) for m in msgs]}


@router.post("/{peer_id}/messages", status_code=201)
async def send(
    peer_id: int,
    body: dict = Body(...),
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Send message. Sender LUÔN là actor từ JWT — chặn impersonation (user A
    gửi message giả danh user B)."""
    sender_id = int(claims["sub"])
    body_text = body.get("body") or ""
    if peer_id == 0 or not body_text:
        raise HTTPException(400, "Thiếu thông tin")
    if peer_id == sender_id:
        raise HTTPException(400, "Không thể tự nhắn tin cho mình")

    # Hàm này PHẢI là `async def` vì cuối cùng còn `await hub.send_to`. Nhưng
    # `db` là Session ĐỒNG BỘ: gọi thẳng ở đây thì mỗi truy vấn khoá event loop
    # và chặn mọi request khác của worker. Đẩy toàn bộ phần chạm DB sang
    # threadpool — đúng chỗ FastAPI vẫn tự đưa các route `def` thường vào.
    def _ghi_tin() -> dict:
        blocked = (
            db.query(models.UserBlock)
            .filter(
                or_(
                    and_(models.UserBlock.blocker_id == sender_id, models.UserBlock.blocked_id == peer_id),
                    and_(models.UserBlock.blocker_id == peer_id, models.UserBlock.blocked_id == sender_id),
                )
            )
            .first()
        )
        if blocked:
            raise HTTPException(403, "Không thể nhắn tin vì một trong hai người đã chặn người còn lại")
        if not db.get(models.User, peer_id):
            raise HTTPException(404, "Không tìm thấy người nhận")
        msg = models.ChatMessage(
            sender_id=sender_id,
            receiver_id=peer_id,
            house_id=body.get("house_id"),
            body=body_text,
            read=False,
        )
        db.add(msg)
        db.commit()
        db.refresh(msg)
        return helpers.chat_message_to_dict(msg)

    payload = await run_in_threadpool(_ghi_tin)
    await hub.send_to(peer_id, "chat:new", payload)
    await hub.send_to(sender_id, "chat:new", payload)
    return {"message": payload}


@router.patch("/{peer_id}/read")
async def mark_read(
    peer_id: int,
    db: Session = Depends(get_db),
    claims: dict = Depends(auth.require_user),
):
    """Mark message FROM peer → actor là read. Actor luôn lấy từ JWT."""
    user_id = int(claims["sub"])
    if peer_id == 0:
        raise HTTPException(400, "Thiếu peerId")

    # Xem lý do dùng threadpool ở [send].
    def _danh_dau() -> None:
        db.query(models.ChatMessage).filter(
            models.ChatMessage.sender_id == peer_id,
            models.ChatMessage.receiver_id == user_id,
            models.ChatMessage.read == False,
        ).update({"read": True})
        db.commit()

    await run_in_threadpool(_danh_dau)
    await hub.send_to(peer_id, "chat:read", {"by_user_id": user_id})
    return {"success": True}


# ───────── WebSocket ─────────

ws_router = APIRouter(tags=["ws"])


@ws_router.post("/api/ws-ticket")
def issue_ws_ticket(claims: dict = Depends(auth.require_user)):
    """Đổi JWT đăng nhập (gửi an toàn trong header Authorization) lấy một vé
    ngắn hạn để mở WebSocket.

    Cần bước này vì WebSocket trên trình duyệt KHÔNG đặt được header tuỳ ý —
    thông tin xác thực buộc phải nằm trong URL, mà URL thì bị ghi vào log.
    Vé sống 30 giây và chỉ dùng được một lần nên có lọt log cũng vô giá trị.
    """
    return {
        "ticket": auth.sign_ws_ticket(int(claims["sub"]), claims.get("role", "")),
        "expires_in": auth.WS_TICKET_TTL_SECONDS,
    }


@ws_router.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket, ticket: str = Query("")):
    """Mở kênh realtime bằng VÉ dùng-một-lần (xin ở POST /api/ws-ticket).

    KHÔNG nhận JWT đăng nhập ở đây: query string bị nginx ghi vào access log,
    nên token dài hạn đặt vào đây là để lộ tài khoản cho bất kỳ ai đọc log.
    """
    claims = auth.redeem_ws_ticket(ticket)
    await websocket.accept()
    if not claims:
        await websocket.send_json(
            {"type": "error", "message": "Vé không hợp lệ hoặc đã hết hạn"}
        )
        await websocket.close()
        return

    user_id = int(claims["sub"])
    await hub.add(user_id, websocket)
    await websocket.send_json({"type": "hello", "user_id": user_id})

    try:
        while True:
            # Client gửi gì cũng ignore (chỉ giữ kết nối)
            await websocket.receive_text()
    except WebSocketDisconnect:
        pass
    finally:
        await hub.remove(user_id, websocket)
