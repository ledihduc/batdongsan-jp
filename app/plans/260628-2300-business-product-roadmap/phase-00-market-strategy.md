# Phase 00 — Market Strategy (ancu365 / UrbanNest)

> Analyst note: Mọi con số đều là estimate có nguồn/giả định công khai. Đánh dấu `[A]` = assumption cần verify trước khi commit ngân sách. Không thay thế due diligence.

---

## 1. Executive Summary

- ancu365 đứng ở giao điểm hiếm: **marketplace + SaaS ops + compliance VN** (KB04, planning lookup). Không đối thủ nào hiện cover trọn bộ.
- Mảng SaaS quản lý nhà trọ là **wedge**: monetize được ngay, churn thấp, data-lock-in. Marketplace là **flywheel**: bơm guest cho host trả tiền SaaS.
- Đã build ~70% MVP kỹ thuật. **Gap còn lại lớn nhất là PHI-tech**: payment gateway, KYC nâng cao, SEO web, hợp đồng pháp lý, hỗ trợ KH, dispute, giấy phép tài chính.
- Team 1-2 dev + AI **không đủ** chạy song song marketplace dài hạn + ngắn ngày + SaaS. Phải chọn beachhead.
- **Verdict: CONDITIONAL GO** — Readiness Score 64/100. Đi tiếp với điều kiện thu hẹp scope launch và xử lý 4 critical gaps trong 60 ngày.

---

## 2. Market Sizing (TAM/SAM/SOM)

### Giả định gốc `[A]`
- VN ~100tr dân, ~30% sống thuê (urban tenant penetration).
- HCMC ~9tr dân, HN ~8.5tr, ĐN ~1.3tr.
- Giá thuê trung bình phòng trọ: 2.5-4tr/tháng (HCM/HN tier 2 area), homestay night rate trung bình 600k-1.2tr.
- SaaS willingness-to-pay host VN: 50k-200k/phòng/tháng (Cohousing đang charge khoảng này).

### TAM — Vietnam rental + short-stay
- **Long-term rent**: ~9tr unit thuê × 3tr/tháng × 12 = **~324.000 tỷ VND/năm (~13 tỷ USD)**.
- **Short-term stay (homestay/airbnb-style)**: ~80.000 unit active × 50% occupancy × 800k × 365 = **~11.700 tỷ VND/năm (~470M USD)** `[A]`.
- **TAM cộng dồn**: ~13.5 tỷ USD GMV/năm.
- TAM SaaS host (ops fee): 800k unit có-tổ-chức × 100k × 12 = **~960 tỷ VND/năm (~38M USD)**.

### SAM — HCM + HN + ĐN
- 60% GMV cả nước tập trung 3 đô thị → SAM GMV ~8 tỷ USD/năm.
- SAM SaaS: ~250k phòng/căn có chủ vận-hành-thật → ~300 tỷ VND/năm (~12M USD).

### SOM năm 1 (realistic, không lạc quan)
| Metric | Mục tiêu | Lý do |
|---|---|---|
| Host paying SaaS | **300 host / 6.000 phòng** | 0.1% beachhead penetration; CAC kham được với team nhỏ |
| Guest đăng ký | **15.000 user** | 1 host tốt = 50-100 lead/tháng × cross |
| Viewing appointments | **2.500/tháng vào tháng 12** | conversion 0.8% guest active |
| GMV ngắn ngày (homestay) | **30-50 tỷ VND** | 100 host homestay × 10 unit × 35% occ × 800k × 365 |
| Doanh thu ancu365 năm 1 | **6-9 tỷ VND** | Mix SaaS + commission (xem §3) |

> Bench: Cohousing public claim ~5k phòng managed sau 2 năm. Chúng ta đặt 6k phòng năm 1 là tham vọng nhưng khả thi nhờ AI marketing đẩy nhanh acquisition.

---

## 3. Persona & Jobs-to-be-done

### Hosts

**H1 — "Cô Hạnh" — Chủ nhà trọ truyền thống 10-30 phòng**
- 45-60 tuổi, sở hữu 1-3 căn nhà chia phòng ở quận ven (Bình Thạnh, Q.7, Gò Vấp, Tân Phú).
- **Pain**: chép sổ tay, thu tiền mặt/chuyển khoản lẫn lộn, quên đọc công tơ, không nhớ ai nợ, sợ công an phạt vì KB04 quá deadline.
- **Substitute hiện tại**: Excel + Zalo group + sổ giấy. Một số dùng Mogi để đăng tin lẻ khi trống phòng.
- **Why switch**: KB04 auto + invoice tự động + nhắc nợ là painkiller. Nhưng phải miễn phí hoặc < 50k/phòng/tháng.
- **JTBD**: "Giúp tôi quản lý nhà trọ đỡ mệt mà không phải học công nghệ phức tạp."

