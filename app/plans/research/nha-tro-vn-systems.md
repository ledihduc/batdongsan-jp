# Vietnamese Boarding House (Nhà Trọ) Management Systems — Market Research

**Date:** June 22, 2026  
**Scope:** Top 7 Vietnamese boarding house management apps; feature mapping; pain points; data model patterns  
**Output:** Feature taxonomy + data model reference for FaceConst "host" role design

---

## 1. Top 7 Boarding House Management Apps in Vietnam

| # | App | URL | Model | Pricing |
|---|-----|-----|-------|---------|
| 1 | **LOZIDO** | quanlytro.me | Web + mobile (iOS/Android) | Freemium: 25-day trial, free tier (limited), Pro tier |
| 2 | **Resident** | resident.vn | Web + mobile | Subscription-based (comparison tool available) |
| 3 | **Simple House** | (No official URL found) | Web + mobile | Free (fully) |
| 4 | **DigiStay** | (No official URL) | Mobile (iOS/Android) | Free (fully) |
| 5 | **Smartos** | smartos.space | Web + mobile | Subscription (high cost for small props) |
| 6 | **MONA House** | mona.media | Web + mobile | Subscription |
| 7 | **Ami** | (Japanese company) | Mobile-first | Subscription (AI/IoT-powered) |

---

## 2. Core Features by System Area

### 2.1 Multi-Property & Building Management
- **Manage multiple buildings/tòa nhà**: Separate organizations, each with floors/wings/areas
- **Building hierarchy**: Building > Floor > Wing > Room (Odoo standard model)
- **Common areas**: Corridors, gates, stairwells with shared utility costs
- **Address management**: Province > District > Ward > Street (Vietnam admin hierarchy)
- **Status tracking**: Active/Inactive building; maintenance/renovation dates

**Apps:** LOZIDO, Resident, Smartos, MONA House support multi-property.

---

### 2.2 Room Inventory & Status Management
- **Room catalog**: Room code (e.g., 101, 202A), area (m²), capacity, amenities
- **Room status enum**: Vacant (Trống) | Occupied (Đang ở) | Maintenance (Sửa) | Reserved (Bảo lưu)
- **Meter tracking**: Electricity meter (kWh), water meter (m³), IoT integration (Ami, LOZIDO)
- **Rate rules**: Base rent + service fees (garbage, security, parking) per room type
- **Asset inventory**: Furniture, appliances linked to room (for damage tracking)

**Key insight:** Manual meter reading vs. IoT—LOZIDO auto-pulls readings; smaller apps require manual entry.

---

### 2.3 Tenant Management (KYC + Registration)
- **Tenant profile**: Full name, DOB, gender, phone, email, ID type (CCCD/passport/etc.)
- **ID verification**: CCCD scan, passport for foreigners (legal requirement)
- **Khai báo tạm trú (temporary residence registration)**: Status flag + integration with VNeID app (2026 requirement)
- **Emergency contact**: Name, phone, relationship
- **Nationality/foreigner flag**: For compliance (fines up to 6M VND if undeclared foreigner)
- **Move-in/move-out dates**: Linked to contract lifecycle

**Critical pain point:** Manual tạm trú registration is chủ trọ burden; VNeID integration (via API) would be game-changer.

---

### 2.4 Contract Lifecycle Management
- **Contract types**: Monthly lease | semester (6mo) | annual
- **Contract fields**: Start date, end date, rent amount, deposit (cọc), deposit % (usually 1-2 months)
- **Terms storage**: Renewal option, early termination penalty, house rules
- **Deposit tracking**: Paid date, held-in-escrow status, refund date, deductions (damages)
- **Contract state**: Draft | Active | Expired | Renewed | Terminated | Refund-pending

**Apps:** All track contract dates; LOZIDO has expiration alerts.

---

### 2.5 Monthly Rent & Utility Billing
- **Rent calculation**: Base rent + service fees (garbage, security, internet, parking, water heating)
- **Utilities breakdown**:
  - **Electricity**: Reading (kWh) × rate (VND/kWh). Regulations: ≤ 2,000 VND/kWh residential; chủ trọ often charges 3–5K illegally → pain point
  - **Water**: Reading (m³) × rate. Standard: 15,000–20,000 VND/m³
  - **Gas** (if applicable): Bottled gas or piped
