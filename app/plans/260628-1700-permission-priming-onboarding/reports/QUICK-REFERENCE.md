# Quick Reference — Permission Priming Copy & UX

**For:** Tech Lead + Copywriter  
**Date:** 2026-06-28  
**Full Report:** `researcher-priming-ux-copy.md`

---

## Vietnamese Copy — Ready to Copy/Paste

### Guest Push Notification (Post-Login)
```
Nhận thông báo khi có phòng mới được đăng, tin nhắn từ chủ nhà,
và các ưu đãi đặc biệt dành riêng cho bạn.
```

### Host Push Notification (Post-Listing)
```
Không bỏ lỡ một đơn đặt phòng nào:
- Thông báo mới về yêu cầu đặt phòng
- Tin nhắn từ khách tiềm năng
- Lịch xem phòng của khách từ các thành phố khác
```

### CCCD Camera Upload
```
Xác minh danh tính nhanh chóng với ảnh chứng minh thư:
- Quá trình xác minh tự động (dưới 1 phút)
- Ảnh của bạn được mã hóa và lưu trữ an toàn
- Được bảo vệ bởi tiêu chuẩn bảo mật quốc tế
Chúng tôi không bao giờ chia sẻ ảnh của bạn với bên thứ ba.
```

### House Photo Upload (Host)
```
Những bức ảnh chất lượng cao giúp bạn kiếm thêm tiền:
- Khách hàng lựa chọn phòng có ảnh cao định nghĩa
- Tỷ lệ đặt phòng tăng trung bình 40% với ảnh chuyên nghiệp
- Gợi ý chụp ảnh từ chủ nhà có kinh nghiệm
```

### Profile Avatar
```
Ảnh đại diện giúp bạn được tin tưởng hơn:
- Khách hoặc chủ nhà có khả năng chọn bạn hơn 3 lần
- Ảnh rõ ràng, thân thiện giúp bao quanh đó biết bạn là ai
- 100% bảo mật: bạn kiểm soát ai có thể xem ảnh
```

---

## Key UX Numbers

| Metric | Target |
|--------|--------|
| iOS push opt-in WITHOUT priming | 43.9% |
| iOS push opt-in WITH priming | 56%+ (+28%) |
| Camera permission opt-in WITH priming | 70–75% |
| Re-ask acceptance (3–5 day window) | 80% |
| Button touch target minimum | 48px height/width |
| Contrast ratio minimum (mobile) | 7:1 |

---

## Implementation Timeline

### Week 1
- [ ] Copy review by native Vietnamese speaker
- [ ] Contrast & accessibility audit (VoiceOver + TalkBack testing)
- [ ] Procure illustrations: Storyset (free or $99/year pro)
- [ ] Design wireframes per spec in full report

### Week 2–3
- [ ] Implement priming sheets (Flutter/native)
- [ ] A/B test: short vs. medium copy (5% user sample)
- [ ] Implement re-ask timing logic (3–5 day defer)

### Week 4+
- [ ] Monitor opt-in rates, compare to benchmarks (target: 60%+)
- [ ] Analyze re-ask acceptance (target: 75%+)
- [ ] Iterate if opt-in < 50% (may need copy tweaks)

---

## Critical Don'ts

❌ **Never use:**
- Generic copy ("Enable notifications for best experience")
- Hidden "Don't Allow" button (dark pattern violation)
- Multiple permissions in one sheet (40% grant rate vs. 70%+)
- Request at app launch (13.85% opt-in baseline)

---

## Anti-Patterns

| Pattern | Why Fails | Your Target |
|---------|-----------|------------|
| Ask at startup | No context | Ask post-first-action |
| Generic headlines | No value | "Xác Minh Với Ảnh" not "Cấp Quyền Camera" |
| Hidden "Sau" button | CPPA violation | Equal visual weight (outline button) |
| "Bật Ngay" only | Pushy | Always show "Để Sau" option |

---

## Accessibility Checklist

- [ ] Contrast 7:1 minimum on mobile (test with WebAIM tool)
- [ ] Touch targets 48px × 48px minimum
- [ ] Both buttons ("Bật Ngay" + "Để Sau") filled/outlined (equal weight)
- [ ] Screen reader labels: `aria-label="Bật camera để xác minh chứng minh thư"`
- [ ] No color-only information (use icons + text)

---

## Illustration

**Recommendation:** Storyset (real estate collection)
- **Free version:** stoyset.com/real-estate
- **Pro:** Customize to red (#B71C1C) + green (#00A65A)
- **Export:** Animated GIF (2–3 sec loop) OR Lottie JSON (lighter)
- **Use case examples:**
  - CCCD upload: "Người chụp ảnh tài liệu"
  - House photo: "Người chụp ảnh căn phòng"
  - Profile avatar: "Người chỉnh sửa hồ sơ"

---

## Re-Ask Pattern (3–5 Days)

**First Denial:**
```
ℹ️ Bạn đã tắt camera. Bật trong Cài đặt để chụp ảnh phòng.
[Mở Cài đặt] [Bỏ qua]
```

**Second Prompt (Day 3–5):**
- Only show if user has 15+ sessions
- Use settings card (not modal) if rejection
- Allow manual entry alternative (e.g., type ID manually)

**Never:** Re-ask if denied twice in same session

---

## Expected Outcomes

**Conservative estimate:**
- Push notification opt-in: 55–60% (vs. 43.9% global baseline)
- Camera permission: 70%+ (vs. 40–50% without priming)
- Re-ask acceptance: 75%+ (at 3–5 day mark)

**These are realistic if:**
- Copy is reviewed by Vietnamese speaker
- Timing tied to feature use (not launch)
- Illustrations load within 2 sec
- Both buttons equally visible (no dark patterns)

---

## Questions for BA/Product

1. Should notification priming appear post-first-listing (host) or post-first-search (guest)?
2. Will CCCD use third-party provider (Ekyc, Onfido)? May conflict with our priming UI.
3. Current iOS/Android baseline opt-in rates from analytics? (helps set realistic targets)

---

**Status:** Report complete. Ready for copywriter + design handoff.