**H2 — "Anh Khoa" — Chủ chuỗi 30-100+ phòng / có quản lý**
- 30-45 tuổi, đầu tư BĐS, có 3-10 nhà, thuê 1-2 quản lý vận hành.
- **Pain**: nhân viên thất thoát tiền, không có báo cáo doanh thu/occupancy realtime, khó scale.
- **Substitute**: Cohousing, Stayhub.vn, Apec Ezstay, hoặc tự build Google Sheet phức tạp.
- **Why switch**: dashboard tài chính realtime + multi-property + audit log. Sẵn sàng trả 100-200k/phòng/tháng nếu thay được nhân sự.
- **JTBD**: "Cho tôi nhìn thấy tiền và occupancy mọi lúc mọi nơi, ngăn nhân viên ăn chặn."

**H3 — "Chị Linh" — Chủ homestay đầu tư 2-10 căn**
- 28-40 tuổi, đầu tư homestay/căn hộ dịch vụ cho thuê Airbnb/Booking.
- **Pain**: dual-listing 3-5 kênh dễ overbook, fee Airbnb 15%+, không có công cụ pricing động, khai báo lưu trú thủ công.
- **Substitute**: Airbnb + Booking + Hostex/Smoobu (channel manager nước ngoài, 20-50 USD/listing/tháng).
- **Why switch**: tích hợp KB04 auto, hợp đồng tiếng Việt, giá VND, support tiếng Việt.
- **JTBD**: "Cho tôi 1 lịch duy nhất, đừng để overbook, đừng để bị phạt vì không khai lưu trú."

### Guests

**G1 — "Em Trang" — Sinh viên / vừa đi làm**
- 18-25 tuổi, ngân sách 2-4tr/tháng, tìm phòng trọ gần trường/công ty.
- **Pain**: tin Phongtro123/Mogi 60% là cò, hình giả, đặt cọc bị mất.
- **Substitute**: Facebook group, Phongtro123, lời mách bạn bè.
- **Why switch**: listing đã verify CCCD host, lịch xem rõ ràng, chat trực tiếp, review tin được.
- **JTBD**: "Tìm phòng thật, gặp chủ thật, không bị lừa cọc."

**G2 — "Anh Hùng" — Công nhân / lao động phổ thông**
- 22-35 tuổi, làm KCN, ngân sách 1.5-2.5tr, ưu tiên gần chỗ làm + an toàn.
- **Pain**: không quen app, dùng chủ yếu Zalo, không có CMND/CCCD số.
- **Substitute**: hỏi đồng nghiệp, dán giấy tay.
- **Why switch**: nếu có Zalo Mini App + filter "gần KCN X" + giá rõ. Khó kéo lên Flutter app riêng.
- **JTBD**: "Tìm chỗ ngủ gần xưởng, giá biết trước, không phải đi xem cả ngày."

**G3 — "Chị Mai" — Khách du lịch / công tác ngắn ngày**
- 28-45 tuổi, đi 2-5 đêm, ngân sách 600k-1.5tr/đêm, ưu tiên review + vị trí.
- **Pain**: Airbnb tăng giá fee, Booking không có homestay nhỏ tiếng Việt.
- **Substitute**: Booking, Agoda, Traveloka, Airbnb, Luxstay (đã đóng).
- **Why switch**: KHÓ — đối thủ quá mạnh. Chỉ thắng nếu inventory unique (homestay địa phương) + giá rẻ 10-15%.
- **JTBD**: "Đặt nhanh, không bị từ chối phút chót, có hoá đơn rõ ràng."

---

## 4. Mô hình doanh thu — chọn 2 mô hình ưu tiên

### Ưu tiên 1 — **SaaS subscription per phòng cho host**
- **Pricing đề xuất**:
  - Free: 1-5 phòng (acquisition tier)
  - Pro: **49k/phòng/tháng**, tối thiểu 200k/tháng (5-100 phòng)
  - Business: **99k/phòng/tháng** + multi-user + audit log (>50 phòng)
  - Homestay add-on: **+30k/phòng/tháng** cho channel-sync + pricing rules
