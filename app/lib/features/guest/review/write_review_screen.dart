import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:house_booking/core/widgets/empty_state.dart';
import 'package:house_booking/data/services/review_service.dart';
import 'package:house_booking/providers/auth_provider.dart';
import 'package:house_booking/core/widgets/ds.dart';
import 'package:house_booking/l10n/app_localizations.dart';

class WriteReviewScreen extends StatefulWidget {
  final int houseId;
  final String houseTitle;

  const WriteReviewScreen({
    super.key,
    required this.houseId,
    required this.houseTitle,
  });

  @override
  State<WriteReviewScreen> createState() => _WriteReviewScreenState();
}

class _WriteReviewScreenState extends State<WriteReviewScreen> {
  int _rating = 5;
  final _commentCtrl = TextEditingController();
  final _service = ReviewService();
  bool _saving = false;

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l = AppLocalizations.of(context);
    final user = Provider.of<AuthProvider>(context, listen: false).currentUser;
    if (user == null) return;
    setState(() => _saving = true);
    try {
      await _service.submit(
        userId: user.id!,
        houseId: widget.houseId,
        rating: _rating,
        comment: _commentCtrl.text.trim(),
      );
      if (!mounted) return;
      AppFeedback.success(context, l.reviewSubmitSuccess);
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) AppFeedback.error(context, l.reviewSubmitError('$e'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: DsAppBar(title: l.reviewTitle),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.houseTitle,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 24),
            Text(
              l.reviewRatePrompt,
              textAlign: TextAlign.center,
              style: const TextStyle(color: HD.inkSoft),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  tooltip: l.reviewStarTooltip(star),
                  iconSize: 40,
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: Colors.amber,
                  ),
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _commentCtrl,
              maxLines: 5,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: l.reviewCommentLabel,
                hintText: l.reviewCommentHint,
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _saving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      l.reviewSubmitButton,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
