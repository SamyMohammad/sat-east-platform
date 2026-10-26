// PROTOTYPE — throwaway. Three restyles of the practice question screen, switchable via ?variant=. Not production; do not import from features.
// ignore_for_file: lines_longer_than_80_chars, always_use_package_imports

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sat_east_client/shared/widgets/question_view/question_data.dart';

import 'prototype_switcher.dart';
import 'variant_a_material.dart';
import 'variant_b_shadcn.dart';
import 'variant_c_bluebook.dart';

const _mcq = QuestionData(
  id: 'q7',
  label: '4.2 · Ex 7',
  stemMd: r'Solve for \(x\): \(3x - 7 = 29\)',
  kind: McqKind([
    ChoiceData(label: 'A', md: r'\(x = 7\)'),
    ChoiceData(label: 'B', md: r'\(x = 12\)'),
    ChoiceData(label: 'C', md: r'\(x = \frac{22}{3}\)'),
    ChoiceData(label: 'D', md: r'\(x = 36\)'),
  ]),
  difficulty: QuestionDifficulty.easy,
  skill: 'Linear equations',
);

class RestylePrototypeScreen extends StatelessWidget {
  const RestylePrototypeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final raw = GoRouterState.of(context).uri.queryParameters['variant'];
    final variant = {'A', 'B', 'C'}.contains(raw) ? raw! : 'A';
    return Stack(
      fit: StackFit.expand,
      children: [
        // Reserve a separate strip so the comparison controls never cover UI.
        Padding(
          padding: const EdgeInsets.only(bottom: 80),
          child: switch (variant) {
            'B' => const VariantBShadcn(question: _mcq),
            'C' => const VariantCBluebook(question: _mcq),
            _ => const VariantAMaterial(question: _mcq),
          },
        ),
        Positioned(
          bottom: 12,
          left: 12,
          right: 12,
          child: SafeArea(
            top: false,
            child: Center(child: PrototypeSwitcher(variant: variant)),
          ),
        ),
      ],
    );
  }
}