- **Benchmark VN**: Cohousing 30-80k, Stayhub 50-150k, Ezstay 100-300k, Hostex ~25 USD/listing.
- **ARPU dự kiến năm 1**: ~60k/phòng/tháng × 6.000 phòng = **360tr/tháng → ~4.3 tỷ/năm**.
- **Lý do chọn**: doanh thu predictable, churn thấp khi data lock-in (lịch sử hợp đồng, công tơ), không cần giấy phép tài chính, biên lợi nhuận cao.

### Ưu tiên 2 — **Commission per booking (homestay ngắn ngày) + lead-fee (thuê dài hạn)**
- **Pricing đề xuất**:
  - Homestay short-stay: **commission 8-10%** (rẻ hơn Airbnb 15%+, Booking 15-18%)
  - Long-term rent lead-fee: **giới thiệu thành công = 30-50% giá phòng tháng đầu**, trả 1 lần khi hợp đồng ký
  - Featured listing host trả top-up: 50-200k/tin/tuần
- **Benchmark**: Airbnb 14-16% total, Booking 15-18%, Mogi VIP listing 100-500k/tin.
- **GMV năm 1**: 40 tỷ × 9% = **3.6 tỷ commission** + lead-fee ~500tr.
- **Lý do chọn**: bù SaaS khi host miễn phí; tạo flywheel guest → host. Nhưng **đòi hỏi payment gateway và escrow** → có rào pháp lý (xem §6).

### Loại bỏ ưu tiên thấp
- **Pure ad-revenue**: không scale ở VN, dễ bị Phongtro123 đánh bại về volume.
- **Insurance/bảo hiểm**: để Phase 2 sau khi có 5k+ host (cross-sell, không phải core).
- **Verify CCCD per use**: included trong SaaS Pro, không tách giá.

> Đề xuất mix năm 1: **70% SaaS + 25% commission + 5% featured**. Tổng ~6-9 tỷ VND.

---

## 5. Competitive Positioning

### Matrix 2 trục

```
                    SaaS-heavy / Ops-focused
                              |
                              |
                    Stayhub   |   ★ ancu365
                    Cohousing |   (target)
                    Ezstay    |
                              |
Long-term  ───────────────────┼─────────────────── Short-stay
                              |
                              |
                    Mogi      |   Airbnb
                    Phongtro123   Booking
                    Batdongsan|   Agoda
                              |
                    Marketplace / Listing-focused
```

### Vị trí ancu365
- Góc phần tư **Top-Right hiện đang trống** ở VN: SaaS-heavy + multi-segment (cả dài hạn + ngắn hạn).
- Đối thủ gần nhất là Cohousing (SaaS dài hạn) và Stayhub. Họ **không** có marketplace guest-facing. Phongtro123 thì ngược lại.

### Unfair Advantages (đối thủ khó copy trong 12 tháng)
1. **Planning lookup tích hợp (HCMC 24 quận PostGIS + Martin)** — giúp host kiểm tra quy hoạch trước khi đầu tư, guest yên tâm đất không bị giải tỏa. Đối thủ phải build pipeline scraping + xử lý dữ liệu công khai → 6-12 tháng.
2. **KB04 auto + Zalo deep-link tự khai** — đã wire xong, có public token. Đối thủ phải hiểu sâu quy trình công an + integrate Zalo OA → 3-6 tháng.
3. **Anti-overbooking PostGIS EXCLUDE constraint** — chuẩn kỹ thuật, không copy nhanh bằng app no-code.
4. **Team AI video marketing in-house** — content cost gần 0, CAC thấp hơn đối thủ 5-10×.
5. **Compliance-first positioning** — chuyên gia ngành + KB04/planning/hoá đơn điện tử built-in. Đối thủ marketplace không quan tâm pháp lý, đối thủ SaaS không quan tâm guest. ancu365 ăn cả 2.

### Defensible moat
- Data: lịch sử hợp đồng + công tơ + thanh toán → churn rất khó (host phải migrate Excel).
- Network: guest review × verified host → trust flywheel.
- Regulatory: compliance modules → lock-in với host serious.

---

## 6. Go-to-Market Strategy

### Beachhead segment (chọn 1)
- **Chủ nhà trọ truyền thống 10-30 phòng tại Q.Bình Thạnh, Q.Gò Vấp, Q.7, Q.Tân Phú (HCMC).**
- Lý do:
  - Mật độ cao, ~15-25k tòa nhà trọ thuộc nhóm này → TAM micro ~150k phòng.
  - Pain KB04 cực gắt (công an khu vực kiểm tra thường xuyên).
  - WTP đã được Cohousing validate.
  - AI video marketing có thể target hyperlocal (TikTok geo + group Zalo phường).

