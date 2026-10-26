# ARCHITECTURE (SINH TỰ ĐỘNG — đừng sửa tay)

> `python scripts/gen_arch_map.py --write`. `check.sh` gate diff.

## Endpoints theo router (module)

### app.api.routes.admin_dashboard
- `GET    /api/admin/audit-trail/{delegation_id}` → get_audit_trail
- `GET    /api/admin/dashboard/summary` → get_dashboard_summary
- `GET    /api/admin/users/{user_id}/delegations` → get_user_delegations

### app.api.routes.admin_delegations
- `POST   /api/admin/delegations/{delegation_id}/force-revoke` → force_revoke_delegation
- `POST   /api/admin/users/{user_id}/reinstate-operator` → reinstate_operator
- `POST   /api/admin/users/{user_id}/suspend-operator` → suspend_operator

### app.api.routes.admin_disputes
- `GET    /api/admin/disputes` → list_disputes
- `POST   /api/admin/disputes/{dispute_id}/escalate` → escalate_dispute
- `POST   /api/admin/disputes/{dispute_id}/resolve` → resolve_dispute

### app.api.routes.admin_retention
- `POST   /api/admin/retention/archive-delegations` → run_archive_batch
- `POST   /api/admin/retention/run-now` → run_retention_now
- `GET    /api/admin/retention/status` → retention_status

### app.api.routes.admin_v2.auth
- `POST   /api/v2/admin/auth/login` → login
- `POST   /api/v2/admin/auth/logout` → logout
- `GET    /api/v2/admin/auth/me` → me
- `POST   /api/v2/admin/auth/reauth` → reauth
- `GET    /api/v2/admin/auth/sessions` → my_sessions

### app.api.routes.admin_v2.compliance
- `GET    /api/v2/admin/compliance/access-logs` → access_logs
- `GET    /api/v2/admin/compliance/delegations` → list_delegations
- `GET    /api/v2/admin/compliance/delegations/{delegation_id}` → get_delegation
- `POST   /api/v2/admin/compliance/delegations/{delegation_id}/force-revoke` → force_revoke
- `POST   /api/v2/admin/compliance/delegations/{delegation_id}/revoke-requests` → request_revoke
- `GET    /api/v2/admin/compliance/disputes` → list_disputes
- `GET    /api/v2/admin/compliance/disputes/{dispute_id}` → get_dispute
- `POST   /api/v2/admin/compliance/disputes/{dispute_id}/escalate` → escalate_dispute
- `POST   /api/v2/admin/compliance/disputes/{dispute_id}/resolve` → resolve_dispute
- `GET    /api/v2/admin/compliance/kyc` → list_kyc
- `GET    /api/v2/admin/compliance/kyc/{profile_id}` → get_kyc
- `POST   /api/v2/admin/compliance/kyc/{profile_id}/approve` → approve_kyc
- `POST   /api/v2/admin/compliance/kyc/{profile_id}/approve-legal-rep-change` → approve_legal_rep_change
- `POST   /api/v2/admin/compliance/kyc/{profile_id}/reject` → reject_kyc
- `POST   /api/v2/admin/compliance/kyc/{profile_id}/revoke-gpkd` → revoke_gpkd
- `GET    /api/v2/admin/compliance/legal-holds` → list_legal_holds
- `POST   /api/v2/admin/compliance/legal-holds` → set_legal_hold
- `GET    /api/v2/admin/compliance/operators/{user_id}` → get_operator
- `POST   /api/v2/admin/compliance/operators/{user_id}/reinstate` → reinstate_operator
- `POST   /api/v2/admin/compliance/operators/{user_id}/suspend` → suspend_operator
- `GET    /api/v2/admin/compliance/owner-death` → list_owner_death
- `GET    /api/v2/admin/compliance/owner-death/{cert_id}` → get_owner_death
- `POST   /api/v2/admin/compliance/owner-death/{cert_id}/reject` → reject_owner_death
- `POST   /api/v2/admin/compliance/owner-death/{cert_id}/verify` → verify_owner_death
- `GET    /api/v2/admin/compliance/retention` → retention_status
- `POST   /api/v2/admin/compliance/retention/archive-delegations` → retention_archive
- `POST   /api/v2/admin/compliance/retention/run` → retention_run

### app.api.routes.admin_v2.content
- `GET    /api/v2/admin/content-reports` → list_content_reports
- `GET    /api/v2/admin/content-reports/{report_id}` → get_content_report
- `POST   /api/v2/admin/content-reports/{report_id}/decisions` → decide_content_report
- `GET    /api/v2/admin/listings` → list_listings
- `GET    /api/v2/admin/listings/{house_id}` → get_listing
- `POST   /api/v2/admin/listings/{house_id}/moderation-decisions` → decide_listing
- `POST   /api/v2/admin/listings/{house_id}/trusted` → set_listing_trusted
- `GET    /api/v2/admin/reels` → list_reels
- `GET    /api/v2/admin/reels/analytics` → reel_analytics
- `GET    /api/v2/admin/reels/{reel_id}` → get_reel
- `POST   /api/v2/admin/reels/{reel_id}/moderation-decisions` → decide_reel
- `GET    /api/v2/admin/reviews` → list_reviews
- `GET    /api/v2/admin/verifications` → list_verifications
- `POST   /api/v2/admin/verifications/{req_id}/complete` → complete_verification
- `POST   /api/v2/admin/verifications/{req_id}/reject` → reject_verification

### app.api.routes.admin_v2.documents
- `GET    /api/v2/admin/documents/download/{token}` → download_document
- `POST   /api/v2/admin/documents/sign` → sign_document
- `GET    /api/v2/documents/download/{token}` → download_own_document
- `POST   /api/v2/documents/sign` → sign_own_document

### app.api.routes.admin_v2.finance
- `GET    /api/v2/admin/finance/commissions` → list_commissions
- `GET    /api/v2/admin/finance/deposits` → list_deposits
- `GET    /api/v2/admin/finance/deposits/{deposit_id}` → get_deposit
- `POST   /api/v2/admin/finance/deposits/{deposit_id}/verify` → verify_deposit
- `GET    /api/v2/admin/finance/invoices` → list_invoices
- `GET    /api/v2/admin/finance/overview` → finance_overview
- `GET    /api/v2/admin/finance/payments` → list_payments
- `POST   /api/v2/admin/finance/payments` → record_payment
- `GET    /api/v2/admin/finance/payments/{payment_id}` → get_payment
- `POST   /api/v2/admin/finance/payments/{payment_id}/reconcile` → reconcile_payment
- `POST   /api/v2/admin/finance/payments/{payment_id}/refund-records` → record_refund
- `GET    /api/v2/admin/finance/reconciliation` → reconciliation
- `GET    /api/v2/admin/finance/refunds` → list_refunds
- `GET    /api/v2/admin/finance/settlements` → list_settlements

### app.api.routes.admin_v2.overview
- `GET    /api/v2/admin/activity` → recent_activity
- `GET    /api/v2/admin/alerts` → alerts
- `GET    /api/v2/admin/badges` → badges
- `GET    /api/v2/admin/dashboard` → dashboard
- `GET    /api/v2/admin/search` → global_search
- `GET    /api/v2/admin/staff-directory` → staff_directory
- `GET    /api/v2/admin/work-items` → list_work_items
- `POST   /api/v2/admin/work-items` → create_work_item
- `GET    /api/v2/admin/work-items/{type_code}/{source_id}` → get_work_item
- `POST   /api/v2/admin/work-items/{type_code}/{source_id}/assign` → assign_work_item

### app.api.routes.admin_v2.partners
- `GET    /api/v2/admin/partners/construction-leads` → list_construction_leads
- `POST   /api/v2/admin/partners/construction-leads/{lead_id}/update` → update_construction_lead
- `GET    /api/v2/admin/partners/contractors` → list_contractors
- `GET    /api/v2/admin/partners/contractors/{cid}` → get_contractor
- `POST   /api/v2/admin/partners/contractors/{cid}/legal-decisions` → decide_contractor_legal
- `POST   /api/v2/admin/partners/contractors/{cid}/status` → set_contractor_status
- `GET    /api/v2/admin/partners/leads` → list_leads
- `POST   /api/v2/admin/partners/leads/{lead_id}/status` → set_lead_status
- `GET    /api/v2/admin/partners/sale-applications` → list_sale_applications
- `GET    /api/v2/admin/partners/sale-applications/{app_id}` → get_sale_application
- `POST   /api/v2/admin/partners/sale-applications/{app_id}/decisions` → decide_sale_application
- `GET    /api/v2/admin/partners/sale-owner-links` → list_sale_owner_links
- `GET    /api/v2/admin/partners/sales` → list_sales
- `GET    /api/v2/admin/partners/service-requests` → list_service_requests
- `POST   /api/v2/admin/partners/service-requests/{req_id}/update` → update_service_request
- `POST   /api/v2/admin/partners/{kind}/{item_id}/reveal-contact` → reveal_contact
- `GET    /api/v2/admin/settings/catalog` → get_catalog
- `GET    /api/v2/admin/settings/deposit-policy` → get_deposit_policy
- `POST   /api/v2/admin/settings/deposit-policy` → create_deposit_policy
- `GET    /api/v2/admin/settings/planning-provinces` → list_planning_provinces
- `POST   /api/v2/admin/settings/planning-provinces/{slug}` → toggle_planning_province

