import 'package:flutter/material.dart';
import 'package:powerboards/ui/powerboards_dialog.dart';

/// A simple confirmation dialog with a YES button, NO button and a title.
/// By default, [ConfirmationDialog.close] will automatically remove itself from [ConfirmationDialog.dialogs].
/// The [ConfirmationDialog.close] method can be used to override the default close behaviour.
/// [ConfirmationDialog.close] will be called before [ConfirmationDialog.onOk] and [ConfirmationDialog.onCancel]
/// Example:
///
/// ```
/// class MyButton extends StatelessWidget{
///   const MyButton({super.key});
///
///   @override
///   Widget build(BuildContext context){
///     return WidgetWithDialogs(builder: (context, dialogs){
///       return TextButton(
///         onPressed: (){
///           ConfirmationDialog dialog = ConfirmationDialog(
///             controller: dialogs,
///             title: 'Are you ok?',
///             onCancel(){
///               // do something
///             },
///             onOk: (){
///               // do something
///             },
///           );
///           dialogs.add(dialog);
///         },
///         child: const Text('My Question'),
///       );
///     }
///   });
/// }
/// ```
///

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.controller,
    required this.title,
    this.onOk,
    this.onCancel,
    this.close,
    this.cancelButtonText = "NO",
    this.okButtonText = "YES",
  });

  final String title;
  final String cancelButtonText;
  final String okButtonText;
  final DialogController controller;
  final void Function()? onCancel;
  final void Function()? onOk;

  /// Override the default close behavior.
  final void Function()? close;

  void _close() {
    if (close != null) {
      close?.call();
    } else {
      controller.remove(this);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PowerboardsDialog(
      builder: (context) {
        final theme = Theme.of(context);

        return IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: theme.dialogTheme.titleTextStyle, key: const Key('confirm-dialog-title')),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    OutlinedButton(
                      key: const Key('confirm-dialog-cancel-button'),
                      onPressed: () {
                        _close();
                        onCancel?.call();
                      },
                      child: Text(cancelButtonText),
                    ),
                    const SizedBox(width: 10),
                    FilledButton(
                      key: const Key('confirm-dialog-ok-button'),
                      onPressed: () {
                        _close();
                        onOk?.call();
                      },
                      child: Text(okButtonText),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