### Mở rộng (after beachhead)
- **Tháng 4-6**: HN (Cầu Giấy, Thanh Xuân, Hai Bà Trưng).
- **Tháng 7-9**: Homestay HCMC + ĐN (mở segment ngắn ngày).
- **Tháng 10-12**: H2 segment (chủ chuỗi 100+ phòng) — bán Business tier.

### Acquisition channels — Host

| Channel | CAC ước lượng | Volume tiềm năng/tháng | Ưu tiên |
|---|---|---|---|
| AI short-video TikTok/Reels (in-house) | **50-150k/host** | 50-150 host | **#1** |
| Facebook group "Chủ nhà trọ HCM" (organic + paid) | 100-300k | 30-80 | #2 |
| Direct sales gõ cửa (chuyên gia ngành dẫn) | 500k-1tr | 20-40 | #3 (high-WTP) |
| Zalo OA + broadcast | 30-80k | 100+ | #4 (nurture) |
| Referral host hiện hữu (1 month free) | 50k | 30-50 | #5 (sau M3) |
| Google Ads keyword "phần mềm quản lý nhà trọ" | 300-800k | 20-50 | thấp ROI |

**Mục tiêu CAC blended host: 150-250k. LTV (3 năm × 1.2tr ARPU) = ~3.6tr. LTV/CAC = 15-24×** → healthy.

### Acquisition channels — Guest

| Channel | CAC | Volume/tháng | Ưu tiên |
|---|---|---|---|
| SEO landing pages (cần build, xem §7) | **2-10k** | 5-15k visits → 500-1500 signup | **#1 sau khi có web** |
| AI short-video review nhà trọ thực tế | 10-30k | 1-3k | **#2** |
| Zalo Mini App (G2 công nhân) | 5-20k | 1-2k | #3 (Phase 2) |
| Facebook Ads geo + interest | 20-60k | 2-5k | #4 |
| Listing borrow từ host (host share link guest) | ~0 | proportional to host base | viral coefficient |

**Mục tiêu CAC blended guest: 15-30k** (rẻ vì content-led).

### Vai trò team AI video marketing
- **Top funnel**: 5-10 video/ngày, format: "Tôi mất X giờ/tháng quản lý nhà trọ → giờ chỉ 10 phút" (host pain), "5 nhà trọ Bình Thạnh giá 2.5tr có thật" (guest discovery).
- **Mid funnel**: tutorial dùng app, story case "Cô Hạnh tăng occupancy 15%".
- **Bottom funnel**: short demo KB04 auto + planning lookup.
- **Phân phối**: TikTok geo HCMC + Reels + YouTube Shorts + Zalo broadcast.
- **KPI**: 100k views/tuần → 1k landing visits → 100 signup → 20 host paid/tháng (target M3+).

---

## 7. Gap Analysis — Cần build/đối tác trước launch

### CRITICAL (phải có trước public launch)
| Gap | Tác động | Effort | Owner đề xuất |
|---|---|---|---|
| **Payment gateway integration (VNPay + Momo + ZaloPay)** | Không thu được commission, không escrow homestay | 3-4 tuần | Dev + đối tác |
| **Giấy phép trung gian thanh toán hoặc escrow ngân hàng** | Pháp lý — không thể giữ tiền guest | 2-6 tháng làm việc với NHNN hoặc đối tác với MB/Techcombank escrow | Chuyên gia ngành |
| **SEO public web (Next.js/Astro static)** | Flutter Web SPA không SEO → mất 80% acquisition organic | 4-6 tuần | Dev (rewrite landing + listing detail) |
| **KYC nâng cao (liveness + OCR CCCD verify NIC)** | Fake listing, fraud → mất trust | 2-3 tuần (đối tác VNPT eKYC / FPT.AI) | Dev + đối tác |
| **Hợp đồng mẫu được luật sư VN review** | Risk dispute, nullify | 2 tuần | Chuyên gia ngành + luật sư |
| **Admin moderation dashboard** | Không xử lý được report/listing xấu | 2-3 tuần | Dev |

