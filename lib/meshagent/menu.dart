import 'package:flutter/material.dart';
import 'package:meshagent/room_server_client.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:powerboards/theme/theme.dart';
import 'package:powerboards/ui/toolbar.dart';

class ThreadPickerMenu extends StatefulWidget {
  final RoomClient room;
  final String selected;
  final void Function(String name) onSelect;

  const ThreadPickerMenu({super.key, required this.room, required this.selected, required this.onSelect});

  @override
  State createState() => _ThreadPickerMenuState();
}

class _ThreadPickerMenuState extends State<ThreadPickerMenu> {
  List<StorageEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.room.storage.list(".threads/");
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      // handle error
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return PowerboardsMenuButton(
      key: const Key('thread-options-button'),
      button: ToolbarIconButton(Icons.forum, color: colorScheme.primary, tooltip: "Threads"),
      itemBuilder: (context) {
        if (_loading) {
          return [PowerboardsMenuItemButton(child: Text("Loading..."))];
        }

        return [
          PowerboardsMenuItemButton(child: Text("Threads")),
          ..._entries.map((entry) {
            // final isSelected = entry.name == widget.selected;
            return PowerboardsMenuItemButton(
              onPressed: () => widget.onSelect(entry.name),
              child: Row(
                children: [
                  // if (isSelected) const Icon(Icons.check, color: Colors.black, size: 16) else const SizedBox(width: 16),
                  // const SizedBox(width: 8),
                  Expanded(child: Text(entry.nameWithoutExtension)),
                ],
              ),
            );
          }),
        ];
      },
    );
  }
}

class FilePickerMenu extends StatefulWidget {
  final RoomClient room;
  final void Function(String name) onSelect;

  const FilePickerMenu({super.key, required this.room, required this.onSelect});

  @override
  State createState() => FilePickerMenuState();
}

class FilePickerMenuState extends State<FilePickerMenu> {
  List<StorageEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final entries = await widget.room.storage.list("");

      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      // handle error
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = ShadTheme.of(context).colorScheme;

    return PowerboardsMenuButton(
      key: const Key('files-options-button'),
      button: ToolbarIconButton(Icons.folder, color: colorScheme.primary, tooltip: "Files"),
      itemBuilder: (context) {
        if (_loading) {
          return [PowerboardsMenuItemButton(child: Text("Loading..."))];
        }

        final files = _entries.where((entry) => !entry.name.startsWith('.'));

        return [
          PowerboardsMenuItemButton(child: Text("Files")),

          if (files.isEmpty)
            PowerboardsMenuItemButton(child: Text("This folder is empty"))
          else
            ...files.map((entry) {
              return PowerboardsMenuItemButton(
                onPressed: () => widget.onSelect(entry.name),
                child: Row(children: [Expanded(child: Text(entry.name))]),
              );
            }),
        ];
      },
    );
  }
}
