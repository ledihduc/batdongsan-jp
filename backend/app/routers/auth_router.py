import secrets
from datetime import datetime, timezone

from fastapi import APIRouter, Body, Depends, HTTPException, Request
from sqlalchemy import and_, or_
from sqlalchemy.orm import Session

from app import auth, helpers, models
from app.database import get_db
from app.middleware.rate_limit import limiter
from app.services import dinh_danh
from app.schemas.login import LoginRequest
from app.services.login_account import login_user_dict, require_login_account_type

router = APIRouter(prefix="/api/auth", tags=["auth"])

_QUA_DAI = (
    "Mật khẩu quá dài (tối đa 72 byte — khoảng 72 ký tự thường "
    "hoặc ~24 ký tự tiếng Việt có dấu)."
)

# Giới hạn tần suất: chống dò mật khẩu. Trước đây KHÔNG có giới hạn nào ở tầng
# ứng dụng — nginx chỉ chặn ở mức 100 req/s, tức vẫn cho thử hàng nghìn mật
# khẩu mỗi phút. Khoá theo user_id nếu có JWT, không thì theo IP.
@router.post("/login")
@limiter.limit("10/minute")
def login(request: Request, body: LoginRequest, db: Session = Depends(get_db)):
    """Một ô cho CẢ email lẫn số điện thoại.

    Người Việt nhớ số của mình chắc hơn nhớ email, và nhiều người bán chỉ dùng
    Zalo. Bắt chọn "đăng nhập bằng gì" trước khi gõ là bắt người dùng trả lời
    một câu hỏi của hệ thống, không phải của họ.

    Khoá cũ `email` vẫn nhận để app bản cũ không gãy giữa lúc deploy.
    """
    raw = (body.dinh_danh or body.email or "").strip()
    password = body.password
    email, sdt = dinh_danh.tach(raw)

    # Không nhận dạng được thì vẫn phải TRẢ LỖI GIỐNG HỆT sai mật khẩu. Báo
    # riêng "số không hợp lệ" là biến ô đăng nhập thành công cụ dò tài khoản.
    u = None
    if email or sdt:
        u = (
            db.query(models.User)
            .filter(
                models.User.is_active == True,  # noqa: E712
                # `<> ''` là bắt buộc: KHÔNG có vế này thì gõ chuỗi rỗng sẽ
                # khớp mọi tài khoản chưa có email/số, và người đầu tiên trong
                # nhóm đó bị đăng nhập nhờ.
                or_(
                    and_(models.User.email == email, models.User.email != ""),
                    and_(models.User.phone == sdt, models.User.phone != ""),
                ),
            )
            .first()
        )
    if not u or not auth.verify_password(password, u.password_hash):
        raise HTTPException(401, "Email/SĐT hoặc mật khẩu không đúng")
    # Check only AFTER credentials, and BEFORE signing any session token.
    user_data = login_user_dict(db, u)
    require_login_account_type(body.login_account_type, user_data["login_account_types"])
    token = auth.sign_token(u.id, u.role, u.password_changed_at)
    return {"token": token, "user": user_data}


@router.post("/register", status_code=201)
@limiter.limit("5/minute")
def register(request: Request, body: dict = Body(...), db: Session = Depends(get_db)):
    name = (body.get("name") or "").strip()
    password = body.get("password") or ""
    # SECURITY: role whitelist — only 'guest' allowed at registration.
    # Callers that pass role='host' or role='admin' are silently normalised to 'guest'.
    # All active accounts can use customer/sale/owner workspaces. Business
    # context selection never changes the system role or legacy profile label.
    role = "guest"

    # Đăng ký bằng email HOẶC số điện thoại — cần ít nhất một, không cần cả hai.
    #
    # Ô `dinh_danh` là đường mới (app gõ gì cũng được); `email`/`phone` là hai ô
    # rời của app bản cũ. Nhận cả hai đường để deploy không làm gãy bản đang
    # chạy trên máy người dùng.
    email, sdt = dinh_danh.tach(body.get("dinh_danh"))
    if not email:
        email = (body.get("email") or "").strip().lower()
    if not sdt:
        sdt = dinh_danh.chuan_hoa_sdt(body.get("phone"))

    if not name or not password:
        raise HTTPException(400, "Thiếu thông tin bắt buộc")
    if not email and not sdt:
        raise HTTPException(400, "Cần email hoặc số điện thoại")
    if email and not helpers.email_valid(email):
        raise HTTPException(400, "Email không hợp lệ")
    # Số gõ vào mà không ra dạng chuẩn thì phải BÁO, đừng lặng lẽ bỏ đi: người
    # dùng sẽ tưởng mình đã đăng ký bằng số đó và lần sau không đăng nhập được.
    if not sdt and (body.get("phone") or "").strip():
        raise HTTPException(400, "Số điện thoại không hợp lệ (VD: 0912345678)")
    if len(password) < 6:
        raise HTTPException(400, "Mật khẩu tối thiểu 6 ký tự")
    if auth.password_too_long(password):
        raise HTTPException(400, _QUA_DAI)
    if email and db.query(models.User).filter(models.User.email == email).first():
        raise HTTPException(409, "Email đã được sử dụng")
    if sdt and db.query(models.User).filter(models.User.phone == sdt).first():
        raise HTTPException(409, "Số điện thoại đã được sử dụng")

    u = models.User(
        name=name,
        email=email,
        password_hash=auth.hash_password(password),
        phone=sdt,
        role=role,
        account_type="customer",
        is_active=True,
    )
    db.add(u)
    db.commit()
    db.refresh(u)
    token = auth.sign_token(u.id, u.role, u.password_changed_at)
    return {"token": token, "user": login_user_dict(db, u)}