### app.api.routes.admin_v2.rentals
- `GET    /api/v2/admin/rentals/contracts` → list_contracts
- `GET    /api/v2/admin/rentals/contracts/{contract_id}` → get_contract
- `POST   /api/v2/admin/rentals/journey-reports/{report_id}/decisions` → decide_journey_report
- `GET    /api/v2/admin/rentals/journeys` → list_journeys
- `GET    /api/v2/admin/rentals/journeys/{journey_id}` → get_journey
- `POST   /api/v2/admin/rentals/journeys/{journey_id}/cancel` → cancel_journey
- `GET    /api/v2/admin/rentals/journeys/{journey_id}/timeline` → journey_timeline
- `GET    /api/v2/admin/rentals/occupancy` → room_occupancy
- `GET    /api/v2/admin/rentals/reservations` → list_reservations
- `GET    /api/v2/admin/rentals/reservations/{reservation_id}` → get_reservation
- `POST   /api/v2/admin/rentals/reservations/{reservation_id}/approve` → approve_reservation
- `POST   /api/v2/admin/rentals/reservations/{reservation_id}/cancel` → cancel_reservation
- `POST   /api/v2/admin/rentals/reservations/{reservation_id}/reject` → reject_reservation
- `GET    /api/v2/admin/rentals/sale-requests` → list_sale_requests
- `GET    /api/v2/admin/rentals/sale-requests/{request_id}` → get_sale_request
- `GET    /api/v2/admin/rentals/viewings` → list_viewings

### app.api.routes.admin_v2.staff
- `GET    /api/v2/admin/change-requests` → list_change_requests
- `GET    /api/v2/admin/change-requests/{req_id}` → get_change_request
- `POST   /api/v2/admin/change-requests/{req_id}/approve` → approve_change_request
- `POST   /api/v2/admin/change-requests/{req_id}/draft` → update_draft
- `POST   /api/v2/admin/change-requests/{req_id}/reject` → reject_change_request
- `POST   /api/v2/admin/change-requests/{req_id}/submit` → submit_draft
- `GET    /api/v2/admin/roles` → list_roles
- `GET    /api/v2/admin/staff` → list_staff
- `GET    /api/v2/admin/staff/{user_id}` → get_staff
- `POST   /api/v2/admin/staff/{user_id}/roles` → grant_role
- `POST   /api/v2/admin/staff/{user_id}/roles/{role_code}/revoke` → revoke_role
- `POST   /api/v2/admin/staff/{user_id}/sessions/revoke` → revoke_staff_sessions

### app.api.routes.admin_v2.system
- `GET    /api/v2/admin/audit-events` → audit_events
- `GET    /api/v2/admin/events` → events_since
- `GET    /api/v2/admin/events/stream` → events_stream
- `GET    /api/v2/admin/system/flags` → system_flags
- `GET    /api/v2/admin/system/health` → system_health
- `GET    /api/v2/admin/system/jobs` → list_jobs
- `POST   /api/v2/admin/system/jobs/{job_id}/retry` → retry_job
- `GET    /api/v2/admin/system/notifications` → list_notifications
- `POST   /api/v2/admin/system/notifications/{push_id}/retry` → retry_notification

### app.api.routes.admin_v2.users
- `GET    /api/v2/admin/users` → list_users
- `GET    /api/v2/admin/users/{user_id}` → get_user
- `POST   /api/v2/admin/users/{user_id}/reinstate` → reinstate_user
- `POST   /api/v2/admin/users/{user_id}/reveal-pii` → reveal_pii
- `POST   /api/v2/admin/users/{user_id}/revoke-sessions` → revoke_user_sessions
- `POST   /api/v2/admin/users/{user_id}/suspend` → suspend_user
- `GET    /api/v2/admin/users/{user_id}/tabs/{tab}` → user_tab

### app.api.routes.approval
- `GET    /api/approvals` → list_approvals
- `GET    /api/approvals/{approval_id}` → get_approval_detail
- `POST   /api/approvals/{approval_id}/approve` → approve_approval
- `POST   /api/approvals/{approval_id}/cancel` → cancel_approval
- `POST   /api/approvals/{approval_id}/reject` → reject_approval
- `POST   /api/delegations/{delegation_id}/report-fraud` → report_fraud
- `POST   /api/kb04/pre-file` → kb04_pre_file
- `POST   /api/kb04/{khai_bao_id}/submit-fast-track` → kb04_submit_fast_track

### app.api.routes.commission
- `GET    /api/commission/operator/{operator_id}/dashboard` → operator_dashboard
- `GET    /api/commission/owner/{owner_id}/report` → owner_commission_report

### app.api.routes.delegation
- `GET    /api/delegations` → list_delegations
- `POST   /api/delegations/internal/pause-for-operator/{operator_user_id}` → pause_for_gpkd_revocation
- `GET    /api/delegations/invitations` → list_invitations
- `POST   /api/delegations/invitations` → create_invitation
- `GET    /api/delegations/invitations/{invitation_id}` → get_invitation
- `POST   /api/delegations/invitations/{invitation_id}/accept` → accept_invitation
- `POST   /api/delegations/invitations/{invitation_id}/decline` → decline_invitation
- `POST   /api/delegations/invitations/{invitation_id}/revoke` → revoke_invitation
- `GET    /api/delegations/{delegation_id}` → get_delegation
- `GET    /api/delegations/{delegation_id}/audit` → get_delegation_audit
- `POST   /api/delegations/{delegation_id}/cancel-termination` → cancel_termination
- `PATCH  /api/delegations/{delegation_id}/out-of-office` → set_out_of_office
- `POST   /api/delegations/{delegation_id}/pause` → pause_delegation
- `POST   /api/delegations/{delegation_id}/resign` → resign_delegation
- `POST   /api/delegations/{delegation_id}/resume` → resume_delegation
- `POST   /api/delegations/{delegation_id}/revoke` → terminate_delegation
- `PATCH  /api/delegations/{delegation_id}/thresholds` → update_thresholds

### app.api.routes.demand
- `GET    /api/demands` → list_demands
- `POST   /api/demands` → create_demand
- `GET    /api/demands/mine` → my_demands
- `GET    /api/demands/{demand_id}` → get_demand
- `PATCH  /api/demands/{demand_id}` → update_demand

### app.api.routes.jp.address
- `GET    /api/jp/address/lookup` → lookup_address

### app.api.routes.jp.listings (Phase 01)
- `POST   /api/jp/listings/attach` → attach_jp_listing_data
- `GET    /api/jp/listings/{listing_id}/jp-data` → get_jp_listing_data
- `GET    /api/jp/stations/search` → search_stations

### app.api.routes.jp.viewings (Phase 01)
- `POST   /api/jp/viewings` → create_viewing
- `GET    /api/jp/viewings` → list_viewings
- `GET    /api/jp/viewings/{viewing_id}` → get_viewing
- `POST   /api/jp/viewings/{viewing_id}/confirm` → confirm_viewing_endpoint
- `POST   /api/jp/viewings/{viewing_id}/cancel` → cancel_viewing_endpoint
- `POST   /api/jp/viewings/{viewing_id}/complete` → complete_viewing_endpoint

### app.api.routes.jp.applications (Phase 01)
- `POST   /api/jp/applications` → create_application
- `GET    /api/jp/applications` → list_applications
- `GET    /api/jp/applications/{app_id}` → get_application
- `POST   /api/jp/applications/{app_id}/submit` → submit_application_endpoint
- `POST   /api/jp/applications/{app_id}/start-review` → start_review_endpoint
- `GET    /api/jp/applications/{app_id}/upload-url` → get_upload_url (TODO P2 stub)

### app.api.routes.jp.application_reviews (Phase 01)
- `POST   /api/jp/applications/{app_id}/reviews` → submit_review_decision
- `GET    /api/jp/applications/{app_id}/reviews` → list_reviews_for_application

### app.api.routes.kyc
- `POST   /admin/kyc/operator-business/{profile_id}/approve` → admin_approve_business_kyc
- `POST   /admin/kyc/operator-business/{profile_id}/approve-legal-rep-change` → admin_approve_legal_rep_change
- `POST   /admin/kyc/operator-business/{profile_id}/reject` → admin_reject_business_kyc
- `PATCH  /admin/kyc/operator-business/{profile_id}/revoke-gpkd` → admin_revoke_gpkd
- `GET    /admin/kyc/queue` → admin_kyc_queue
- `PATCH  /api/kyc/delegation/{delegation_id}/shared-login-disclosure-ack` → ack_delegation_shared_login_disclosure
- `POST   /api/kyc/digital-signature/callback` → digital_signature_callback
- `POST   /api/kyc/digital-signature/initiate` → initiate_digital_signature
- `GET    /api/kyc/onboarding/status` → onboarding_status
- `POST   /api/kyc/operator/business/gpkd` → upload_business_gpkd
- `POST   /api/kyc/operator/business/info` → submit_business_info
- `POST   /api/kyc/operator/business/legal-rep` → submit_legal_rep
- `POST   /api/kyc/operator/business/legal-rep-change` → initiate_legal_rep_change
- `GET    /api/kyc/operator/business/me` → get_business_profile_me
- `GET    /api/kyc/operator/individual/status` → get_individual_kyc_status
- `POST   /api/kyc/owner/pmc-legal-rep-update` → pmc_legal_rep_update
- `POST   /api/kyc/owner/shared-login-disclosure` → owner_shared_login_disclosure
- `GET    /api/kyc/owner/sole-ownership-attestation` → get_sole_ownership_attestation
- `PATCH  /api/kyc/owner/sole-ownership-attestation` → record_sole_ownership_attestation

