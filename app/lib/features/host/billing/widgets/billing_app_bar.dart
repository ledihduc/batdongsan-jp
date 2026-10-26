import 'package:flutter/material.dart';
import 'package:house_booking/features/host/dashboard/host_dashboard_tokens.dart';

/// Shared appbar for billing screens — paper background, eyebrow title.
PreferredSizeWidget billingAppBar(String eyebrow, {List<Widget>? actions}) {
  return AppBar(
    backgroundColor: HD.paper,
    surfaceTintColor: HD.paper,
    elevation: 0,
    scrolledUnderElevation: 0,
    foregroundColor: HD.ink,
    iconTheme: const IconThemeData(color: HD.ink, size: 20),
    shape: const Border(bottom: BorderSide(color: HD.hairline)),
    titleSpacing: 0,
    title: Text(eyebrow,
        style: HD.eyebrow(color: HD.ink).copyWith(letterSpacing: 1.6)),
    actions: actions,
  );
}