@router.get("/me")
def me(claims: dict = Depends(auth.require_user), db: Session = Depends(get_db)):
    u = db.get(models.User, claims["sub"])
    if not u or not u.is_active:
        raise HTTPException(401, "Tài khoản không tồn tại")
    return {"user": login_user_dict(db, u)}


@router.post("/change-password")
def change_password(
    body: dict = Body(...),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    # SECURITY: use claims.sub from verified JWT — ignore body.user_id to prevent IDOR.
    # Any authenticated user can only change their own password.
    uid = claims["sub"]
    old = body.get("old_password") or ""
    new = body.get("new_password") or ""
    if not new:
        raise HTTPException(400, "Thiếu thông tin")
    u = db.get(models.User, uid)
    if not u:
        raise HTTPException(404, "Không tìm thấy")
    if not auth.verify_password(old, u.password_hash):
        raise HTTPException(401, "Mật khẩu hiện tại không đúng")
    if len(new) < 6:
        raise HTTPException(400, "Mật khẩu mới tối thiểu 6 ký tự")
    if auth.password_too_long(new):
        raise HTTPException(400, _QUA_DAI)
    u.password_hash = auth.hash_password(new)
    # Đóng MỌI phiên cũ: token phát trước mốc này sẽ bị từ chối. Đây là điểm
    # mấu chốt — trước đây đổi mật khẩu vì nghi bị lộ KHÔNG hề đuổi được kẻ
    # đang giữ token cũ, họ dùng tiếp tới hết hạn (7 ngày).
    u.password_changed_at = datetime.now(timezone.utc)
    db.commit()
    # Cấp token mới để CHÍNH người vừa đổi không bị đăng xuất theo.
    return {"success": True, "token": auth.sign_token(u.id, u.role, u.password_changed_at)}


@router.post("/delete-account")
def delete_account(
    body: dict = Body(default={}),
    claims: dict = Depends(auth.require_user),
    db: Session = Depends(get_db),
):
    """Người dùng TỰ xoá tài khoản (bắt buộc: Apple 5.1.1(v) + Google Play).

    Ẩn danh hoá toàn bộ PII + vô hiệu hoá tài khoản + đuổi mọi phiên. CỐ Ý không
    hard-delete để giữ toàn vẹn khoá ngoại (tin đăng/booking/hoá đơn lịch sử) —
    dữ liệu CÁ NHÂN bị xoá, bản ghi nghiệp vụ trở thành ẩn danh. Yêu cầu xác
    nhận mật khẩu để tránh xoá nhầm khi token bị lộ / mất máy.
    """
    uid = claims["sub"]
    u = db.get(models.User, uid)
    if not u or not u.is_active:
        raise HTTPException(404, "Không tìm thấy tài khoản")

    password = body.get("password") or ""
    if not auth.verify_password(password, u.password_hash):
        raise HTTPException(401, "Mật khẩu không đúng")

    # Dọn dữ liệu tài khoản và nội dung do người dùng tạo trước khi ẩn danh hoá.
    # Dữ liệu nghiệp vụ bắt buộc giữ lại sẽ không còn liên kết PII sau bước dưới.
    from app.services.cccd_storage import delete_cccd
    host_profiles = db.query(models.HostProfile).filter(models.HostProfile.user_id == uid).all()
    for profile in host_profiles:
        for file_path in (profile.cccd_front_path, profile.cccd_back_path):
            if file_path:
                try:
                    delete_cccd(file_path, uid, db)
                except (FileNotFoundError, PermissionError):
                    pass
        db.delete(profile)

    for model, column in (
        (models.Notification, models.Notification.user_id),
        (models.UserPushToken, models.UserPushToken.user_id),
        (models.UserPreferences, models.UserPreferences.user_id),
        (models.UserBlock, models.UserBlock.blocker_id),
        (models.UserBlock, models.UserBlock.blocked_id),
        (models.SaleProfile, models.SaleProfile.user_id),
        (models.CCCDAccessLog, models.CCCDAccessLog.user_id),
        (models.Wishlist, models.Wishlist.user_id),
        (models.SavedPost, models.SavedPost.user_id),
        (models.Review, models.Review.user_id),
        (models.ContentReport, models.ContentReport.reporter_id),
    ):
        db.query(model).filter(column == uid).delete(synchronize_session=False)
    db.query(models.ChatMessage).filter(
        or_(models.ChatMessage.sender_id == uid, models.ChatMessage.receiver_id == uid)
    ).delete(synchronize_session=False)
    db.query(models.House).filter(models.House.host_id == uid).update(
        {
            models.House.title: "Tin đăng đã bị xoá",
            models.House.description: "",
            models.House.images: [],
            models.House.status: "deleted",
        },
        synchronize_session=False,
    )
    # Ẩn danh hoá PII — không thể đăng nhập lại, không còn thông tin cá nhân.
    u.name = "Người dùng đã xoá"
    u.email = f"deleted_{u.id}@deleted.ancu365.local"
    u.phone = ""
    u.avatar_path = ""
    u.bio = None
    u.id_number = None
    u.birthday = None
    u.password_hash = auth.hash_password(secrets.token_urlsafe(32))
    u.is_active = False
    # Đuổi mọi phiên đang mở: token cũ bị require_user từ chối ngay.
    u.password_changed_at = datetime.now(timezone.utc)
    db.commit()
    return {"success": True}


@router.post("/forgot-password")
@limiter.limit("5/minute")
def forgot_password(request: Request, body: dict = Body(...)):
    """ĐÃ TẮT — endpoint này từng cho phép CHIẾM BẤT KỲ TÀI KHOẢN NÀO.

    Bản cũ nhận email, ĐỔI LUÔN mật khẩu của chủ tài khoản thành chuỗi ngẫu
    nhiên, rồi TRẢ CHÍNH MẬT KHẨU ĐÓ về trong response — không đăng nhập,
    không xác minh quyền sở hữu email, không giới hạn tần suất. Nghĩa là bất kỳ
    ai biết một địa chỉ email (kể cả admin@…) đều chiếm được tài khoản đó, còn
    chủ thật thì bị đá ra ngay lập tức.

    Nó cũng trả 404 khi email không tồn tại, cho phép dò xem email nào đã đăng
    ký — trong khi /login đã cẩn thận tránh đúng điều này.

    Tắt thay vì sửa dần: chừng nào chưa có kênh gửi email/SMS thật thì KHÔNG có
    cách nào trao mật khẩu tạm cho đúng người. Khôi phục mật khẩu hiện làm thủ
    công qua quản trị viên. Khi dựng xong luồng gửi email, thay thân hàm này
    bằng: sinh token ngẫu nhiên có hạn + dùng-một-lần, gửi qua email, KHÔNG đổi
    mật khẩu cho tới khi người dùng bấm link.

    KHI DỰNG LẠI — luật đã chốt: **chỉ gửi qua EMAIL, không gửi SMS.** Từ mig
    0097 đăng ký được bằng số điện thoại thôi, nên sẽ có tài khoản KHÔNG có
    email; những tài khoản đó không tự lấy lại mật khẩu được và phải nhờ quản
    trị viên. Đó là lý do màn đăng ký phải nói trước điều này ngay lúc người
    dùng bỏ trống ô email — biết trước thì họ chọn được, biết sau là mất tài
    khoản.
    """
    return {
        "success": False,
        "message": (
            "Yêu cầu đã được ghi nhận. Vui lòng liên hệ bộ phận hỗ trợ qua "
            "trang Điều khoản để xác minh quyền sở hữu tài khoản."
        ),
    }
