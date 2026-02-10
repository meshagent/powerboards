import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_solidart/flutter_solidart.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

class UserSelect extends StatefulWidget {
  const UserSelect({super.key, required this.projectId, this.focusNode, this.initialUser, this.onChanged});

  final FocusNode? focusNode;
  final String projectId;
  final String? initialUser;
  final void Function(String?)? onChanged;

  @override
  State<UserSelect> createState() => _UserSelectState();
}

class _UserSelectState extends State<UserSelect> {
  String searchValue = "";

  late final users = Resource<List<Map<String, dynamic>>>(() async {
    return await getMeshagentClient().getUsersInProject(widget.projectId);
  });

  final popoverController = ShadPopoverController();

  late final controller = ShadSelectController<String?>(initialValue: {widget.initialUser});

  List<Map<String, dynamic>> get _filteredUsers {
    final list = users.state.isReady ? users.state.value! : const <Map<String, dynamic>>[];
    if (searchValue.isEmpty) return list;
    final lower = searchValue.toLowerCase();
    return list.where((u) => (u["email"] as String).toLowerCase().contains(lower)).toList();
  }

  Map<String, dynamic>? _firstStartsWith(List<Map<String, dynamic>> list) {
    final lower = searchValue.toLowerCase();
    return list.firstWhereOrNull((user) => (user["email"] as String).toLowerCase().startsWith(lower));
  }

  KeyEventResult _submitCurrentSelection() {
    if (!users.state.isReady) {
      return KeyEventResult.ignored;
    }

    final list = _filteredUsers;
    final firstStartsWith = _firstStartsWith(list);

    final String? selectedEmail =
        (firstStartsWith?["email"] as String?) ?? (list.firstOrNull?["email"] as String?) ?? (searchValue.isNotEmpty ? searchValue : null);

    if (selectedEmail == null) {
      return KeyEventResult.ignored;
    }

    controller.value = {selectedEmail};
    widget.onChanged?.call(selectedEmail);

    popoverController.setOpen(false);
    setState(() {
      searchValue = "";
    });

    return KeyEventResult.handled;
  }

  late final searchFocusNode = FocusNode(
    onKeyEvent: (_, event) {
      if (event is KeyDownEvent && (event.logicalKey == LogicalKeyboardKey.enter || event.logicalKey == LogicalKeyboardKey.numpadEnter)) {
        return _submitCurrentSelection();
      }

      return KeyEventResult.ignored;
    },
  );

  @override
  void dispose() {
    popoverController.dispose();
    controller.dispose();
    searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SignalBuilder(
      builder: (context, _) {
        final list = _filteredUsers;
        final firstMatch = _firstStartsWith(list);

        return ShadSelect<String?>(
          padding: EdgeInsets.zero,
          anchor: const ShadAnchor(childAlignment: Alignment.topLeft),
          popoverController: popoverController,
          onChanged: widget.onChanged,
          controller: controller,
          maxHeight: kIsWeb ? null : MediaQuery.of(context).size.height * 0.3,
          options: !users.state.isReady
              ? []
              : [
                  if (list.isEmpty && searchValue.isNotEmpty) ShadOption<String?>(value: searchValue, child: Text('$searchValue (new)')),
                  for (final user in list)
                    ShadOption<String?>(
                      backgroundColor: user == firstMatch ? ShadTheme.of(context).colorScheme.selection : null,
                      value: user["email"],
                      child: Text(user["isNew"] == true ? "${user["email"]} (new user)" : user["email"]),
                    ),
                ],
          selectedOptionBuilder: (context, value) => Container(
            width: double.infinity,
            alignment: Alignment.centerLeft,
            child: value == null
                ? Listener(
                    onPointerDown: (event) {
                      popoverController.setOpen(true);
                    },
                    child: ShadInput(
                      textInputAction: TextInputAction.done,
                      padding: const EdgeInsets.all(8),
                      decoration: ShadDecoration.none,
                      placeholder: const Text("Type an email"),
                      focusNode: searchFocusNode,
                      onSubmitted: (_) {
                        _submitCurrentSelection();
                      },
                      onChanged: (value) {
                        setState(() {
                          searchValue = value;
                          if (widget.onChanged != null) {
                            widget.onChanged!(value);
                          }
                        });
                      },
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(6),
                    child: ShadBadge(
                      padding: const EdgeInsets.all(4),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 6),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          spacing: 8,
                          children: [
                            Text(value),
                            ShadGestureDetector(
                              onTap: () {
                                controller.value = {null};
                                widget.onChanged?.call(null);

                                setState(() {
                                  searchValue = "";
                                });
                                popoverController.setOpen(true);
                              },
                              child: Icon(LucideIcons.x, color: ShadTheme.of(context).colorScheme.background),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}

class UserSelectFormField extends ShadFormBuilderField<String?> {
  UserSelectFormField({
    super.key,
    super.id,
    super.focusNode,
    required this.projectId,
    super.label,
    super.description,
    super.onChanged,
    super.validator,
  }) : super(
         builder: (state) {
           return UserSelect(projectId: projectId, focusNode: focusNode, initialUser: state.value, onChanged: state.didChange);
         },
       );

  final String projectId;
}

class UserSelectFormFieldState extends ShadFormBuilderFieldState<UserSelectFormField, String?> {}
