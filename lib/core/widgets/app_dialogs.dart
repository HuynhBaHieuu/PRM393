import 'package:flutter/material.dart';

import 'package:all_fits/core/extensions/context_extensions.dart';

/// Shows a confirmation dialog. Resolves to true only when confirmed.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final palette = context.palette;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(cancelLabel),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: TextButton.styleFrom(
            foregroundColor: destructive ? palette.danger : palette.ink,
          ),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Prompts for a single line of text. Resolves to null when cancelled.
Future<String?> showTextInputDialog(
  BuildContext context, {
  required String title,
  String initialValue = '',
  String? hint,
  String? prefixText,
  int? maxLength,
  String confirmLabel = 'Save',
  TextInputType? keyboardType,
  bool multiline = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (context) => _TextInputDialog(
      title: title,
      initialValue: initialValue,
      hint: hint,
      prefixText: prefixText,
      maxLength: maxLength,
      confirmLabel: confirmLabel,
      keyboardType: keyboardType,
      multiline: multiline,
    ),
  );
}

class _TextInputDialog extends StatefulWidget {
  const _TextInputDialog({
    required this.title,
    required this.initialValue,
    required this.confirmLabel,
    this.hint,
    this.prefixText,
    this.maxLength,
    this.keyboardType,
    this.multiline = false,
  });

  final String title;
  final String initialValue;
  final String confirmLabel;
  final String? hint;
  final String? prefixText;
  final int? maxLength;
  final TextInputType? keyboardType;
  final bool multiline;

  @override
  State<_TextInputDialog> createState() => _TextInputDialogState();
}

class _TextInputDialogState extends State<_TextInputDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        maxLength: widget.maxLength,
        keyboardType: widget.multiline
            ? TextInputType.multiline
            : widget.keyboardType,
        minLines: widget.multiline ? 3 : 1,
        maxLines: widget.multiline ? 6 : 1,
        textCapitalization: widget.multiline
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        textInputAction: widget.multiline
            ? TextInputAction.newline
            : TextInputAction.done,
        onSubmitted: widget.multiline ? null : (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint,
          prefixText: widget.prefixText,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}