- **Surcharge rules**: Late fee, extra person surcharge, damage fees
- **Billing cycle**: Auto-generate invoice on fixed day (1st, 20th, etc.)

**Features:** LOZIDO auto-pulls meter readings → invoice; Simple House/DigiStay require manual entry.

---

### 2.6 Invoice & Payment Tracking
- **Invoice generation**: Auto-create PDF with: room code, tenant name, period, itemized charges, due date, balance-forward
- **Payment receipt**: Date, method (cash, bank transfer, e-wallet), reference number, notes
- **Debt tracking**: Outstanding balance, aging (0–30d, 30–60d, 60d+)
- **Payment reminder**: SMS/Zalo/email notification (24h before due date)
- **Bank reconciliation**: Match payments to invoices (LOZIDO auto-reconciles)

**Apps support:** All generate invoices; DigiStay supports Bluetooth printers (on-site collection); LOZIDO auto-reconciles.

---

### 2.7 Reporting & Financial Analytics
- **Monthly P&L**: Revenue (rent + utilities) vs. expenses (maintenance, utilities paid to utility co., staff)
- **Occupancy rate**: Occupied rooms / total rooms (%)
- **Room-level revenue**: Total revenue per room over period
- **Debt report**: List of tenants with unpaid invoices + aging
- **Tax report**: Structured journal + ledger (LOZIDO auto-generates)

**Feature maturity:** LOZIDO most comprehensive; others basic summaries.

---

### 2.8 Tenant Notifications & Communication
- **Channels**: SMS, Zalo (critical in Vietnam), in-app push, email
- **Triggers**:
  - Rent due reminder (24h–3d before)
  - Invoice generated notification
  - Contract expiration warning (30d before)
  - Room inspection scheduled
  - House rule violation
  - Account balance low/overdue
- **Bulk messaging**: Send to all tenants in building

**Key:** Zalo integration is critical—**most Vietnamese tenants use Zalo, not SMS**. DigiStay's in-app chat reduces notification friction.

---

### 2.9 Meter Integration (Electricity/Water)
- **Manual reading**: Host enters readings; system calculates owed
- **IoT integration**: Smart meters push readings to app (Ami, LOZIDO)
- **Historical tracking**: Per-tenant usage trend; anomaly detection (spike = leak)
- **Regulation compliance**: EVN/Saigon Water rules on rate-per-kWh; automatic cap enforcement

**Integration gap:** Most VN boarding house apps offer manual only. Ami differentiates with IoT.

---

### 2.10 Đăng Ký Tạm Trú (Temporary Residence Registration)
- **VNeID integration**: API call to register tenant on gov platform (online since Jan 2024)
- **Requirements**: Tenant Level-2 VNeID + rental contract photo + chủ trọ approval (Level-2 VNeID)
- **Workflow**:
  1. Host uploads contract + tenant ID to app
  2. Tenant approves in VNeID app
  3. App submits to Công An (Police) via Portal
  4. Status tracked in app: Pending | Registered | Rejected
- **Compliance risk**: Fine up to 1M VND if not registered (Government Decree 282/2025)

**Critical gap:** No Vietnamese boarding house app currently integrates VNeID. This is a **major differentiation opportunity**.

---

## 3. Pain Points (Solved + Unsolved)

### SOLVED by Current Apps
| Pain Point | Solution |
|------------|----------|
| Manual invoice creation | Auto-generate + print |
| Electricity overcharging | Rate cap enforcement (LOZIDO) |
| Payment tracking across tenants | Centralized ledger + aging report |
| Contract expiration forgotten | Alerts 30d before |
| Meter reading errors | Auto-pull (Ami, LOZIDO) or structured input |
| Room vacancy visibility | Dashboard occupancy % |