### HIGH (60-90 ngày sau launch)
| Gap | Effort |
|---|---|
| Dispute resolution flow (escrow hold + arbitration) | 3-4 tuần |
| Email marketing infra (Mailchimp/Brevo + lifecycle) | 1 tuần |
| Analytics (Posthog/Mixpanel + DWH BigQuery) | 2 tuần |
| Customer support tooling (Crisp/Intercom + Zalo OA) | 1-2 tuần |
| Marketing site landing page A/B | 1-2 tuần |
| Hoá đơn điện tử e-invoice tích hợp (Misa/Viettel) | 3-4 tuần |
| Public API + webhook cho host integrate | 2-3 tuần |

### MEDIUM (Phase 2, sau M6)
- Bảo hiểm tài sản host (đối tác Bảo Việt/PVI)
- Mobile native push notification chính chủ
- Multi-language (EN) cho guest du lịch
- Zalo Mini App cho G2 segment
- Channel manager 2-way sync Airbnb/Booking
- Loyalty/referral program

### Hiện đã có và OK
- Flutter mobile + web SPA cho host ops
- Chat WS, notifications, upload ảnh
- Building/Room/Contract/Invoice/Meter/Debt aging
- KB04 auto + Zalo deep-link public token
- Reservation anti-overbooking PostGIS
- Planning lookup HCMC

---

## 8. Risk & Mitigation (Top 5 Critical)

| # | Risk | Severity | Likelihood | Mitigation |
|---|---|---|---|---|
| 1 | **Pháp lý — không có giấy phép trung gian thanh toán** | CRITICAL | High (12 tháng) | (a) Tháng 1-3 không nhận tiền guest; commission lấy từ host post-paid invoice. (b) Đàm phán escrow đối tác MB/Techcombank/VPBank. (c) Hồ sơ NHNN song song (6-12 tháng). |
| 2 | **Đối thủ lớn (Mogi, Phongtro123) hạ giá listing / launch SaaS** | HIGH | Medium | (a) Build compliance moat (KB04 + planning + e-invoice) mà họ không có khẩu vị. (b) Lock-in data SaaS sớm. (c) Định vị "made by chuyên gia ngành VN" — không phải bản sao Airbnb. |
| 3 | **Host dual-listing → marketplace ancu365 thiếu inventory độc quyền** | HIGH | High | (a) Không yêu cầu exclusivity; chấp nhận multi-listing. (b) Đổi lại: SaaS ops + KB04 auto + báo cáo là painkiller giữ host. (c) Cho host export sang Airbnb/Booking để họ thấy giá trị. |
| 4 | **Fraud listing / lừa cọc → sụp đổ trust** | CRITICAL | Medium | (a) KYC liveness bắt buộc trước đăng tin. (b) Verified badge + community report. (c) Escrow cọc qua đối tác bank. (d) Moderation queue + AI image dedup detect listing trùng. |
| 5 | **Team 1-2 dev không kham nổi marketplace + SaaS + ngắn ngày song song** | HIGH | High | (a) **Cắt scope launch: chỉ SaaS dài hạn + lead-fee.** Marketplace ngắn ngày dời M4+. (b) Tuyển 1 mid-dev BE + 1 mid-dev FE Q3. (c) Thuê freelancer audit định kỳ. (d) AI dev assist tối đa. |

### Risk thứ cấp (theo dõi)
- GDPR-VN (NĐ 13/2023): cần consent flow + data export, **chưa thấy trong codebase** → fix trước launch.
- Thuế TNCN 10% cho host: tích hợp tax calc Phase 2 (sell point chứ không phải risk).
- App Store / Play Store reject vì thiếu privacy policy + content moderation → chuẩn bị docs.

---

## 9. Readiness Score

| Dimension | Weight | Score | Lý do |
|---|---|---|---|
| Market viability | 30% | **75/100** | TAM lớn, SAM rõ ràng, beachhead segment validate được. -25đ vì SOM dependent on payment/SEO chưa có. |
| Requirement clarity | 30% | **60/100** | MVP tech rõ. Nhưng pricing model chưa A/B, dispute flow chưa spec, payment compliance unclear. |
| Plan feasibility | 30% | **55/100** | Team 1-2 dev là bottleneck nghiêm trọng. Roadmap 6 tháng phải cắt scope. |
| Risk controllability | 10% | **65/100** | 4/5 risk có mitigation rõ. Risk #1 (license) phụ thuộc bên ngoài. |

**Tổng: 0.3×75 + 0.3×60 + 0.3×55 + 0.1×65 = 22.5 + 18 + 16.5 + 6.5 = 63.5/100**

→ **CONDITIONAL GO** (ngưỡng 60-79).

---

## 10. Recommendation: CONDITIONAL GO