### app.api.routes.owner_death
- `GET    /api/admin/owner-death/pending` → list_pending_certificates
- `POST   /api/admin/owner-death/{cert_id}/reject` → reject_death_certificate
- `POST   /api/admin/owner-death/{cert_id}/verify` → verify_death_certificate
- `POST   /api/owner-death/report` → report_owner_death
- `POST   /api/owner-death/{cert_id}/designate-heir` → designate_heir
- `GET    /api/owner-death/{cert_id}/eligible-approvals` → list_eligible_approvals
- `POST   /api/owner-death/{cert_id}/executor-decision` → executor_decision
- `GET    /api/owner-death/{owner_user_id}` → get_death_status

### app.api.routes.sale_van_hanh
- `GET    /api/sale/van-hanh/bai-dang` → bai_dang
- `GET    /api/sale/van-hanh/bao-cao` → bao_cao
- `GET    /api/sale/van-hanh/chu-nha` → chu_nha
- `GET    /api/sale/van-hanh/don/{reservation_id}` → chi_tiet_don
- `GET    /api/sale/van-hanh/hop-dong` → hop_dong
- `GET    /api/sale/van-hanh/khach-hang` → khach_hang
- `GET    /api/sale/van-hanh/lich` → lich
- `GET    /api/sale/van-hanh/lich-xem/{appointment_id}` → chi_tiet_lich
- `POST   /api/sale/van-hanh/lich-xem/{appointment_id}/ket-qua` → ghi_ket_qua
- `GET    /api/sale/van-hanh/toa-nha` → toa_nha
- `GET    /api/sale/van-hanh/toa-nha/{building_id}` → chi_tiet_toa
- `GET    /api/sale/van-hanh/tong-quan` → tong_quan

### app.api.routes.services
- `GET    /api/services` → list_services
- `GET    /api/services/requests` → admin_list_requests
- `POST   /api/services/requests` → create_request
- `GET    /api/services/requests/mine` → my_requests
- `PATCH  /api/services/requests/{request_id}` → admin_update_request

### app.api.routes.so_chu_nha
- `GET    /api/host/so-chu-nha/mau-nhap-phong.xlsx` → mau_nhap
- `GET    /api/host/so-chu-nha/phong/{room_id}` → phong
- `PUT    /api/host/so-chu-nha/phong/{room_id}` → sua_phong
- `GET    /api/host/so-chu-nha/phong/{room_id}/dich-vu` → dich_vu
- `POST   /api/host/so-chu-nha/phong/{room_id}/dich-vu` → them_dich_vu
- `PATCH  /api/host/so-chu-nha/phong/{room_id}/dich-vu/{ma}` → sua_dich_vu
- `GET    /api/host/so-chu-nha/phong/{room_id}/dien-nuoc` → dien_nuoc
- `POST   /api/host/so-chu-nha/phong/{room_id}/dien-nuoc` → luu_chi_so
- `POST   /api/host/so-chu-nha/phong/{room_id}/hoa-don` → tao_hoa_don
- `GET    /api/host/so-chu-nha/phong/{room_id}/hop-dong` → hop_dong
- `POST   /api/host/so-chu-nha/phong/{room_id}/hop-dong/gia-han` → gia_han
- `GET    /api/host/so-chu-nha/phong/{room_id}/lich-su` → lich_su
- `PUT    /api/host/so-chu-nha/phong/{room_id}/so-nguoi` → so_nguoi
- `GET    /api/host/so-chu-nha/phong/{room_id}/thu-chi` → thu_chi
- `GET    /api/host/so-chu-nha/phong/{room_id}/thu-tien` → chi_tiet_thu
- `POST   /api/host/so-chu-nha/phong/{room_id}/thu-tien` → xac_nhan_thu
- `GET    /api/host/so-chu-nha/thu-chi` → thu_chi_tong
- `GET    /api/host/so-chu-nha/toa-nha` → toa_nha
- `GET    /api/host/so-chu-nha/toa-nha/{building_id}/form-phong` → form_phong
- `POST   /api/host/so-chu-nha/toa-nha/{building_id}/nhap-phong` → nhap_phong
- `GET    /api/host/so-chu-nha/toa-nha/{building_id}/phong` → phong_cua_toa
- `POST   /api/host/so-chu-nha/toa-nha/{building_id}/phong` → them_phong
- `PUT    /api/host/so-chu-nha/toa-nha/{building_id}/tang` → dat_tang
- `GET    /api/host/so-chu-nha/trang-chu` → trang_chu

### app.routers.activity_v2
- `GET    /api/v2/admin/activity-policy/deposits` → get_deposit_policy
- `POST   /api/v2/admin/activity-policy/deposits` → create_deposit_policy
- `GET    /api/v2/admin/sale-applications` → list_sale_applications
- `POST   /api/v2/admin/sale-applications/{application_id}/review` → review_sale_application
- `GET    /api/v2/manage/counters` → management_counters
- `GET    /api/v2/manage/summary` → management_summary
- `GET    /api/v2/manage/timeline` → management_timeline
- `GET    /api/v2/manage/work-items` → management_work_items
- `GET    /api/v2/me/capabilities` → capabilities
- `POST   /api/v2/sale-application-web-sessions` → create_sale_application_web_session
- `POST   /api/v2/sale-application-web-sessions/exchange` → exchange_sale_application_web_session
- `POST   /api/v2/sale-applications` → submit_sale_application
- `GET    /api/v2/sale-applications/me` → my_sale_applications
- `POST   /api/v2/sale-applications/web` → submit_sale_application_from_web
- `POST   /api/v2/sale-applications/{application_id}/withdraw` → withdraw_sale_application

### app.routers.admin_houses
- `GET    /api/admin/houses` → admin_list_houses
- `POST   /api/admin/houses/{house_id}/moderate` → moderate_house
- `PATCH  /api/admin/houses/{house_id}/trusted` → toggle_trusted

### app.routers.auth_router
- `POST   /api/auth/change-password` → change_password
- `POST   /api/auth/delete-account` → delete_account
- `POST   /api/auth/forgot-password` → forgot_password
- `POST   /api/auth/login` → login
- `GET    /api/auth/me` → me
- `POST   /api/auth/reauth` → reauth
- `POST   /api/auth/register` → register

### app.routers.basemap_tiles
- `GET    /api/basemap/{z}/{x}/{y}.png` → serve_basemap_tile

### app.routers.blocks
- `GET    /api/social/blocks` → list_blocks
- `DELETE /api/social/blocks/{user_id}` → unblock_user
- `POST   /api/social/blocks/{user_id}` → block_user

### app.routers.booking_availability
- `GET    /api/houses/{house_id}/availability` → get_availability
- `PUT    /api/houses/{house_id}/availability` → put_availability
- `GET    /api/houses/{house_id}/available-slots` → get_available_slots
- `GET    /api/rooms/{room_id}/available-slots` → get_room_slots

### app.routers.building_claim
- `POST   /api/buildings/claim` → nhan_ban_giao
- `GET    /api/buildings/claim/{code}` → xem_truoc

### app.routers.buildings_public
- `GET    /api/buildings/public` → du_an_cua_nguoi
- `GET    /api/buildings/{building_id}/public` → chi_tiet

### app.routers.buy_sell_v2
- `GET    /api/v2/buy-sell/transactions` → list_transactions
- `POST   /api/v2/buy-sell/transactions/from-deal/{deal_id}` → create_from_deal
- `GET    /api/v2/buy-sell/transactions/{transaction_id}` → detail
- `POST   /api/v2/buy-sell/transactions/{transaction_id}/documents` → add_document
- `POST   /api/v2/buy-sell/transactions/{transaction_id}/transition` → transition

### app.routers.catalog
- `GET    /api/amenities` → amenities
- `GET    /api/categories` → categories
- `GET    /api/category-groups` → category_groups
- `GET    /api/geo/reverse` → geo_reverse
- `GET    /api/master/provinces` → master_provinces
- `GET    /api/master/wards` → master_wards

### app.routers.chat
- `GET    /api/chats` → conversations
- `GET    /api/chats/{peer_id}/messages` → history
- `POST   /api/chats/{peer_id}/messages` → send
- `PATCH  /api/chats/{peer_id}/read` → mark_read
- `POST   /api/ws-ticket` → issue_ws_ticket