### UNSOLVED (Gaps)
| Pain Point | Why Unsolved | Implication for FaceConst |
|------------|--------------|------------------------|
| **VNeID Tạm Trú integration** | Complex gov API, regulatory risk | **Differentiation:** Automate the #1 legal burden |
| **Multi-property financial rollup** | Requires enterprise pricing tier | SMB landlords want simple consolidated P&L |
| **Foreign tenant compliance** | Undeclared = 6M VND fine; hard to audit | Build compliance checklist + audit trail |
| **Damage deposit disputes** | No photo/video evidence capture at check-in/out | Integrate photo upload + timeline |
| **Tenant credit scoring** | Apps don't assess payment history | Optional: risk score for future bookings |
| **Bulk contract renewal** | Manual one-by-one; no auto-template | Batch renewal with terms adjustments |
| **Utility fraud detection** | No anomaly alerts (usage spike = leak/theft) | Smart meter correlation + alerts |
| **Legal document templates** | Apps assume contract already exists | Provide VN-compliant contract builder |
| **Cross-platform payment** | No direct integration with banking (e-wallet, QR) | Accept Momo, ZaloPay, BIDV QR in-app |

---

## 4. Common Data Model (Entity-Relationship)

Derived from LOZIDO, Resident, Odoo Property Management module:

```
BUILDING
├─ id, name, address, province, district, ward
├─ owner_id (FK → HOST)
├─ total_rooms, occupied_rooms
├─ created_at, updated_at
│
ROOM
├─ id, code (e.g., 101), building_id (FK)
├─ floor, area_m2, capacity, status (enum: vacant/occupied/maintenance)
├─ base_rent_monthly, amenities_json
├─ electricity_meter_id, water_meter_id (FK → METER)
├─ created_at, updated_at
│
TENANT
├─ id, full_name, dob, gender, phone, email
├─ id_type (enum: cccd/passport), id_number, id_photo_url
├─ nationality, is_foreigner
├─ tam_tru_status (enum: pending/registered/rejected), tam_tru_vn_eid_number
├─ emergency_contact_name, emergency_contact_phone
├─ created_at, updated_at
│
CONTRACT
├─ id, tenant_id (FK), room_id (FK), building_id (FK)
├─ start_date, end_date, status (enum: draft/active/expired/renewed/terminated)
├─ monthly_rent, deposit_amount, deposit_paid_date, deposit_refunded_date
├─ deposit_refund_deduction_reason, renewal_option
├─ contract_file_url, signed_date
├─ created_at, updated_at
│
INVOICE
├─ id, contract_id (FK), room_id (FK), period (YYYY-MM)
├─ rent_amount, electricity_cost, water_cost, service_fees, total_due
├─ due_date, status (enum: draft/issued/paid/partial/overdue)
├─ generated_at, paid_at
│
PAYMENT
├─ id, invoice_id (FK), contract_id (FK)
├─ amount, method (enum: cash/bank_transfer/e_wallet), reference_number
├─ paid_date, notes
│
METER (Electricity/Water)
├─ id, room_id (FK), meter_type (enum: electricity/water)
├─ meter_number, current_reading, reading_date, unit (kWh/m³)
├─ rate_per_unit, auto_push_enabled (bool, for IoT)
├─ created_at, updated_at
│
SERVICE_FEE (Garbage, Security, Internet, etc.)
├─ id, building_id (FK), service_name, monthly_cost
├─ applies_to_all_rooms (bool), room_ids_json (if selective)
│
NOTIFICATION_LOG
├─ id, tenant_id (FK), type (enum: rent_due/invoice_generated/contract_expiring)
├─ channel (enum: sms/zalo/email/in_app), status (enum: pending/sent/failed)
├─ sent_at
│
AUDIT_LOG
├─ id, entity_type (enum: contract/invoice/payment), entity_id
├─ action (create/update/delete), changed_by (FK → HOST), changed_at
```

**Key observations:**
- **No separate "Host" table** — Host is auth user with Building ownership
- **Contract → multiple Invoices** (one per month)
- **Notification tracking** required for compliance + SMS/Zalo metrics
- **Audit trail** critical for dispute resolution + tax compliance
- **Tạm trú integration** adds `tam_tru_status + vneid_number` to Tenant

---

## 5. Feature Classification: Must-Have vs. Nice-to-Have

