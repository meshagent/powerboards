import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

Future<String?> showRenameRoomDialog(
  BuildContext context, {
  String title = 'Rename room',
  String description = 'Use this a short, memorable name.',
  String initialValue = '',
  String label = 'Name',
  String placeholder = 'e.g. General',
}) {
  final formKey = GlobalKey<ShadFormState>();
  final tt = ShadTheme.of(context).textTheme;
  final labelStyle = tt.small.copyWith(fontWeight: FontWeight.w600);

  return showShadDialog<String?>(
    context: context,
    builder: (ctx) {
      return ShadDialog(
        useSafeArea: false,
        title: Text(title),
        description: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(description)),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ShadButton(
            onPressed: () {
              if (formKey.currentState!.saveAndValidate()) {
                final values = formKey.currentState!.value;
                final name = (values['name'] as String).trim();

                Navigator.of(ctx).pop(name);
              }
            },
            child: const Text('Continue'),
          ),
        ],
        child: ShadForm(
          key: formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ShadInputFormField(
                  id: 'name',
                  label: Text('New Name', style: labelStyle),
                  placeholder: Text(placeholder),
                  initialValue: initialValue,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    final value = v.trim();

                    if (value.isEmpty) return 'Please enter a name.';
                    if (value.length < 2) return 'Name must be at least 2 characters.';
                    return null;
                  },
                ),

                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      );
    },
  );
}