### app.routers.chu_nha_van_hanh
- `POST   /api/host/chu-nha/lich-xem/{appointment_id}/hop-dong` → tao_hop_dong
- `POST   /api/host/chu-nha/lich-xem/{appointment_id}/ket-qua` → ghi_ket_qua
- `GET    /api/host/chu-nha/phong` → phong
- `GET    /api/host/chu-nha/phong/{room_id}/lich-xem` → lich_xem_phong
- `GET    /api/host/chu-nha/tong-quan` → tong_quan
- `GET    /api/host/chu-nha/yeu-cau` → yeu_cau

### app.routers.client_logs
- `POST   /api/client-logs` → ingest_client_log

### app.routers.construction
- `GET    /api/construction/admin/contractors` → admin_list_contractors
- `GET    /api/construction/admin/contractors/legal-queue` → admin_legal_queue
- `GET    /api/construction/contractors` → list_contractors
- `POST   /api/construction/contractors` → create_contractor
- `GET    /api/construction/contractors/{contractor_id}` → contractor_detail
- `PATCH  /api/construction/contractors/{contractor_id}` → update_contractor
- `POST   /api/construction/contractors/{contractor_id}/legal-submit` → submit_legal_docs
- `POST   /api/construction/contractors/{contractor_id}/legal-verify` → verify_legal
- `POST   /api/construction/contractors/{contractor_id}/projects` → add_project
- `DELETE /api/construction/contractors/{contractor_id}/projects/{project_id}` → delete_project
- `PATCH  /api/construction/contractors/{contractor_id}/projects/{project_id}` → update_project
- `POST   /api/construction/contractors/{contractor_id}/reject` → reject_contractor
- `GET    /api/construction/contractors/{contractor_id}/reviews` → list_contractor_reviews
- `POST   /api/construction/contractors/{contractor_id}/reviews` → create_contractor_review
- `POST   /api/construction/contractors/{contractor_id}/verify` → verify_contractor
- `POST   /api/construction/contractors/{contractor_id}/verify-cert` → verify_cert
- `GET    /api/construction/designs` → design_showcase
- `GET    /api/construction/feed` → unified_feed
- `GET    /api/construction/leads` → admin_list_leads
- `POST   /api/construction/leads` → submit_rfq
- `GET    /api/construction/leads/mine` → my_leads
- `PATCH  /api/construction/leads/{lead_id}` → update_lead
- `GET    /api/construction/leads/{lead_id}/contact` → get_contact
- `GET    /api/construction/leads/{lead_id}/quotes` → list_quotes
- `POST   /api/construction/leads/{lead_id}/quotes` → create_quote
- `POST   /api/construction/leads/{lead_id}/share-contact` → share_contact
- `GET    /api/construction/my/contractor` → my_contractor
- `GET    /api/construction/my/leads-feed` → contractor_leads_feed
- `GET    /api/construction/my/quotes` → my_quotes
- `POST   /api/construction/projects/{project_id}/verify` → verify_project
- `POST   /api/construction/quotes/{quote_id}/accept` → accept_quote
- `GET    /api/construction/services` → list_services

### app.routers.content_reports
- `POST   /api/reports` → create_report
- `GET    /api/reports/queue` → report_queue
- `POST   /api/reports/{report_id}/resolve` → resolve_report
- `DELETE /api/social/posts/{post_id}/save` → unsave_post
- `POST   /api/social/posts/{post_id}/save` → save_post
- `GET    /api/social/saved-posts` → list_saved_posts

### app.routers.deals
- `POST   /api/deals` → chot
- `GET    /api/deals/inbox` → cho_xac_nhan
- `GET    /api/deals/mine` → cua_toi
- `POST   /api/deals/{deal_id}/confirm` → xac_nhan
- `POST   /api/deals/{deal_id}/confirm-customer` → xac_nhan_khach
- `POST   /api/deals/{deal_id}/reject` → tu_choi

### app.routers.dien_nuoc
- `POST   /api/guest/dien-nuoc` → nguoi_thue_gui
- `GET    /api/host/dien-nuoc` → bang_thang
- `GET    /api/host/dien-nuoc/phong` → chi_tiet_phong
- `POST   /api/host/dien-nuoc/phong/{room_id}/chup` → chu_nha_chup
- `POST   /api/host/dien-nuoc/{reading_id}/chup-lai` → chup_lai
- `POST   /api/host/dien-nuoc/{reading_id}/duyet` → duyet

### app.routers.guest_da_dat
- `GET    /api/guest/da-dat` → da_dat_cua_toi

### app.routers.guest_dang_thue
- `GET    /api/guest/dang-thue` → dang_thue
- `GET    /api/guest/dang-thue/{contract_id}/ho-so` → ho_so_khach
- `POST   /api/guest/dang-thue/{contract_id}/su-co` → bao_su_co

### app.routers.guest_hoat_dong
- `GET    /api/guest/don-thue` → don_thue
- `GET    /api/guest/don-thue/{nguon}/{don_id}` → don_thue_chi_tiet
- `GET    /api/guest/hoat-dong` → hoat_dong

### app.routers.guest_reservation
- `GET    /api/guest/reservations` → list_my_reservations
- `POST   /api/guest/reservations` → create_my_reservation
- `PATCH  /api/guest/reservations/{reservation_id}` → sua_don_cua_toi
- `POST   /api/guest/reservations/{reservation_id}/cancel` → cancel_my_reservation
- `POST   /api/guest/reservations/{reservation_id}/doi-gio` → doi_gio_don
- `POST   /api/guest/reservations/{reservation_id}/doi-gio/bao-gia` → bao_gia_doi_gio
- `GET    /api/guest/reservations/{reservation_id}/lich-su` → lich_su_don
- `GET    /api/guest/reservations/{reservation_id}/phieu` → phieu_dat_phong_cua_toi

### app.routers.host_analytics
- `GET    /api/host/analytics/drill-down` → get_drill_down
- `GET    /api/host/analytics/occupancy-heatmap` → get_occupancy_heatmap
- `GET    /api/host/analytics/revenue-trend` → get_revenue_trend
- `GET    /api/host/analytics/source-breakdown` → get_source_breakdown
- `GET    /api/host/analytics/summary` → get_summary

### app.routers.host_building
- `GET    /api/host/buildings` → list_buildings
- `POST   /api/host/buildings` → create_building
- `DELETE /api/host/buildings/{building_id}` → delete_building
- `PATCH  /api/host/buildings/{building_id}` → update_building
- `POST   /api/host/buildings/{building_id}/gan-tin` → gan_tin_vao_du_an

### app.routers.host_ca_thue
- `GET    /api/host/ca-thue/{res_id}` → chi_tiet
- `POST   /api/host/ca-thue/{res_id}/gia-han` → gia_han
- `POST   /api/host/ca-thue/{res_id}/nhan-phong` → nhan_phong
- `POST   /api/host/ca-thue/{res_id}/phu-thu` → them_phu_thu
- `DELETE /api/host/ca-thue/{res_id}/phu-thu/{phu_thu_id}` → xoa_phu_thu
- `POST   /api/host/ca-thue/{res_id}/thanh-toan` → ghi_thanh_toan
- `POST   /api/host/ca-thue/{res_id}/tra-phong` → tra_phong

### app.routers.host_cho_thue_ngoai
- `DELETE /api/host/rooms/{room_id}/cho-thue-ngoai` → bo_danh_dau
- `POST   /api/host/rooms/{room_id}/cho-thue-ngoai` → danh_dau

### app.routers.host_contract
- `GET    /api/host/contracts` → list_contracts
- `POST   /api/host/contracts` → create_contract_endpoint
- `POST   /api/host/contracts/batch-renew` → batch_renew_endpoint
- `GET    /api/host/contracts/{contract_id}` → get_contract
- `PATCH  /api/host/contracts/{contract_id}/activate` → activate_contract_endpoint
- `PATCH  /api/host/contracts/{contract_id}/terminate` → terminate_contract_endpoint
- `PATCH  /api/host/contracts/{contract_id}/transfer-room` → transfer_room_endpoint

### app.routers.host_dashboard
- `GET    /api/host/dashboard/action-items` → action_items
- `POST   /api/host/dashboard/invoices/{invoice_id}/zalo-reminder` → build_invoice_zalo_reminder

### app.routers.host_export
- `POST   /api/host/analytics/export/tt200` → export_tt200

### app.routers.host_ho_so_phong
- `POST   /api/host/contracts/{contract_id}/hoa-don-thang-nay` → hoa_don_thang_nay
- `PATCH  /api/host/contracts/{contract_id}/thanh-toan` → cap_nhat_thanh_toan
- `GET    /api/host/rooms/{room_id}/ho-so` → ho_so_phong
- `POST   /api/host/rooms/{room_id}/sua-chua` → ghi_sua_chua
- `POST   /api/host/rooms/{room_id}/tai-san` → them_tai_san
- `DELETE /api/host/sua-chua/{muc_id}` → xoa_muc_sua_chua
- `PATCH  /api/host/sua-chua/{muc_id}` → sua_muc_sua_chua
- `DELETE /api/host/tai-san/{muc_id}` → xoa_tai_san
- `PATCH  /api/host/tai-san/{muc_id}` → sua_tai_san

### app.routers.host_hoa_don_thang
- `POST   /api/host/hoa-don/chot` → chot
- `POST   /api/host/hoa-don/xem-truoc` → xem_truoc

