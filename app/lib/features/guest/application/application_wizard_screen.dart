/// JP 入居申込 wizard — 5-step application flow.
///
/// This is the parent GoRoute screen. Each step is pushed as a child via
/// [Navigator.push] (no URL per step). The wizard maintains application
/// state across steps via [_WizardState] and delegates persistence to
/// [IJpApplicationRepository].
///
/// Route: /applications/:id
///   - :id == '0' → create new application for a listing
///   - :id > 0   → resume/edit an existing draft application
/// Query params:
///   - listing_id (required when :id == '0')
///
/// Provider: none — self-contained with repository.
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/data/models/jp/jp_application.dart';
import 'package:house_booking/data/repositories/jp/mock_jp_application_repository.dart';
import 'package:house_booking/domain/repositories/jp/i_jp_application_repository.dart';
import 'package:house_booking/l10n/app_localizations.dart';
import 'steps/step1_basic_info.dart';
import 'steps/step2_employer.dart';
import 'steps/step3_guarantor.dart';
import 'steps/step4_documents.dart';
import 'steps/step5_confirm.dart';

class ApplicationWizardScreen extends StatefulWidget {
  /// [applicationId] = 0 means create new.
  const ApplicationWizardScreen({
    super.key,
    required this.applicationId,
    this.listingId,
    IJpApplicationRepository? repository,
  }) : _repository = repository;

  final int applicationId;
  final int? listingId;
  final IJpApplicationRepository? _repository;

  @override
  State<ApplicationWizardScreen> createState() =>
      _ApplicationWizardScreenState();
}

class _ApplicationWizardScreenState extends State<ApplicationWizardScreen> {
  late final IJpApplicationRepository _repo;

  // Mutable wizard state — built up step by step.
  int _step = 1;
  static const int _totalSteps = 5;

  // Collected data per step.
  String _name = '';
  String _phone = '';
  String _email = '';
  JpEmployerInfo? _employer;
  JpContactPerson? _guarantor;
  JpContactPerson? _emergencyContact;
  List<JpDocumentRef> _documents = [];

  int _applicationId = 0;
  bool _submitting = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _repo = widget._repository ?? MockJpApplicationRepository();
    _applicationId = widget.applicationId;
    if (_applicationId > 0) {
      _loadDraft();
    }
  }

  Future<void> _loadDraft() async {
    setState(() => _loading = true);
    try {
      final app = await _repo.getById(_applicationId);
      if (mounted) {
        setState(() {
          _name = app.applicantName;
          _phone = app.applicantPhone;
          _email = app.applicantEmail;
          _employer = app.employer;
          _guarantor = app.guarantor;
          _emergencyContact = app.emergencyContact;
          _documents = List<JpDocumentRef>.from(app.documents);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  JpApplication _buildApplication() {
    return JpApplication(
      id: _applicationId,
      listingId: widget.listingId ?? 0,
      tenantId: 0, // filled by server from JWT
      status: JpApplicationStatus.draft,
      applicantName: _name,
      applicantPhone: _phone,
      applicantEmail: _email,
      employer: _employer,
      guarantor: _guarantor,
      emergencyContact: _emergencyContact,
      documents: _documents,
    );
  }

  Future<void> _saveDraft() async {
    try {
      final saved = await _repo.saveDraft(_buildApplication());
      if (mounted && _applicationId == 0) {
        setState(() => _applicationId = saved.id);
      }
    } catch (_) {
      // Non-blocking — wizard still advances.
    }
  }

  void _advance(int toStep) {
    _saveDraft();
    setState(() => _step = toStep);
  }

  void _back(int toStep) {
    setState(() => _step = toStep);
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);
    try {
      final saved = await _repo.saveDraft(_buildApplication());
      await _repo.submit(saved.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('申込を送信しました。')),
        );
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('送信に失敗しました。もう一度お試しください。')),
        );
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final stepLabels = [
      l.jp_step_basic_info,
      l.jp_step_employer,
      l.jp_step_guarantor,
      l.jp_step_documents,
      l.jp_step_confirm,
    ];

    return Scaffold(
      backgroundColor: HD.paper,
      appBar: DsAppBar(
        eyebrow: l.jp_apply,
        title: stepLabels[_step - 1],
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '$_step / $_totalSteps',
                style: const TextStyle(color: HD.inkMuted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: HD.accent))
          : Column(
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: _step / _totalSteps,
                  backgroundColor: HD.paperSunken,
                  valueColor: const AlwaysStoppedAnimation(HD.accent),
                  minHeight: 3,
                ),
                Expanded(child: _buildStep(l)),
              ],
            ),
    );
  }

  Widget _buildStep(AppLocalizations l) {
    switch (_step) {
      case 1:
        return ApplicationStep1BasicInfo(
          initialName: _name,
          initialPhone: _phone,
          initialEmail: _email,
          onNext: ({required name, required phone, required email}) {
            setState(() {
              _name = name;
              _phone = phone;
              _email = email;
            });
            _advance(2);
          },
        );
      case 2:
        return ApplicationStep2Employer(
          initialEmployer: _employer,
          onBack: () => _back(1),
          onNext: (employer) {
            setState(() => _employer = employer);
            _advance(3);
          },
        );
      case 3:
        return ApplicationStep3Guarantor(
          initialGuarantor: _guarantor,
          initialEmergencyContact: _emergencyContact,
          onBack: () => _back(2),
          onNext: (guarantor, emergency) {
            setState(() {
              _guarantor = guarantor;
              _emergencyContact = emergency;
            });
            _advance(4);
          },
        );
      case 4:
        return ApplicationStep4Documents(
          applicationId: _applicationId == 0 ? -1 : _applicationId,
          existingDocuments: _documents,
          onBack: () => _back(3),
          onNext: (docs) {
            setState(() => _documents = docs);
            _advance(5);
          },
        );
      case 5:
        return ApplicationStep5Confirm(
          application: _buildApplication(),
          submitting: _submitting,
          onBack: () => _back(4),
          onSubmit: _submit,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
