"""ĐỊNH DANH đăng nhập — email hoặc số điện thoại, một ô duy nhất.

## Vì sao phải có tệp riêng

Cho đăng nhập bằng SĐT nghĩa là SĐT trở thành **khoá định danh**, ngang hàng
email. Mà một số điện thoại Việt Nam viết được bằng ít nhất bốn cách:

    0912345678 · +84912345678 · 84912345678 · 0912 345 678

Nếu mỗi chỗ tự xử lý theo cách riêng thì cùng một người đăng ký được hai lần,
và lần thứ hai sẽ không đăng nhập nổi bằng cách họ vừa gõ. Chuẩn hoá phải nằm ở
ĐÚNG MỘT chỗ, và mọi đường ghi/đọc đều đi qua đây.

## Dạng chuẩn

`0` + 9 chữ số (dạng người Việt gõ và đọc cho nhau). Chọn dạng này thay vì E.164
`+84…` vì nó là thứ hiện trên giấy tờ, danh bạ và card visit — người dùng nhìn
vào phải nhận ra số của mình.

## Nguyên tắc: KHÔNG đoán bừa

Số không khớp dạng nào thì trả về chuỗi RỖNG chứ không "sửa cho gần đúng".
Đoán sai một chữ số là gán tài khoản cho người khác. Dữ liệu cũ có sẵn số lệch
chuẩn (vd `8478553330` — 10 chữ số bắt đầu bằng 84, không phải `+84` mà cũng
không phải số nội địa); những số đó giữ nguyên, chủ tài khoản vẫn đăng nhập
bằng email như trước.
"""

from __future__ import annotations

import re

#: Đầu số di động VN sau đợt chuyển đổi 2018: 03x 05x 07x 08x 09x.
#: Cố định 10 chữ số. Số cố định (02x) KHÔNG nhận — không ai đăng nhập bằng số
#: bàn, mà nhận vào là mở cửa cho số dùng chung của cả một văn phòng.
_DI_DONG = re.compile(r"^0[35789][0-9]{8}$")


def chuan_hoa_sdt(raw: str | None) -> str:
    """Đưa mọi cách viết về `0xxxxxxxxx`. Không nhận dạng được → chuỗi rỗng.

    Rỗng nghĩa là "đây không phải số điện thoại dùng để đăng nhập", KHÔNG phải
    "số sai" — người gọi tự quyết định báo lỗi hay bỏ qua.
    """
    s = (raw or "").strip()
    if not s:
        return ""

    # Giữ dấu + đầu tiên, bỏ mọi khoảng trắng/chấm/gạch trong thân số.
    co_cong = s.startswith("+")
    so = re.sub(r"\D", "", s)
    if not so:
        return ""

    if co_cong or len(so) == 11:
        # +84912345678 · 84912345678 → 0912345678
        if so.startswith("84") and len(so) == 11:
            so = "0" + so[2:]
    elif so.startswith("084") and len(so) == 12:
        # Một số bàn phím quay số chèn '0' trước mã quốc gia.
        so = "0" + so[3:]

    return so if _DI_DONG.match(so) else ""


def la_email(raw: str | None) -> bool:
    """Người dùng đang gõ email hay số?

    Chỉ cần dấu `@`: không số điện thoại nào chứa nó, nên phép phân loại này
    không bao giờ nhập nhằng. Việc email có HỢP LỆ hay không là câu hỏi khác,
    hỏi bằng `helpers.email_valid`.
    """
    return "@" in (raw or "")


def tach(raw: str | None) -> tuple[str, str]:
    """Tách ô đăng nhập thành `(email, sđt)` — đúng một vế có giá trị.

    Trả `("", "")` khi không nhận dạng được cả hai; người gọi báo lỗi chung
    "Email/SĐT hoặc mật khẩu không đúng" chứ đừng nói rõ vế nào sai — nói rõ là
    biến ô đăng nhập thành công cụ dò xem ai đã đăng ký.
    """
    s = (raw or "").strip()
    if la_email(s):
        return s.lower(), ""
    return "", chuan_hoa_sdt(s)