### app.routers.host_homestay
- `GET    /api/host/homestay/availability` → list_availability
- `POST   /api/host/homestay/availability/block` → block_availability
- `GET    /api/host/homestay/pricing-rules` → list_pricing_rules
- `POST   /api/host/homestay/pricing-rules` → create_pricing_rule
- `DELETE /api/host/homestay/pricing-rules/{rule_id}` → delete_pricing_rule
- `PATCH  /api/host/homestay/pricing-rules/{rule_id}` → update_pricing_rule
- `GET    /api/host/homestay/reservations` → list_reservations
- `POST   /api/host/homestay/reservations` → create_reservation
- `GET    /api/host/homestay/reservations/{reservation_id}` → get_reservation
- `POST   /api/host/homestay/reservations/{reservation_id}/cancel` → cancel_reservation
- `PATCH  /api/host/homestay/reservations/{reservation_id}/check-in` → check_in_reservation
- `PATCH  /api/host/homestay/reservations/{reservation_id}/check-out` → check_out_reservation
- `PATCH  /api/host/homestay/reservations/{reservation_id}/status` → change_status
- `GET    /api/host/homestay/rooms/{room_id}/calendar` → room_calendar
- `GET    /api/host/homestay/unified-calendar` → unified_calendar

### app.routers.host_invoice
- `GET    /api/host/invoices` → list_invoices
- `GET    /api/host/invoices/debt-aging` → debt_aging
- `POST   /api/host/invoices/generate-batch` → generate_batch
- `GET    /api/host/invoices/needs-reminder` → needs_reminder
- `GET    /api/host/invoices/{invoice_id}` → get_invoice
- `POST   /api/host/invoices/{invoice_id}/credit-note` → create_credit_note
- `PATCH  /api/host/invoices/{invoice_id}/pay` → pay_invoice
- `PATCH  /api/host/invoices/{invoice_id}/send` → send_invoice
- `GET    /api/host/invoices/{invoice_id}/zalo-link` → zalo_link

### app.routers.host_kenh
- `GET    /api/host/rooms/{room_id}/kenh` → danh_sach
- `PUT    /api/host/rooms/{room_id}/kenh/{kenh}` → dat_kenh
- `POST   /api/host/rooms/{room_id}/kenh/{kenh}/rao-lai` → rao_lai
- `POST   /api/host/rooms/{room_id}/kenh/{kenh}/trang-thai` → doi_trang_thai

### app.routers.host_khai_bao
- `GET    /api/host/khai-bao` → list_khai_bao
- `POST   /api/host/khai-bao` → create_khai_bao
- `GET    /api/host/khai-bao/dashboard-summary` → dashboard_summary
- `GET    /api/host/khai-bao/{record_id}` → get_khai_bao
- `PATCH  /api/host/khai-bao/{record_id}/declared` → mark_declared
- `PATCH  /api/host/khai-bao/{record_id}/skipped` → mark_skipped

### app.routers.host_leads
- `GET    /api/host/leads` → host_leads

### app.routers.host_lich_phong
- `GET    /api/host/buildings/{building_id}/lich-phong` → lich_toa
- `DELETE /api/host/chan/{khoang_id}` → bo_chan
- `POST   /api/host/rooms/{room_id}/chan` → chan_phong

### app.routers.host_loai_phong
- `GET    /api/host/buildings/{building_id}/loai-phong` → danh_sach
- `POST   /api/host/buildings/{building_id}/loai-phong` → tao
- `DELETE /api/host/loai-phong/{loai_id}` → xoa
- `PATCH  /api/host/loai-phong/{loai_id}` → sua
- `POST   /api/host/loai-phong/{loai_id}/ca-thue` → ca_theo_loai
- `POST   /api/host/loai-phong/{loai_id}/phong` → gan_phong
- `GET    /api/host/toa-va-hang` → toa_va_hang

### app.routers.host_meter_reading
- `GET    /api/host/meter-readings` → list_meter_readings
- `POST   /api/host/meter-readings` → create_meter_reading
- `POST   /api/host/meter-readings/batch` → create_batch

### app.routers.host_ngan_han
- `GET    /api/host/buildings/{building_id}/lich-ngan-han` → lich_ngay
- `GET    /api/host/buildings/{building_id}/lich-tuan` → lich_tuan
- `POST   /api/host/rooms/{room_id}/ca-thue` → them_ca
- `GET    /api/host/rooms/{room_id}/ho-so-ngan-han` → ho_so
- `GET    /api/host/rooms/{room_id}/lich-gio` → lich_gio_nhieu_ngay

### app.routers.host_profile
- `GET    /api/host/cccd/{profile_id}` → serve_cccd
- `GET    /api/host/profile` → get_host_profile
- `PATCH  /api/host/profile` → update_host_profile
- `POST   /api/host/profile/cccd` → upload_cccd
- `POST   /api/host/upgrade-to-host` → upgrade_to_host

### app.routers.host_quan_ly_dai_han
- `GET    /api/host/buildings/{building_id}/doanh-thu` → xem_doanh_thu
- `GET    /api/host/buildings/{building_id}/hoa-don` → xem_hoa_don
- `POST   /api/host/buildings/{building_id}/hoa-don/tao-thang` → tao_hoa_don_thang
- `GET    /api/host/buildings/{building_id}/hop-dong` → xem_hop_dong
- `GET    /api/host/buildings/{building_id}/khach-hang` → xem_khach_hang

### app.routers.host_report
- `GET    /api/host/reports/adr` → adr
- `GET    /api/host/reports/export` → export_invoices_csv
- `GET    /api/host/reports/occupancy` → occupancy
- `GET    /api/host/reports/revenue` → revenue

### app.routers.host_room
- `GET    /api/host/buildings/{building_id}/rooms` → list_rooms
- `POST   /api/host/buildings/{building_id}/rooms` → create_room
- `DELETE /api/host/rooms/{room_id}` → xoa_phong
- `PATCH  /api/host/rooms/{room_id}` → update_room
- `POST   /api/host/rooms/{room_id}/duplicate` → duplicate_room
- `POST   /api/host/rooms/{room_id}/maintenance` → set_room_maintenance
- `POST   /api/host/rooms/{room_id}/maintenance/end` → end_room_maintenance

### app.routers.host_service_fee
- `POST   /api/host/contracts/{contract_id}/service-fees` → attach_service_to_contract
- `DELETE /api/host/contracts/{contract_id}/service-fees/{fee_id}` → detach_service_from_contract
- `GET    /api/host/service-fees` → list_service_fees
- `POST   /api/host/service-fees` → create_service_fee
- `PATCH  /api/host/service-fees/{fee_id}` → update_service_fee

### app.routers.host_sources
- `GET    /api/host/sources/` → list_sources
- `POST   /api/host/sources/` → create_source
- `DELETE /api/host/sources/{source_id}` → delete_source
- `PATCH  /api/host/sources/{source_id}` → update_source

### app.routers.host_tenant
- `GET    /api/host/tenants` → list_tenants
- `POST   /api/host/tenants` → create_tenant
- `GET    /api/host/tenants/{tenant_id}` → get_tenant
- `PATCH  /api/host/tenants/{tenant_id}` → update_tenant

### app.routers.host_tong_quan
- `GET    /api/host/tong-quan` → tong_quan

### app.routers.hosts_public
- `GET    /api/hosts/featured` → featured_hosts
- `GET    /api/hosts/sales` → public_sales
- `GET    /api/hosts/{user_id}` → host_public_profile
- `GET    /api/hosts/{user_id}/reviews` → host_reviews

### app.routers.houses
- `GET    /api/houses` → list_houses
- `POST   /api/houses` → create_house
- `GET    /api/houses/search-nearby` → search_houses_near_place
- `DELETE /api/houses/{house_id}` → delete_house
- `GET    /api/houses/{house_id}` → get_house
- `PUT    /api/houses/{house_id}` → update_house
- `POST   /api/houses/{house_id}/close-unit` → close_unit

### app.routers.houses_social
- `GET    /api/houses/{house_id}/comments` → danh_sach_binh_luan
- `POST   /api/houses/{house_id}/comments` → viet_binh_luan
- `DELETE /api/houses/{house_id}/comments/{comment_id}` → xoa_binh_luan
- `POST   /api/houses/{house_id}/like` → bat_tat_tim
- `POST   /api/houses/{house_id}/pin` → ghim
- `GET    /api/houses/{house_id}/thong-ke` → thong_ke
- `POST   /api/houses/{house_id}/visibility` → doi_hien_thi

### app.routers.leads
- `GET    /api/admin/leads` → list_leads
- `POST   /api/leads` → create_lead

### app.routers.marketplace_integration
- `POST   /api/host/marketplace/contracts/from-appointment/{appointment_id}` → create_contract_from_appointment
- `POST   /api/host/marketplace/reservations/{reservation_id}/approve-from-booking` → approve_reservation_from_booking
- `POST   /api/host/marketplace/rooms/{room_id}/publish` → publish_room
- `POST   /api/host/marketplace/rooms/{room_id}/unpublish` → unpublish_room
- `GET    /api/host/marketplace/sync-status` → sync_status

