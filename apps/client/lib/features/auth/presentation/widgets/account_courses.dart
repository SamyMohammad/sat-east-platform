import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/app_tokens.dart';
import 'package:sat_east_client/features/auth/domain/entities/my_enrollment.dart';

class AccountCourses extends StatelessWidget {
  const AccountCourses({required this.enrollments, super.key});

  final List<MyEnrollment> enrollments;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppSpace.s3,
    children: [
      Text('Course', style: Theme.of(context).textTheme.titleLarge),
      for (final enrollment in enrollments) ...[
        const Divider(),
        Text(
          enrollment.courseTitle,
          style: Theme.of(context).textTheme.titleMedium,
          textDirection: TextDirection.ltr,
        ),
        if (enrollment.targetTestDate case final date?)
          _DateRow(label: 'Test date', date: date),
        _DateRow(
          label: enrollment.isExpired ? 'Access ended' : 'Access until',
          date: enrollment.expiresAt.toLocal(),
        ),
      ],
      const Text('Contact your teacher to change your test date.'),
    ],
  );
}

class _DateRow extends StatelessWidget {
  const _DateRow({required this.label, required this.date});

  final String label;
  final DateTime date;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    spacing: AppSpace.s3,
    children: [
      Expanded(child: Text(label)),
      Flexible(
        child: Text(MaterialLocalizations.of(context).formatShortDate(date)),
      ),
    ],
  );
}
