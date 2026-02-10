import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class NewProjectDialog extends StatelessWidget {
  const NewProjectDialog({super.key, required this.formKey});

  final GlobalKey<ShadFormState> formKey;

  @override
  Widget build(BuildContext context) {
    final tt = ShadTheme.of(context).textTheme;
    final labelStyle = tt.small.copyWith(fontWeight: FontWeight.w600);

    return ShadDialog(
      useSafeArea: false,
      title: Text("New Project"),
      description: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text('Each project has its own members and billing')),
      actions: [
        ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Cancel')),
        ShadButton(
          onPressed: () {
            if (formKey.currentState!.saveAndValidate()) {
              final values = formKey.currentState!.value;
              final name = (values['name'] as String).trim();

              Navigator.of(context).pop(name);
            }
          },
          child: const Text('Create Project'),
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
                label: Text('Name', style: labelStyle),
                placeholder: Text('e.g. General'),
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
  }
}

Future<String?> showNewProjectDialog(BuildContext context) {
  final formKey = GlobalKey<ShadFormState>();

  return showShadDialog<String?>(
    context: context,
    builder: (context) => NewProjectDialog(formKey: formKey),
  );
}