### app.routers.moi_sale
- `POST   /api/buildings/moi-sale` → nhan_moi
- `GET    /api/buildings/moi-sale/{code}` → xem_truoc
- `GET    /api/host/buildings/{building_id}/ma-ban-giao` → xem_ma_ban_giao
- `POST   /api/host/buildings/{building_id}/ma-ban-giao` → doi_ma_ban_giao
- `DELETE /api/host/buildings/{building_id}/ma-moi-sale` → thu_hoi_ma
- `POST   /api/host/buildings/{building_id}/ma-moi-sale` → sinh_ma_moi

### app.routers.money_ledger_v2
- `GET    /api/v2/money-ledger/legacy-adapter` → legacy_adapter
- `GET    /api/v2/money-ledger/payments` → payments
- `POST   /api/v2/money-ledger/payments` → record_payment
- `POST   /api/v2/money-ledger/payments/{payment_id}/refunds` → record_refund
- `GET    /api/v2/money-ledger/reconciliation` → reconciliation

### app.routers.notifications
- `GET    /api/notifications` → list_notifications
- `PATCH  /api/notifications/read-all` → mark_all_read
- `PATCH  /api/notifications/{notif_id}/read` → mark_read

### app.routers.planning
- `GET    /api/planning/admin/etl-runs` → admin_etl_runs
- `POST   /api/planning/admin/etl-trigger` → admin_etl_trigger
- `GET    /api/planning/admin/provinces` → admin_list_provinces
- `POST   /api/planning/admin/provinces/{slug}` → admin_toggle_province
- `GET    /api/planning/admin/risky-listings` → admin_risky_listings
- `GET    /api/planning/districts` → get_districts
- `GET    /api/planning/layers` → get_layers
- `GET    /api/planning/parcels` → get_parcel_by_point
- `GET    /api/planning/parcels/bbox` → get_parcels_in_bbox
- `GET    /api/planning/parcels/{parcel_id}` → get_parcel_by_id
- `GET    /api/planning/provinces` → get_provinces
- `GET    /api/planning/provinces/search` → search_provinces
- `POST   /api/planning/report-error` → report_error
- `GET    /api/planning/search` → search_address

### app.routers.planning_tiles
- `GET    /planning-tiles/v2/{slug}/{z}/{x}/{y}.png` → serve_tile_v2
- `GET    /planning-tiles/{slug}/{z}/{x}/{y}.png` → serve_tile

### app.routers.preferences
- `GET    /api/me/preferences` → get_preferences
- `PUT    /api/me/preferences` → put_preferences

### app.routers.public_invoice
- `GET    /public/invoices/{token}` → render_public_invoice

### app.routers.public_khai_bao
- `GET    /public/khai-bao/{token}` → render_public_khai_bao

### app.routers.quality_rating
- `GET    /api/houses/{house_id}/quality` → get_quality
- `PUT    /api/houses/{house_id}/quality` → set_quality

### app.routers.quan_ly
- `GET    /api/quan-ly` → quan_ly

### app.routers.reels
- `GET    /api/reels` → list_reels
- `POST   /api/reels` → create_reel
- `GET    /api/reels/analytics/summary` → reel_analytics
- `DELETE /api/reels/comments/{comment_id}` → delete_reel_comment
- `GET    /api/reels/mine` → my_reels
- `GET    /api/reels/moderation/queue` → moderation_queue
- `POST   /api/reels/upload` → upload_reel_video
- `DELETE /api/reels/{reel_id}` → delete_reel
- `GET    /api/reels/{reel_id}/comments` → list_reel_comments
- `POST   /api/reels/{reel_id}/comments` → create_reel_comment
- `POST   /api/reels/{reel_id}/like` → toggle_like
- `POST   /api/reels/{reel_id}/moderate` → moderate_reel
- `POST   /api/reels/{reel_id}/report` → report_reel
- `POST   /api/reels/{reel_id}/view` → add_view

### app.routers.rental_journeys
- `GET    /api/rental-journeys` → list_rental_journeys
- `POST   /api/rental-journeys/from-appointment/{appointment_id}/viewing-result` → submit_viewing_result
- `GET    /api/rental-journeys/payment-account` → get_payment_account
- `GET    /api/rental-journeys/{journey_id}` → get_rental_journey
- `POST   /api/rental-journeys/{journey_id}/cancel` → cancel_rental_journey
- `POST   /api/rental-journeys/{journey_id}/confirm` → confirm_rental
- `GET    /api/rental-journeys/{journey_id}/contact-access` → get_rental_journey_contact_access
- `PUT    /api/rental-journeys/{journey_id}/contract` → put_contract
- `GET    /api/rental-journeys/{journey_id}/events` → list_events
- `POST   /api/rental-journeys/{journey_id}/payments/OWNER_DEPOSIT/acknowledge` → acknowledge_owner_deposit
- `PUT    /api/rental-journeys/{journey_id}/payments/{kind}/proof` → put_payment_proof
- `POST   /api/rental-journeys/{journey_id}/reports` → report_participant

### app.routers.reviews
- `POST   /api/guest-reviews` → review_guest
- `GET    /api/houses/{house_id}/reviews` → list_reviews
- `POST   /api/reviews` → create_review
- `GET    /api/users/{user_id}/trust` → user_trust

### app.routers.sale_crm_v2
- `GET    /api/v2/sale-crm/commission-summary` → commission_summary
- `GET    /api/v2/sale-crm/contacts` → contacts
- `GET    /api/v2/sale-crm/contacts/{contact_id}` → contact_detail
- `GET    /api/v2/sale-crm/contacts/{contact_id}/notes` → notes
- `POST   /api/v2/sale-crm/contacts/{contact_id}/notes` → create_note
- `GET    /api/v2/sale-crm/dashboard` → dashboard
- `GET    /api/v2/sale-crm/deals` → deals
- `PATCH  /api/v2/sale-crm/deals/{deal_id}/stage` → update_deal_stage
- `GET    /api/v2/sale-crm/properties` → properties
- `GET    /api/v2/sale-crm/stay-support` → stay_support
- `GET    /api/v2/sale-crm/tasks` → tasks
- `POST   /api/v2/sale-crm/tasks` → create_task
- `PATCH  /api/v2/sale-crm/tasks/{task_id}` → update_task

### app.routers.sale_lien_he
- `GET    /api/sales/me/lien-he` → xem_lien_he
- `PATCH  /api/sales/me/lien-he` → sua_lien_he

### app.routers.sale_links
- `POST   /api/owner-links` → lien_ket
- `GET    /api/owner-links/me` → lien_ket_cua_toi
- `POST   /api/owner-links/resolve-code` → tra_ma
- `POST   /api/owner-links/{link_id}/end` → ngat
- `POST   /api/owner-links/{link_id}/transfer` → chuyen
- `GET    /api/sales/me/code` → ma_cua_toi
- `POST   /api/sales/me/code/regenerate` → doi_ma
- `GET    /api/sales/me/owners` → chu_phong_cua_toi

### app.routers.sale_yeu_cau
- `PATCH  /api/sale/cai-dat` → cai_dat
- `GET    /api/sale/khach` → khach_hang
- `POST   /api/sale/khach` → them_khach
- `GET    /api/sale/toa-doanh-thu` → toa_doanh_thu
- `GET    /api/sale/tong-quan` → tong_quan
- `GET    /api/sale/yeu-cau` → danh_sach_yeu_cau
- `POST   /api/sale/yeu-cau` → tao_yeu_cau
- `GET    /api/sale/yeu-cau/{yeu_cau_id}` → chi_tiet_yeu_cau
- `POST   /api/sale/yeu-cau/{yeu_cau_id}/can` → gan_can
- `POST   /api/sale/yeu-cau/{yeu_cau_id}/can/{can_id}/chon` → chon_can
- `POST   /api/sale/yeu-cau/{yeu_cau_id}/chuyen-buoc` → chuyen_buoc
- `GET    /api/sale/yeu-cau/{yeu_cau_id}/nguon-can` → nguon_can

### app.routers.search
- `GET    /api/search` → unified_search

### app.routers.seo
- `GET    /privacy` → privacy_policy
- `GET    /robots.txt` → robots
- `GET    /sitemap.xml` → sitemap
- `GET    /support` → support_page
- `GET    /tin` → danh_muc_tin
- `GET    /tin/{slug}` → trang_tin

### app.routers.short_inventory_v2
- `GET    /api/v2/short-stay/quote` → quote
- `GET    /api/v2/short-stay/requests` → requests
- `POST   /api/v2/short-stay/requests` → create_request
- `GET    /api/v2/short-stay/requests/{request_id}` → request_detail
- `POST   /api/v2/short-stay/requests/{request_id}/assign` → assign
- `POST   /api/v2/short-stay/requests/{request_id}/transition` → transition

