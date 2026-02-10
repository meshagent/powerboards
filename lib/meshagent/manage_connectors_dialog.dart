import 'package:flutter/material.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:meshagent/meshagent.dart';

class _DeleteButton extends StatefulWidget {
  const _DeleteButton({required this.onPressed});

  final Future<void> Function() onPressed;

  @override
  State createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<_DeleteButton> {
  bool isDeleting = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: isDeleting
          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(LucideIcons.trash2, size: 16),
      onPressed: isDeleting
          ? null
          : () async {
              setState(() {
                isDeleting = true;
              });

              try {
                await widget.onPressed();
              } finally {
                if (mounted) {
                  setState(() {
                    isDeleting = false;
                  });
                }
              }
            },
    );
  }
}

class ManageConnectorsDialog extends StatefulWidget {
  const ManageConnectorsDialog({super.key, required this.projectId, required this.room});

  final String projectId;
  final RoomClient room;

  @override
  State createState() => _ManageConnectorsDialogState();
}

class _ManageConnectorsDialogState extends State<ManageConnectorsDialog> {
  late final secretsRes = Resource<List<SecretInfo>>(widget.room.secrets.listSecrets);

  @override
  void dispose() {
    secretsRes.dispose();

    super.dispose();
  }

  List<ShadTableCell> header(TextStyle style) => [
    ShadTableCell(child: Text('Name', style: style)),
    ShadTableCell(child: Text('Delegated To', style: style)),
    ShadTableCell(child: Text('')),
  ];

  List<ShadTableCell> row(SecretInfo secret) => [
    ShadTableCell(child: Text(secret.name, softWrap: false, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ShadTableCell(child: Text(secret.delegatedTo ?? 'N/A', softWrap: false, maxLines: 1, overflow: TextOverflow.ellipsis)),
    ShadTableCell(
      alignment: Alignment.centerRight,
      child: _DeleteButton(
        onPressed: () async {
          await widget.room.secrets.deleteSecret(secretId: secret.id, delegatedTo: secret.delegatedTo);

          secretsRes.refresh();
        },
      ),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final theme = ShadTheme.of(context);
        final tt = theme.textTheme;

        if (!secretsRes.state.isReady) {
          return const Center(child: CircularProgressIndicator());
        }

        final secrets = secretsRes.state.value ?? [];

        return ShadDialog(
          title: Text('Keychain'),
          description: Text('If you connect this room to an external application, you can remove the connection from here.'),
          actions: [ShadButton(onPressed: () => Navigator.of(context).pop(), child: Text('Close'))],
          child: SizedBox(
            width: 500,
            height: 400,
            child: secrets.isEmpty
                ? Center(child: Text('No connectors found.', style: tt.muted))
                : ShadTable.list(
                    pinnedRowCount: 1,
                    header: header(tt.small.copyWith(fontWeight: FontWeight.bold)),
                    columnSpanExtent: (index) => switch (index) {
                      0 => FractionalSpanExtent(0.4),
                      1 => FractionalSpanExtent(0.4),
                      _ => FractionalSpanExtent(0.2),
                    },
                    children: secrets.map(row),
                  ),
          ),
        );
      },
    );
  }
}