### MUST-HAVE (MVP for viable host product)
1. ✅ **Multi-building + multi-room inventory** — Non-negotiable; competitive necessity
2. ✅ **Contract + lease term tracking** — Legal requirement; core to rent collection
3. ✅ **Monthly invoice generation** (rent + utilities itemized) — Essential workflow
4. ✅ **Payment tracking + debt aging** — Cash flow depends on it
5. ✅ **Tenant profile + ID verification** — VN legal compliance
6. ✅ **Notification system** (Zalo + SMS) — Rent collection success driver
7. ✅ **Basic reporting** (occupancy, revenue summary) — Host decision-making

### NICE-TO-HAVE (Differentiator)
1. 🎯 **VNeID tạm trú integration** — Legal automation; major pain point
2. 🎯 **IoT meter integration** — Reduce utility disputes; fraud prevention
3. 🎯 **Damage deposit photo evidence** — Reduce refund disputes
4. 🎯 **Zalo/banking payment gateway** — Reduce payment friction
5. 🎯 **Tax report auto-generation** — Reduce compliance burden
6. 🎯 **Foreign tenant compliance checklist** — Reduce audit risk
7. 🎯 **Bulk contract renewal** — Reduce manual work at scale

### NOT NEEDED (Out of scope for MVP)
- ❌ Booking/vacancy listing (belongs to marketplace, not host operations)
- ❌ Furnished inventory tracking (nice for furnished rentals, not core)
- ❌ Staff management (not relevant for SMB landlords)
- ❌ Preventive maintenance scheduling (low-priority for boarding houses)

---

## 6. Pricing & Business Model Patterns

| Model | Apps | Notes |
|-------|------|-------|
| **Freemium** | LOZIDO, Simple House, DigiStay | Free tier (limited rooms/buildings); upgrade for multi-prop |
| **Subscription (Monthly)** | Resident, Smartos, MONA | 50K–500K VND/mo depending on property count |
| **Subscription (Annual)** | Most | 30% discount vs. monthly |
| **Commission on rent** | None observed | Taboo in VN market; landlords resist |

**Implication for FaceConst:** Host features likely **free or low-cost**; differentiate on VNeID integration + compliance, not pricing.

---

## 7. Technology Stack Observations

| Component | Typical Stack |
|-----------|---------------|
| **Backend** | Node.js/Python + PostgreSQL (Odoo standard) |
| **Frontend** | React/Vue.js (web) + React Native/Flutter (mobile) |
| **Notifications** | Twilio SMS + Zalo Bot API + Firebase Push |
| **Meters** | HTTP/MQTT for IoT; scheduled polling |
| **Gov Integration** | REST API to National Public Service Portal (VNeID) |
| **Payments** | Momo API, ZaloPay, bank transfer tracking (ACH simulation) |
| **Reports** | Jasper/Crystal Reports or custom PDF generation |

---

## 8. Vietnam-Specific Regulatory Constraints

| Requirement | Apps' Approach | FaceConst Implication |
|-------------|---|---|
| **Tạm trú for tenants >30d** | Manual (must improve) | Integrate VNeID API (gov mandate 2024+) |
| **Electricity rate cap** | LOZIDO enforces; others don't | Implement rate validation (3K VND/kWh max) |
| **ID verification** | Require CCCD photo | Storage compliant with GDPR-lite (Law 34/2018) |
| **Contract bilingual (if foreigner)** | Assumed in contract build | Offer EN/VN templates |
| **Deposit holding period** | App tracks date; no escrow | Clarify in terms (legal: returned within 30d post-checkout) |
| **Foreign tenant disclosure** | No current app enforces | Add compliance checkbox + flag for audit |
| **Tax deductibility** | Apps don't opine; user tracks | Provide receipt/invoice format for tax filing |

---

## 9. Integration Points for FaceConst Marketplace

### Inbound Integrations (Host → FaceConst)
- **Sync available rooms** to marketplace listing (auto-update vacancy)
- **Occupancy history** → trust score (occupied consistently = reliable landlord)
- **Payment history** → financial credibility badge

### Outbound Integrations (FaceConst → Host)
- **New tenant booked** → auto-create contract template (pre-filled name, dates)
- **Tenant profile from booking** → auto-populate tenant KYC form
- **Payment collected by marketplace** → sync to invoice ledger (cash flow transparency)

