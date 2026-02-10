import 'package:flutter/material.dart';
import 'package:meshagent/client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class RoomNameResult {
  final String name;
  final bool owner;

  RoomNameResult(this.name, this.owner);
}

Future<RoomNameResult?> showRoomNameDialog(
  BuildContext context, {
  String title = 'Create room',
  String description = 'Give this a short, memorable name.',
  String initialValue = '',
  String label = 'Name',
  String placeholder = 'e.g. General',
}) {
  final formKey = GlobalKey<ShadFormState>();
  final tt = ShadTheme.of(context).textTheme;
  final labelStyle = tt.small.copyWith(fontWeight: FontWeight.w600);

  return showShadDialog<RoomNameResult?>(
    context: context,
    builder: (ctx) {
      void submit() {
        if (formKey.currentState!.saveAndValidate()) {
          final values = formKey.currentState!.value;
          final name = (values['name'] as String).trim();

          Navigator.of(ctx).pop(RoomNameResult(name, true));
        }
      }

      return ShadDialog(
        useSafeArea: false,
        title: Text(title),
        description: Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(description)),
        actions: [
          ShadButton.outline(onPressed: () => Navigator.of(ctx).pop(null), child: const Text('Cancel')),
          ShadButton(onPressed: submit, child: const Text('Continue')),
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
                  placeholder: Text(placeholder),
                  initialValue: initialValue,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submit(),
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

Future<void> showRoomCreationErrorDialog(BuildContext context, Object error) {
  String title = 'Something went wrong';
  String description = 'An error occurred while creating the room. Please try again.';

  if (error is NameInUseException) {
    title = error.message;
    description = 'A room with this name (and similar variations) already exists. Please choose a different name.';
  } else if (error is MeshagentException) {
    title = error.message;
  }

  debugPrint('Room creation error: $error');

  return showShadDialog(
    context: context,
    builder: (context) {
      return ShadDialog.alert(
        useSafeArea: false,
        title: Text(title),
        description: Text(description),
        actions: [ShadButton(onPressed: () => Navigator.of(context).pop(), child: const Text("OK"))],
      );
    },
  );
}