### Điều kiện (must close trong 60 ngày)
1. **Chốt mô hình payment**: post-paid commission từ host (không escrow) cho M1-M3; song song đàm phán escrow bank.
2. **Build SEO web public** (Next.js/Astro) cho listing — không thể skip nếu muốn organic guest.
3. **Cắt scope launch M1-M3**: chỉ SaaS dài hạn + lead-fee. Homestay ngắn ngày dời M4+.
4. **KYC + hợp đồng pháp lý** xong trước public launch.
5. **Tuyển +1 mid-dev** trước M3 nếu muốn giữ tốc độ.

Nếu không close được 1-4 trong 60 ngày → downgrade NO-GO public launch, ở chế độ private beta thêm 60 ngày.

---

## 11. Action Plan — 2 tuần đầu (priority sequence)

### Week 1
1. **[Chuyên gia ngành]** Khởi động làm việc với 2-3 ngân hàng (MB/Techcombank/VPBank) về escrow + check sơ bộ với NHNN về giấy phép trung gian thanh toán. Deliverable: 1 trang option matrix.
2. **[Dev]** Spike kỹ thuật SEO rewrite: chọn Next.js vs Astro, POC 1 trang listing detail SSR. Deliverable: ADR + estimate.
3. **[Chuyên gia ngành + luật sư]** Đặt hàng review hợp đồng mẫu (thuê dài hạn + homestay ngắn ngày + ToS marketplace). Deliverable: SOW + báo giá.
4. **[Marketing AI]** Sản xuất 10 short-video pilot — 5 cho host pain, 5 cho guest discovery — A/B 3 thumbnail/script. Deliverable: 10 video + CTR baseline.
5. **[PM/Founder]** Phỏng vấn 10 host beachhead (Bình Thạnh + Gò Vấp): WTP, current tool, KB04 pain. Deliverable: research note.

### Week 2
6. **[Dev]** Tích hợp VNPay sandbox + KYC eKYC sandbox (VNPT hoặc FPT.AI). Deliverable: working demo trong dev env.
7. **[Dev]** Build admin moderation dashboard MVP (list listing + approve/reject + ban user). Deliverable: deploy staging.
8. **[Marketing AI]** Launch chiến dịch pilot TikTok geo Bình Thạnh — 50k VND/ngày × 7 ngày. Deliverable: report CTR, CPR, signup intent.
9. **[Chuyên gia ngành]** Đăng ký Zalo OA chính thức + nộp hồ sơ tích xanh. Deliverable: OA verified.
10. **[PM]** Quyết định pricing tier final (49k vs 59k vs 79k) dựa research Week 1. Deliverable: pricing page draft + comparison vs Cohousing.

---

## 12. Open Questions

1. **Payment**: Founder/chuyên gia đã có quan hệ với bank nào ở mức quyết định? Có khả năng đẩy escrow xong trong < 3 tháng không?
2. **Funding**: Đang bootstrap hay đã raise? Burn rate cho phép tuyển thêm dev khi nào?
3. **Chuyên gia ngành**: Vai trò cụ thể là gì — co-founder full-time, advisor part-time, hay sales lead? Time commitment/tuần?
4. **Team AI video**: là in-house hay outsource? Số lượng video/ngày khả thi bền vững? Có quota TikTok ads budget không?
5. **Geography priority**: nếu phải chọn 1 trong 2, HCMC trước hay HN trước? (Đề xuất: HCMC vì chuyên gia ngành + planning lookup đã có).
6. **Brand**: "ancu365" vs "UrbanNest" — chọn 1 hay dual-brand B2C/B2B? Domain/trademark đã đăng ký chưa?
7. **Homestay strategy**: chấp nhận competing thẳng với Airbnb ở M4+ hay tránh và chỉ làm "long-stay 1-3 tháng" niche?
8. **Data/GDPR**: ai sẽ phụ trách DPO (Data Protection Officer) theo NĐ 13/2023?
9. **Tax compliance**: ancu365 có dự định làm tax-withholding hộ host (1% trên revenue homestay theo TT 40/2021) không?
10. **Exit strategy** (3-5 năm): IPO, acquisition bởi proptech (Cenhomes/Hozo)? Ảnh hưởng đến cấu trúc công ty + ESOP từ giờ.

---

> **Status**: Phân tích chiến lược pre-development hoàn tất. Verdict CONDITIONAL GO với readiness 63.5/100. Khuyến nghị founder review 10 open questions trước khi Tech Lead bắt đầu Phase 01 (Product Roadmap 6 tháng).
