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
- `GET    /api/v2/admin/system/notifications` → list_notifications
- `POST   /api/v2/admin/system/notifications/{push_id}/retry` → retry_notification

### app.api.routes.ai_actions
- `GET    /api/ai/actions/{token}` → preview_ai_action
- `POST   /api/ai/actions/{token}/confirm` → confirm_ai_action

### app.api.routes.ai_chat
- `POST   /api/ai/chat` → ai_chat

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

### app.api.routes.ekyc
- `POST   /api/ekyc/anh/{loai}` → anh
- `GET    /api/ekyc/ho-so` → xem
- `POST   /api/ekyc/link` → tao_link
- `POST   /api/ekyc/nop` → nop
- `PUT    /api/ekyc/thong-tin` → thong_tin

### app.api.routes.jp.address
- `GET    /api/jp/address/lookup` → lookup_address

### app.api.routes.jp.admin_kpi
- `GET    /api/jp/admin/kpis` → get_kpis

### app.api.routes.jp.application_reviews
- `GET    /api/jp/applications/{app_id}/reviews` → list_reviews_for_application
- `POST   /api/jp/applications/{app_id}/reviews` → submit_review_decision

### app.api.routes.jp.applications
- `GET    /api/jp/applications` → list_applications
- `POST   /api/jp/applications` → create_application
- `GET    /api/jp/applications/{app_id}` → get_application
- `POST   /api/jp/applications/{app_id}/start-review` → start_review_endpoint
- `POST   /api/jp/applications/{app_id}/submit` → submit_application_endpoint
- `GET    /api/jp/applications/{app_id}/upload-url` → get_upload_url

### app.api.routes.jp.compliance
- `GET    /api/jp/compliance/evidence` → get_compliance_evidence

### app.api.routes.jp.consent
- `GET    /api/jp/consent` → get_current_consent
- `POST   /api/jp/consent/grant` → grant_consent
- `POST   /api/jp/consent/revoke` → revoke_consent_endpoint

### app.api.routes.jp.deposit_settlements
- `POST   /api/jp/deposit-settlements` → create_settlement
- `PATCH  /api/jp/deposit-settlements/{settlement_id}/items` → patch_settlement_items
- `POST   /api/jp/deposit-settlements/{settlement_id}/payout` → process_payout
- `POST   /api/jp/deposit-settlements/{settlement_id}/tenant-sign` → tenant_sign_settlement

### app.api.routes.jp.econtracts
- `POST   /api/jp/econtracts` → create_econtract
- `GET    /api/jp/econtracts/{econtract_id}` → get_econtract

### app.api.routes.jp.invoices
- `GET    /api/jp/invoices/{invoice_id}` → get_invoice_detail

### app.api.routes.jp.it_sessions
- `POST   /api/jp/it-sessions` → create_it_session
- `GET    /api/jp/it-sessions/{session_id}` → get_it_session
- `POST   /api/jp/it-sessions/{session_id}/consent` → record_tenant_consent

### app.api.routes.jp.listing_search
- `GET    /api/jp/listings` → list_jp_listings
- `GET    /api/jp/listings/{listing_id}` → get_jp_listing

### app.api.routes.jp.listings
- `POST   /api/jp/listings/attach` → attach_jp_listing_data
- `GET    /api/jp/listings/{listing_id}/jp-data` → get_jp_listing_data
- `GET    /api/jp/stations/search` → search_stations

### app.api.routes.jp.me
- `DELETE /api/jp/me/cancel-deletion` → cancel_deletion
- `POST   /api/jp/me/data-delete` → request_data_delete
- `GET    /api/jp/me/data-export` → get_data_export
- `GET    /api/jp/me/export` → get_real_export
- `POST   /api/jp/me/schedule-deletion` → schedule_deletion

### app.api.routes.jp.payments
- `POST   /api/jp/payments/intents` → create_payment_intent
- `GET    /api/jp/payments/intents/{intent_id}` → get_payment_intent
- `POST   /api/jp/payments/intents/{intent_id}/konbini-voucher` → issue_konbini_voucher

### app.api.routes.jp.renewals
- `POST   /api/jp/renewals/{renewal_id}/confirm` → confirm_renewal
- `POST   /api/jp/renewals/{renewal_id}/invoice` → generate_renewal_invoice

### app.api.routes.jp.viewings
- `GET    /api/jp/viewings` → list_viewings
- `POST   /api/jp/viewings` → create_viewing
- `GET    /api/jp/viewings/{viewing_id}` → get_viewing
- `POST   /api/jp/viewings/{viewing_id}/cancel` → cancel_viewing_endpoint
- `POST   /api/jp/viewings/{viewing_id}/complete` → complete_viewing_endpoint
- `POST   /api/jp/viewings/{viewing_id}/confirm` → confirm_viewing_endpoint

### app.api.routes.jp.webhooks_cloudsign
- `POST   /api/jp/webhooks/cloudsign` → receive_cloudsign_webhook

### app.api.routes.jp.webhooks_komoju
- `POST   /api/jp/webhooks/komoju` → receive_komoju_webhook

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

### app.api.routes.services
- `GET    /api/services` → list_services
- `GET    /api/services/requests` → admin_list_requests
- `POST   /api/services/requests` → create_request
- `GET    /api/services/requests/mine` → my_requests
- `PATCH  /api/services/requests/{request_id}` → admin_update_request

### app.mcp.mount
- `GET    /mcp/SKILL.md` → _skill_markdown

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
- `POST   /api/auth/register` → register

