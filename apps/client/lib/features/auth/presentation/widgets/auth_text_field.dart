import 'package:flutter/material.dart';
import 'package:sat_east_client/core/theme/booklet_tokens.dart';

/// Labelled text field: label above, 48 px control, inline error with the
/// theme's 2 px error border, optional password visibility toggle.
class AuthTextField extends StatefulWidget {
  const AuthTextField({
    required this.label,
    required this.controller,
    super.key,
    this.focusNode,
    this.isPassword = false,
    this.error,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool isPassword;

  /// Inline error content shown under the field (text, optionally with a link).
  final Widget? error;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onSubmitted;

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: BookletSpace.s2,
      children: [
        ExcludeSemantics(
          child: Text(widget.label, style: theme.textTheme.labelLarge),
        ),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            obscureText: widget.isPassword && _obscured,
            enableSuggestions: !widget.isPassword,
            autocorrect: !widget.isPassword,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            onSubmitted: widget.onSubmitted,
            decoration: InputDecoration(
              isDense: true,
              constraints: const BoxConstraints(
                minHeight: BookletSize.touchTarget,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: BookletSpace.s3,
                vertical: BookletSpace.s3,
              ),
              error: widget.error,
              suffixIcon: widget.isPassword
                  ? IconButton(
                      tooltip: _obscured ? 'Show password' : 'Hide password',
                      icon: Icon(
                        _obscured ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscured = !_obscured),
                    )
                  : null,
            ),
          ),
        ),
      ],
    );
  }
}