### app.routers.short_stays
- `GET    /api/host/short-stays/reservations` → reservations
- `POST   /api/host/short-stays/reservations/{reservation_id}/actions` → action
- `GET    /api/host/short-stays/rooms` → managed_rooms
- `GET    /api/host/short-stays/rooms/{room_id}/blocks` → blocks
- `POST   /api/host/short-stays/rooms/{room_id}/blocks` → block
- `DELETE /api/host/short-stays/rooms/{room_id}/blocks/{block_id}` → unblock
- `PUT    /api/host/short-stays/rooms/{room_id}/rates` → set_rates
- `POST   /api/short-stays/quote` → quote
- `GET    /api/short-stays/rooms` → search_rooms
- `GET    /api/short-stays/rooms/{room_id}` → room_detail
- `GET    /api/short-stays/rooms/{room_id}/lich-ban` → lich_ban_phong
- `GET    /api/short-stays/rooms/{room_id}/thong-tin-dat` → thong_tin_dat_phong
- `POST   /api/short-stays/tin/{house_id}/dat` → dat_theo_tin
- `GET    /api/short-stays/tin/{house_id}/lich-ban` → lich_ban_theo_tin
- `POST   /api/short-stays/tin/{house_id}/quote` → quote_theo_tin
- `GET    /api/short-stays/tin/{house_id}/thong-tin-dat` → thong_tin_dat_theo_tin

### app.routers.social
- `DELETE /api/social/comments/{comment_id}` → delete_comment
- `GET    /api/social/feed` → get_feed
- `POST   /api/social/posts` → create_post
- `DELETE /api/social/posts/{post_id}` → delete_post
- `GET    /api/social/posts/{post_id}` → get_post
- `PATCH  /api/social/posts/{post_id}` → edit_post
- `GET    /api/social/posts/{post_id}/comments` → list_comments
- `POST   /api/social/posts/{post_id}/comments` → create_comment
- `POST   /api/social/posts/{post_id}/like` → toggle_like

### app.routers.stays_v2
- `GET    /api/v2/stays` → list_stays
- `GET    /api/v2/stays/{contract_id}` → detail
- `GET    /api/v2/stays/{contract_id}/change-requests` → change_list
- `POST   /api/v2/stays/{contract_id}/change-requests` → change_create
- `POST   /api/v2/stays/{contract_id}/change-requests/{request_id}/review` → change_review
- `GET    /api/v2/stays/{contract_id}/invoices` → invoices
- `GET    /api/v2/stays/{contract_id}/invoices/{invoice_id}` → invoice_detail
- `GET    /api/v2/stays/{contract_id}/meters` → meters
- `GET    /api/v2/stays/{contract_id}/support` → support_list
- `POST   /api/v2/stays/{contract_id}/support` → support_create
- `GET    /api/v2/stays/{contract_id}/support/{case_id}` → support_detail
- `PATCH  /api/v2/stays/{contract_id}/support/{case_id}` → support_update

### app.routers.tools
- `GET    /api/tools/compare` → compare_houses
- `POST   /api/tools/loan-calculator` → loan_calculator

### app.routers.upload
- `POST   /api/upload` → upload

### app.routers.users
- `GET    /api/users` → list_users
- `DELETE /api/users/me/push-token` → unregister_push_token
- `POST   /api/users/me/push-token` → register_push_token
- `PATCH  /api/users/{user_id}` → update_user

### app.routers.verification
- `POST   /api/houses/{house_id}/verification` → request_verification
- `GET    /api/verification/queue` → verification_queue
- `POST   /api/verification/{req_id}/complete` → complete_verification
- `POST   /api/verification/{req_id}/reject` → reject_verification

### app.routers.viewing_appointments
- `GET    /api/viewing-appointments` → list_viewing_appointments
- `POST   /api/viewing-appointments` → create_viewing_appointment
- `GET    /api/viewing-appointments/thong-tin-dat` → thong_tin_dat_lich
- `GET    /api/viewing-appointments/work-queue` → viewing_work_queue
- `POST   /api/viewing-appointments/{appointment_id}/chon-gio` → khach_chon_gio_moi
- `POST   /api/viewing-appointments/{appointment_id}/doi-gio` → xin_doi_gio
- `GET    /api/viewing-appointments/{appointment_id}/gio-trong` → gio_trong_de_doi
- `POST   /api/viewing-appointments/{appointment_id}/hen-chot` → hen_gap_chot
- `PATCH  /api/viewing-appointments/{appointment_id}/khach` → khach_sua_lich
- `POST   /api/viewing-appointments/{appointment_id}/khach-doi-lich` → khach_doi_lich
- `GET    /api/viewing-appointments/{appointment_id}/lich-su` → lich_su_lich_hen
- `GET    /api/viewing-appointments/{appointment_id}/phieu` → xem_phieu_hen
- `PATCH  /api/viewing-appointments/{appointment_id}/status` → update_status

### app.routers.viewings_v2
- `GET    /api/v2/viewings` → list_viewings
- `GET    /api/v2/viewings/{appointment_id}` → get_viewing
- `POST   /api/v2/viewings/{appointment_id}/accept-proposal/{proposal_id}` → accept_proposal
- `POST   /api/v2/viewings/{appointment_id}/cancel` → cancel
- `POST   /api/v2/viewings/{appointment_id}/confirm` → confirm
- `POST   /api/v2/viewings/{appointment_id}/issues` → report_issue
- `POST   /api/v2/viewings/{appointment_id}/proposals` → create_proposal
- `POST   /api/v2/viewings/{appointment_id}/rent-now` → rent_now
- `POST   /api/v2/viewings/{appointment_id}/result` → result
- `GET    /api/v2/viewings/{appointment_id}/timeline` → get_timeline

### app.routers.wishlists
- `DELETE /api/wishlists` → remove
- `GET    /api/wishlists` → list_wishlist
- `POST   /api/wishlists` → add

### fastapi.applications
- `GET    /docs` → swagger_ui_html
- `GET    /docs/oauth2-redirect` → swagger_ui_redirect
- `GET    /openapi.json` → openapi
- `GET    /redoc` → redoc_html

### main
- `GET    /api/health` → api_health
- `GET    /health` → health
- `GET    /healthz` → health

