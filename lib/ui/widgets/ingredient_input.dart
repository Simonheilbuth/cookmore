import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/validators.dart';

/// Text field with an "Add" button, used for ingredients, the pantry and
/// the shopping list. The field is cleared when [onSubmit] returns true.
class IngredientInput extends StatefulWidget {
  const IngredientInput({
    super.key,
    required this.hintText,
    required this.onSubmit,
    this.errorText,
    this.enabled = true,
  });

  final String hintText;
  final FutureOr<bool> Function(String value) onSubmit;
  final String? errorText;
  final bool enabled;

  @override
  State<IngredientInput> createState() => _IngredientInputState();
}

class _IngredientInputState extends State<IngredientInput> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  Future<void> _submit() async {
    final accepted = await widget.onSubmit(_controller.text);
    if (!mounted) return;
    if (accepted) _controller.clear();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            enabled: widget.enabled,
            textInputAction: TextInputAction.done,
            textCapitalization: TextCapitalization.none,
            // Limit the length already while typing.
            inputFormatters: [
              LengthLimitingTextInputFormatter(Validators.ingredientMaxLength),
            ],
            decoration: InputDecoration(
              hintText: widget.hintText,
              errorText: widget.errorText,
            ),
            onSubmitted: (_) => _submit(),
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          tooltip: 'Add',
          onPressed: widget.enabled ? _submit : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
