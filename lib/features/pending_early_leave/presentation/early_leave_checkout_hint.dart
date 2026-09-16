import 'package:flutter/material.dart';

import '../../../theme/theme.dart';
import '../domain/early_leave_checkout_eligibility.dart';

final class EarlyLeaveCheckoutHint extends StatelessWidget {
  const EarlyLeaveCheckoutHint({super.key, required this.eligibility});

  final EarlyLeaveCheckoutEligibility eligibility;

  @override
  Widget build(BuildContext context) => Directionality(
    textDirection: TextDirection.rtl,
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: ZaWolfColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ZaWolfColors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: ZaWolfColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              eligibility.warningArabic,
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white, height: 1.5),
            ),
          ),
        ],
      ),
    ),
  );
}