### app.routers.basemap_tiles
- `GET    /api/basemap/{z}/{x}/{y}.png` → serve_basemap_tile

### app.routers.blocks
- `GET    /api/social/blocks` → list_blocks
- `DELETE /api/social/blocks/{user_id}` → unblock_user
- `POST   /api/social/blocks/{user_id}` → block_user

### app.routers.catalog
- `GET    /api/amenities` → amenities
- `GET    /api/categories` → categories

### app.routers.chat
- `GET    /api/chats` → conversations
- `GET    /api/chats/{peer_id}/messages` → history
- `POST   /api/chats/{peer_id}/messages` → send
- `PATCH  /api/chats/{peer_id}/read` → mark_read
- `POST   /api/ws-ticket` → issue_ws_ticket

### app.routers.client_logs
- `POST   /api/client-logs` → ingest_client_log

### app.routers.guest_reservation
- `GET    /api/guest/reservations` → list_my_reservations
- `POST   /api/guest/reservations` → create_my_reservation
- `PATCH  /api/guest/reservations/{reservation_id}` → sua_don_cua_toi
- `POST   /api/guest/reservations/{reservation_id}/cancel` → cancel_my_reservation
- `POST   /api/guest/reservations/{reservation_id}/doi-gio` → doi_gio_don
- `POST   /api/guest/reservations/{reservation_id}/doi-gio/bao-gia` → bao_gia_doi_gio
- `GET    /api/guest/reservations/{reservation_id}/lich-su` → lich_su_don
- `GET    /api/guest/reservations/{reservation_id}/phieu` → phieu_dat_phong_cua_toi

### app.routers.host_room
- `GET    /api/host/buildings/{building_id}/rooms` → list_rooms
- `POST   /api/host/buildings/{building_id}/rooms` → create_room
- `DELETE /api/host/rooms/{room_id}` → xoa_phong
- `PATCH  /api/host/rooms/{room_id}` → update_room
- `POST   /api/host/rooms/{room_id}/duplicate` → duplicate_room
- `POST   /api/host/rooms/{room_id}/maintenance` → set_room_maintenance
- `POST   /api/host/rooms/{room_id}/maintenance/end` → end_room_maintenance

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

### app.routers.leads
- `GET    /api/admin/leads` → list_leads
- `POST   /api/leads` → create_lead

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

### app.routers.preferences
- `GET    /api/me/preferences` → get_preferences
- `PUT    /api/me/preferences` → put_preferences

### app.routers.quality_rating
- `GET    /api/houses/{house_id}/quality` → get_quality
- `PUT    /api/houses/{house_id}/quality` → set_quality

### app.routers.search
- `GET    /api/search` → unified_search

### app.routers.seo
- `GET    /privacy` → privacy_policy
- `GET    /robots.txt` → robots
- `GET    /sitemap.xml` → sitemap
- `GET    /support` → support_page
- `GET    /tin` → danh_muc_tin
- `GET    /tin/{slug}` → trang_tin

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
- `ContactLead` → `contact_leads` (app.models.lead)
- `ContentReport` → `content_reports` (app.models.listing)
- `Contract` → `contracts` (app.models.rental)
- `ContractServiceFee` → `contract_service_fees` (app.models.rental)
- `ContractTaiLieu` → `contract_tai_lieu` (app.models.rental)
- `ContractTenant` → `contract_tenants` (app.models.rental)
- `CreditNote` → `credit_notes` (app.models.billing)
- `Deal` → `deals` (app.models.sale)
- `EkycChuNha` → `ekyc_chu_nha` (app.models.host)
- `EkycLink` → `ekyc_link` (app.models.host)
- `HostProfile` → `host_profiles` (app.models.host)
- `House` → `houses` (app.models.listing)
- `HouseViewDay` → `house_view_days` (app.models.listing)
- `Invoice` → `invoices` (app.models.billing)
- `InvoiceLineItem` → `invoice_line_items` (app.models.billing)
- `KhaiBaoTamTru` → `khai_bao_tam_tru` (app.models.khai_bao)
- `LoaiPhong` → `loai_phong` (app.models.rental)
- `MeterReading` → `meter_readings` (app.models.rental)
- `MoneyRefund` → `money_refunds` (app.models.money)
- `Notification` → `notifications` (app.models.messaging)
- `OwnerSettlement` → `owner_settlements` (app.models.money)
- `Payment` → `payments` (app.models.billing)
- `PaymentAllocation` → `payment_allocations` (app.models.money)
- `PlatformPayment` → `platform_payments` (app.models.money)
- `PricingRule` → `pricing_rules` (app.models.homestay)
- `PrivateDocument` → `private_documents` (app.models.admin)
- `PushOutbox` → `push_outbox` (app.models.messaging)
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
- `SaleOwnerLink` → `sale_owner_links` (app.models.sale)
- `SaleProfile` → `sale_profiles` (app.models.sale)
- `SaleTransaction` → `sale_transactions` (app.models.buy_sell)
- `SaleTransactionDocument` → `sale_transaction_documents` (app.models.buy_sell)
- `SaleTransactionEvent` → `sale_transaction_events` (app.models.buy_sell)
- `SavedPost` → `saved_posts` (app.models.listing)
- `ServiceFee` → `service_fees` (app.models.rental)
- `ShortStayRatePlan` → `short_stay_rate_plans` (app.models.short_inventory)
- `ShortStayWorkflowEvent` → `short_stay_workflow_events` (app.models.short_inventory)
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