## Models (class → table → module)
- `ActivityAuditEvent` → `activity_audit_events` (app.models.sale)
- `ActivityPolicyVersion` → `activity_policy_versions` (app.models.sale)
- `AdminActionLog` → `admin_action_logs` (app.models.admin)
- `AdminCase` → `admin_cases` (app.models.admin)
- `AdminCaseEvent` → `admin_case_events` (app.models.admin)
- `AdminChangeRequest` → `admin_change_requests` (app.models.admin)
- `AdminEvent` → `admin_events` (app.models.admin)
- `AdminPermission` → `admin_permissions` (app.models.admin)
- `AdminRole` → `admin_roles` (app.models.admin)
- `AdminRolePermission` → `admin_role_permissions` (app.models.admin)
- `AdminSession` → `admin_sessions` (app.models.admin)
- `AdminUserRole` → `admin_user_roles` (app.models.admin)
- `Amenity` → `amenities` (app.models.core)
- `AuditLog` → `audit_logs` (app.models.audit)
- `Availability` → `availability` (app.models.homestay)
- `Building` → `buildings` (app.models.rental)
- `CCCDAccessLog` → `cccd_access_logs` (app.models.host)
- `Category` → `categories` (app.models.core)
- `ChangeLog` → `change_logs` (app.models.host)
- `ChatMessage` → `chat_messages` (app.models.messaging)
- `CommissionPayout` → `commission_payouts` (app.models.money)
- `ConstructionLead` → `construction_leads` (app.models.construction)
- `ConstructionService` → `construction_services` (app.models.construction)
- `ContactLead` → `contact_leads` (app.models.lead)
- `ContactRevealLog` → `contact_reveal_logs` (app.models.construction)
- `ContentReport` → `content_reports` (app.models.listing)
- `Contract` → `contracts` (app.models.rental)
- `ContractServiceFee` → `contract_service_fees` (app.models.rental)
- `ContractTenant` → `contract_tenants` (app.models.rental)
- `Contractor` → `contractors` (app.models.construction)
- `ContractorProject` → `contractor_projects` (app.models.construction)
- `ContractorReview` → `contractor_reviews` (app.models.construction)
- `CreditNote` → `credit_notes` (app.models.billing)
- `Deal` → `deals` (app.models.sale)
- `GuestReview` → `guest_reviews` (app.models.construction)
- `HostProfile` → `host_profiles` (app.models.host)
- `House` → `houses` (app.models.listing)
- `HouseViewDay` → `house_view_days` (app.models.listing)
- `Invoice` → `invoices` (app.models.billing)
- `InvoiceLineItem` → `invoice_line_items` (app.models.billing)
- `JpAddress` → `jp_addresses` (app.domain.jp.address)
- `JpRentalTerms` → `jp_rental_terms` (app.domain.jp.rental_terms)  [Phase 01]
- `JpPropertyInfo` → `jp_property_info` (app.domain.jp.property_info)  [Phase 01]
- `TrainLine` → `jp_train_lines` (app.domain.jp.transit)  [Phase 01]
- `Station` → `jp_stations` (app.domain.jp.transit)  [Phase 01]
- `TransitAccess` → `jp_transit_access` (app.domain.jp.transit)  [Phase 01]
- `JpViewing` → `jp_viewings` (app.domain.jp.viewing)  [Phase 01]
- `JpTenantApplication` → `jp_tenant_applications` (app.domain.jp.application)  [Phase 01]
- `JpApplicationReview` → `jp_application_reviews` (app.domain.jp.application)  [Phase 01]
- `ListingSalesAssignment` → `listing_sales_assignments` (app.domain.jp.sales_assignment)  [Phase 01]
- `KhaiBaoTamTru` → `khai_bao_tam_tru` (app.models.khai_bao)
- `LeadContractor` → `lead_contractors` (app.models.construction)
- `LoaiPhong` → `loai_phong` (app.models.rental)
- `MediaJob` → `media_jobs` (app.models.reels)
- `MeterReading` → `meter_readings` (app.models.rental)
- `MoneyRefund` → `money_refunds` (app.models.money)
- `Notification` → `notifications` (app.models.messaging)
- `OwnerSettlement` → `owner_settlements` (app.models.money)
- `Payment` → `payments` (app.models.billing)
- `PaymentAllocation` → `payment_allocations` (app.models.money)
- `PlanningHiddenProvince` → `planning_hidden_provinces` (app.models.planning_setting)
- `PlatformPayment` → `platform_payments` (app.models.money)
- `PricingRule` → `pricing_rules` (app.models.homestay)
- `PrivateDocument` → `private_documents` (app.models.admin)
- `PushOutbox` → `push_outbox` (app.models.messaging)
- `Quote` → `quotes` (app.models.construction)
- `Reel` → `reels` (app.models.reels)
- `ReelLike` → `reel_likes` (app.models.reels)
- `ReelReport` → `reel_reports` (app.models.reels)
- `ReelView` → `reel_views` (app.models.reels)
- `RentalJourney` → `rental_journeys` (app.models.sale)
- `RentalJourneyEvent` → `rental_journey_events` (app.models.sale)
- `RentalJourneyPayment` → `rental_journey_payments` (app.models.sale)
- `RentalJourneyReport` → `rental_journey_reports` (app.models.sale)
- `Reservation` → `reservations` (app.models.homestay)
- `ReservationPhuThu` → `reservation_phu_thu` (app.models.homestay)
- `ReservationThanhToan` → `reservation_thanh_toan` (app.models.homestay)
- `RevenueSource` → `revenue_sources` (app.models.host)
- `Review` → `reviews` (app.models.listing)
- `Room` → `rooms` (app.models.rental)
- `RoomChiemDung` → `room_chiem_dung` (app.models.rental)
- `RoomKenh` → `room_kenh` (app.models.rental)
- `RoomSuaChua` → `room_sua_chua` (app.models.rental)
- `RoomTaiSan` → `room_tai_san` (app.models.rental)
- `RoomTypeBookingRequest` → `room_type_booking_requests` (app.models.short_inventory)
- `RoomTypeInventory` → `room_type_inventory` (app.models.short_inventory)
- `SaleApplication` → `sale_applications` (app.models.sale)
- `SaleApplicationWebSession` → `sale_application_web_sessions` (app.models.sale)
- `SaleCommission` → `sale_commissions` (app.models.money)
- `SaleCrmActivity` → `sale_crm_activities` (app.models.crm)
- `SaleCrmContact` → `sale_crm_contacts` (app.models.crm)
- `SaleCrmNote` → `sale_crm_notes` (app.models.crm)
- `SaleCrmTask` → `sale_crm_tasks` (app.models.crm)
- `SaleKhach` → `sale_khach` (app.models.sale)
- `SaleOwnerLink` → `sale_owner_links` (app.models.sale)
- `SaleProfile` → `sale_profiles` (app.models.sale)
- `SaleTransaction` → `sale_transactions` (app.models.buy_sell)
- `SaleTransactionDocument` → `sale_transaction_documents` (app.models.buy_sell)
- `SaleTransactionEvent` → `sale_transaction_events` (app.models.buy_sell)
- `SaleYeuCau` → `sale_yeu_cau` (app.models.sale)
- `SaleYeuCauCan` → `sale_yeu_cau_can` (app.models.sale)
- `SaleYeuCauMoc` → `sale_yeu_cau_moc` (app.models.sale)
- `SavedPost` → `saved_posts` (app.models.listing)
- `ServiceFee` → `service_fees` (app.models.rental)
- `ShortStayRatePlan` → `short_stay_rate_plans` (app.models.short_inventory)
- `ShortStayWorkflowEvent` → `short_stay_workflow_events` (app.models.short_inventory)
- `SocialComment` → `social_comments` (app.models.social)
- `SocialPost` → `social_posts` (app.models.social)
- `SocialPostLike` → `social_post_likes` (app.models.social)
- `StayChangeRequest` → `stay_change_requests` (app.models.stay)
- `StaySupportCase` → `stay_support_cases` (app.models.stay)
- `StaySupportEvent` → `stay_support_events` (app.models.stay)
- `Tenant` → `tenants` (app.models.rental)
- `Tt200Export` → `tt200_exports` (app.models.audit)
- `User` → `users` (app.models.core)
- `UserBlock` → `user_blocks` (app.models.moderation)
- `UserPreferences` → `user_preferences` (app.models.preferences)
- `UserPushToken` → `user_push_tokens` (app.models.messaging)
- `VerificationRequest` → `verification_requests` (app.models.audit)
- `ViewingAppointment` → `viewing_appointments` (app.models.listing)
- `ViewingEvent` → `viewing_events` (app.models.viewing)
- `ViewingIssue` → `viewing_issues` (app.models.viewing)
- `ViewingProposal` → `viewing_proposals` (app.models.viewing)
- `ViewingResult` → `viewing_results` (app.models.viewing)
- `Wishlist` → `wishlists` (app.models.listing)

## JP Phase 02 — Transactions Backend (261016-2323)

### New Models (app/domain/jp/)
- `OrgProviderConfig` → `org_provider_configs` (app.domain.jp.provider_config) — per-org encrypted provider credentials
- `JpInvoiceLine` → `jp_invoice_lines` (app.domain.jp.invoice_line) — multi-line JP invoice with 消費税 treatment
- `JpPaymentIntent` → `jp_payment_intents` (app.domain.jp.payment_intent) — payment request tracking (Komoju)
- `JpWebhookEvent` → `jp_webhook_events` (app.domain.jp.webhook_event) — webhook audit log with idempotency
- `JpUserConsent` → `jp_user_consents` (app.domain.jp.user_consent) — APPI consent records (append-only)
- `JpItSession` → `jp_it_sessions` (app.domain.jp.it_session) — IT重説 session with Zoom integration
- `JpEContract` → `jp_econtracts` (app.domain.jp.econtract) — electronic contract via CloudSign

### New Routes (app/api/routes/jp/)
- `POST /api/jp/payments/intents` — create payment intent
- `GET  /api/jp/payments/intents/{id}` — get intent status
- `POST /api/jp/payments/intents/{id}/konbini-voucher` — issue konbini voucher
- `POST /api/jp/webhooks/komoju` — Komoju webhook (HMAC + idempotency)
- `GET  /api/jp/invoices/{invoice_id}` — invoice detail with lines + totals
- `POST /api/jp/consent/grant` — grant APPI consent
- `GET  /api/jp/consent` — current consent status
- `POST /api/jp/consent/revoke` — revoke consent
- `GET  /api/jp/me/data-export` — DSR data export (zip)
- `POST /api/jp/me/data-delete` — DSR deletion request (30-day schedule)
- `POST /api/jp/it-sessions` — create IT重説 session + Zoom meeting
- `POST /api/jp/it-sessions/{id}/consent` — record tenant IT重説 consent
- `GET  /api/jp/it-sessions/{id}` — IT session detail
- `POST /api/jp/econtracts` — create + send eContract via CloudSign
- `GET  /api/jp/econtracts/{id}` — eContract detail
- `POST /api/jp/webhooks/cloudsign` — CloudSign webhook (HMAC + idempotency)

### New Services
- `app/services/payment/jp/base.py` — JpPaymentAdapter Protocol
- `app/services/payment/jp/komoju/client.py` — KomojuMockClient + KomojuClient
- `app/services/payment/jp/provider_resolver.py` — per-org adapter factory
- `app/services/jp/invoice/line_generator.py` — compute_line_drafts() + JP tax rules
- `app/services/consent/capture.py` — APPI consent grant/revoke
- `app/services/consent/dsr.py` — DSR export (zip) + deletion schedule
- `app/services/it_session/zoom_adapter.py` — Zoom mock + real adapter
- `app/services/it_session/scheduler.py` — IT重説 session creation + consent capture
- `app/services/econtract/cloudsign_adapter.py` — CloudSign mock + real adapter
- `app/services/crypto.py` — Fernet encryption for OrgProviderConfig.config_encrypted

### Webhook Multi-Tenant Limitation (Known)
In the Komoju webhook handler, org_id is extracted from the payload metadata field
(set at session creation time). In a deployment with multiple orgs using different
webhook secrets, the HMAC check must happen after org_id extraction. Current
implementation resolves the adapter using the org_id from payload metadata before
HMAC verification. In mock mode (development), HMAC is skipped entirely.
Production multi-org deployments should embed org_id in session metadata at
create_payment_intent() time (already implemented) and route webhook verification
per-org accordingly. This is tracked as a P3 enhancement.