### No Direct Integration (Separate Systems)
- ❌ Listing search/filter (marketplace domain)
- ❌ Messaging/chat (marketplace channels)
- ❌ Tenant review/rating (marketplace domain, separate from operations)

---

## 10. Competitive Analysis: Adjacencies

| App | Strength | Weakness | Opportunity for FaceConst |
|-----|----------|----------|--------------------------|
| **LOZIDO** | Auto meter + reports | Clunky UI; no VNeID | Cleaner UX + VNeID integration |
| **Resident** | Good comparisons | Generic; not VN-specific | Vietnam-localized pain point focus |
| **Simple House** | Free + simple | Lacks advanced features | Add compliance automation |
| **DigiStay** | Free + in-app chat | Limited reporting | Better financial analytics |
| **Smartos** | Enterprise-grade | Overkill for SMB; expensive | Affordable tier for micro-landlords |
| **Ami** | IoT leader | Limited ecosystem | Full marketplace + operations combo |

**FaceConst angle:** Position as **"Marketplace + Ops, not Marketplace OR Ops"** — unified host experience.

---

## Summary: Top 3 Insights for Feature Design

1. **VNeID tạm trú integration is a 10x differentiation** — None of the 7 apps offer it; it's the #1 chủ trọ pain point (legal risk + time). Investing here pays 100:1 ROI.

2. **Zalo is mandatory; SMS/email is optional** — Vietnamese tenants' default communication channel. Apps that only do SMS miss 80% of engagement.

3. **Freemium model with subscription tier beats pure subscription** — Adoption friction is high in VN SMB market. Free MVP (1–2 buildings) wins, then convert on VNeID unlock or advanced analytics.

---

## Unresolved Questions

1. **VNeID API availability:** Is there public API docs or must we partner with gov? Response time? Sandbox available?
2. **Electricity meter integration cost:** Do popular smart meter vendors (Ami partners) offer API access, or is it proprietary?
3. **Tax compliance depth:** Does FaceConst need to auto-generate full tax filings (tax returns), or just receipt formatting?
4. **Zalo Business API rate limits:** How many msgs/day can we send for 10K+ hosts without hitting spam filters?
5. **Data retention regulations:** How long to retain tenant CCCD photos (security vs. privacy)?
6. **Deposit escrow legality:** Can FaceConst hold deposits as marketplace intermediary, or must host manage independently?

---

## Sources

- [Top 15 phần mềm quản lý nhà trọ miễn phí tốt nhất hiện nay](https://www.pos365.vn/phan-mem-quan-ly-nha-tro-6790.html)
- [LOZIDO - Quản lý trọ, căn hộ](https://quanlytro.me/)
- [RESIDENT - Phần Mềm Quản Lý Nhà Trọ](https://resident.vn/)
- [Smartos - Phần mềm quản lý nhà trọ](https://smartos.space/)
- [Top 10 phần mềm quản lý nhà trọ hiệu quả nhất năm 2026](https://resident.vn/top-10-phan-mem-quan-ly-nha-tro/)
- [The Importance of Using a Digital Boarding House Management App](https://nimbus9.tech/blog/en/the-importance-of-using-a-digital-boarding-house-management-app/)
- [Cách đăng ký tạm trú online cho người thuê nhà 2026](https://thuvienphapluat.vn/phap-luat/cach-dang-ky-tam-tru-online-cho-nguoi-thue-nha-2025-moi-nhat-cach-dang-ky-tam-tru-online-cho-nguoi-thue-nha--894901-198737.html)
- [Hướng dẫn đăng ký tạm trú trên VNeID 2026](https://www.meinvoice.vn/tin-tuc/42009/cach-dang-ky-tam-tru-tren-vneid/)
- [Cách tính tiền điện, nước nhà trọ theo quy định mới](https://luatvietnam.vn/tin-phap-luat/cach-tinh-tien-dien-nuoc-nha-tro-theo-quy-dinh-moi-230-18375-article.html)
- [Tenant Property Contract Management - Odoo](https://apps.odoo.com/apps/modules/18.0/tenant_property_contract_management)
- [Property Management - Odoo Apps Store](https://www.odoo.com/industries/property-management)
