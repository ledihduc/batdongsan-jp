"""ORM models — package theo domain (tách từ models.py 1586 dòng, §C1).
`from app.models import X` GIỮ NGUYÊN nhờ re-export. Bản đồ: docs/model_tables.txt.
Mỗi domain: 1 file; sửa 1 bảng chỉ nạp file đó thay vì cả 1586 dòng."""
from app.models._shared import JSONList, now_utc, Base  # noqa: F401
from app.models.core import *          # noqa: F401,F403
from app.models.listing import *       # noqa: F401,F403
from app.models.messaging import *     # noqa: F401,F403
from app.models.host import *          # noqa: F401,F403
from app.models.rental import *        # noqa: F401,F403
from app.models.billing import *       # noqa: F401,F403
from app.models.khai_bao import *      # noqa: F401,F403
from app.models.homestay import *      # noqa: F401,F403
from app.models.audit import *         # noqa: F401,F403
from app.models.lead import *          # noqa: F401,F403
from app.models.preferences import *   # noqa: F401,F403
from app.models.moderation import *     # noqa: F401,F403
from app.models.sale import *          # noqa: F401,F403
from app.models.viewing import *       # noqa: F401,F403
from app.models.stay import *          # noqa: F401,F403
from app.models.money import *         # noqa: F401,F403
from app.models.short_inventory import *  # noqa: F401,F403
from app.models.buy_sell import *       # noqa: F401,F403
from app.models.admin import *          # noqa: F401,F403
