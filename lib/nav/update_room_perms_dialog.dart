import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';

import 'package:powerboards/meshagent/grant.dart';
import 'package:powerboards/meshagent/user_builder.dart';
import 'package:powerboards/meshagent/meshagent.dart';

import 'package:powerboards/widgets/select_users.dart';

enum _View { permissions, addUser }

enum _LoadingState { loading, loaded }

class _UserSettingsMenuButton extends StatefulWidget {
  const _UserSettingsMenuButton({required this.role, required this.onSetOwner, required this.onSetNonOwner, required this.onRemove});

  final GrantRole role;
  final VoidCallback onSetOwner;
  final VoidCallback onSetNonOwner;
  final VoidCallback onRemove;

  @override
  State createState() => _UserSettingsMenuButtonState();
}

class _UserSettingsMenuButtonState extends State<_UserSettingsMenuButton> {
  final controller = ShadContextMenuController();

  @override
  void dispose() {
    controller.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = ShadTheme.of(context).colorScheme;

    return ShadContextMenuRegion(
      controller: controller,
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        if (widget.role == GrantRole.owner)
          ShadContextMenuItem(
            height: 40.0,
            leading: Icon(LucideIcons.user, size: 16),
            onPressed: widget.onSetNonOwner,
            child: const Text('Set as Member'),
          ),

        if (widget.role == GrantRole.nonOwner)
          ShadContextMenuItem(
            height: 40.0,
            leading: Icon(LucideIcons.user, size: 16),
            onPressed: widget.onSetOwner,
            child: const Text('Set as Owner'),
          ),

        ShadContextMenuItem(
          height: 40.0,
          leading: Icon(LucideIcons.trash2, size: 16, color: cs.destructive),
          onPressed: widget.onRemove,
          textStyle: TextStyle(color: cs.destructive),
          child: const Text('Remove'),
        ),
      ],
      child: ShadButton.ghost(
        onPressed: controller.show,
        padding: EdgeInsets.zero,
        child: const SizedBox(width: 40, height: 30, child: Icon(LucideIcons.settings, size: 16)),
      ),
    );
  }
}

class _UserGrantRow extends StatelessWidget {
  const _UserGrantRow({
    required this.grantSummary,
    required this.user,
    required this.canEdit,
    required this.setAsOwner,
    required this.setAsNonOwner,
    required this.onRemove,
  });

  final GrantSummary grantSummary;
  final User user;
  final bool canEdit;
  final VoidCallback setAsOwner;
  final VoidCallback setAsNonOwner;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(user.email, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        SizedBox(width: 90, child: Text(grantSummary.role.displayName)),

        if (canEdit)
          _UserSettingsMenuButton(role: grantSummary.role, onSetOwner: setAsOwner, onSetNonOwner: setAsNonOwner, onRemove: onRemove)
        else
          SizedBox(width: 40, height: 30, child: Icon(LucideIcons.lock, size: 16)),
      ],
    );
  }
}

class _PermissionDialog extends StatefulWidget {
  const _PermissionDialog({
    required this.projectId,
    required this.room,
    required this.title,
    required this.description,
    required this.onAddUser,
  });

  final String projectId;
  final Room room;
  final String title;
  final String description;
  final VoidCallback onAddUser;

  @override
  State createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<_PermissionDialog> {
  Map<String, GrantSummary> grants = {};
  _LoadingState state = _LoadingState.loading;
  Map<String, User> userMap = {};

  GrantSummary? get myGrant => grants.values.firstWhereOrNull((g) => isMe(g.userId));

  bool get canEdit => myGrant?.role == GrantRole.owner;

  Future<User> _fetchUser(String userId) async {
    final client = getMeshagentClient();
    final profileJson = await client.getUserProfile(userId);

    return User.fromJson(profileJson);
  }

  Future<Map<String, User>> _fetchAllUsers(Iterable<GrantSummary> grants) async {
    final um = <String, User>{};

    final futures = grants.map(
      (g) => _fetchUser(g.userId).then((user) {
        um[g.userId] = user;
      }),
    );

    await Future.wait(futures);

    return um;
  }

  Future<void> _loadGrants() async {
    final grantMap = await roomGrantSummaries(projectId: widget.projectId, roomName: widget.room.name);

    if (!mounted) return;

    final um = await _fetchAllUsers(grantMap.values);

    if (!mounted) return;

    setState(() {
      state = _LoadingState.loaded;
      grants = grantMap;
      userMap = um;
    });
  }

  @override
  void initState() {
    super.initState();

    _loadGrants();
  }

  Widget _userRowBuilder(BuildContext context, GrantSummary grant) {
    final user = userMap[grant.userId];

    if (user == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: ValueKey(grant.userId),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: _UserGrantRow(
        grantSummary: grant,
        user: user,
        canEdit: canEdit && !isMe(grant.userId),
        setAsOwner: () async {
          final client = getMeshagentClient();
          await client.updateRoomGrant(
            projectId: widget.projectId,
            roomId: widget.room.id,
            userId: grant.userId,
            permissions: GrantRole.owner.apiScope,
          );

          if (!mounted) return;

          setState(() {
            grants[grant.userId] = GrantSummary(userId: grant.userId, role: GrantRole.owner);
          });
        },
        setAsNonOwner: () async {
          final client = getMeshagentClient();
          await client.updateRoomGrant(
            projectId: widget.projectId,
            roomId: widget.room.id,
            userId: grant.userId,
            permissions: GrantRole.nonOwner.apiScope,
          );

          if (!mounted) return;

          setState(() {
            grants[grant.userId] = GrantSummary(userId: grant.userId, role: GrantRole.nonOwner);
          });
        },
        onRemove: () async {
          final client = getMeshagentClient();
          await client.deleteRoomGrant(projectId: widget.projectId, roomId: widget.room.id, userId: grant.userId);

          if (!mounted) return;

          setState(() {
            grants.remove(grant.userId);
          });
        },
      ),
    );
  }

  String _grantToEmail(GrantSummary grant) {
    final user = userMap[grant.userId];
    return user?.email ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final sortedGrants = grants.values.where((g) => !isMe(g.userId)).toList()
      ..sort((a, b) => _grantToEmail(a).toLowerCase().compareTo(_grantToEmail(b).toLowerCase()));

    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final isMobile = breakpoint == theme.breakpoints.tn;

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = isMobile
                ? constraints.maxHeight
                : (constraints.maxHeight > 700.0 ? constraints.maxHeight - 100 : constraints.maxHeight);
            final minHeight = isMobile ? constraints.maxHeight : (constraints.maxHeight > 700.0 ? 600.0 : constraints.maxHeight - 100);
            final maxWidth = isMobile ? constraints.maxWidth : 512.0;
            final minWidth = isMobile ? constraints.maxWidth : 512.0;

            return ShadDialog(
              scrollable: true,
              useSafeArea: false,
              titlePinned: true,
              descriptionPinned: true,
              actionsPinned: true,
              constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight),
              title: Text(widget.title, style: ShadTheme.of(context).textTheme.h4),
              description: Padding(padding: const EdgeInsets.only(bottom: 20), child: Text(widget.description)),
              actions: [
                ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Close')),

                if (canEdit)
                  ShadButton(
                    onPressed: widget.onAddUser,
                    leading: const Icon(LucideIcons.userPlus, size: 16),
                    child: const Text('Add user'),
                  ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 420),
                child: (state == _LoadingState.loading)
                    ? const Center(child: CircularProgressIndicator())
                    : ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 480),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (myGrant != null) _userRowBuilder(context, myGrant!),

                              ...sortedGrants.map((g) => _userRowBuilder(context, g)),
                            ],
                          ),
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class AddedUser {
  AddedUser({required this.email, required this.role});

  final String email;
  final GrantRole role;
}

class AddUserDialog extends StatefulWidget {
  const AddUserDialog({
    super.key,
    required this.projectId,
    required this.room,
    required this.title,
    required this.description,
    this.onBack,
    this.onSaved,
  });

  final String projectId;
  final Room room;
  final String title;
  final String description;
  final VoidCallback? onBack;
  final VoidCallback? onSaved;

  @override
  State createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  bool submitting = false;
  final selectedUsers = Signal<List<AddedUser>>([]);
  final controller = SelectUsersController();
  final textController = TextEditingController();

  late final projectUsersMap = Resource<Map<String, User>>(lazy: false, () async {
    final client = getMeshagentClient();

    final results = await client.getUsersInProject(widget.projectId);
    final users = results.map((json) => User.fromJson(json)).toList();

    return {for (final u in users) u.email.toLowerCase(): u};
  });

  late final grants = Resource<Map<String, GrantSummary>>(lazy: false, () {
    return roomGrantSummaries(projectId: widget.projectId, roomName: widget.room.name);
  });

  @override
  void didUpdateWidget(covariant AddUserDialog oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.projectId != widget.projectId) {
      projectUsersMap.refresh();
      grants.refresh();
    } else if (oldWidget.room.id != widget.room.id) {
      grants.refresh();
    }
  }

  @override
  void dispose() {
    selectedUsers.dispose();
    projectUsersMap.dispose();
    grants.dispose();
    controller.dispose();
    textController.dispose();

    super.dispose();
  }

  Future<void> onAdded() async {
    setState(() => submitting = true);

    await projectUsersMap.untilReady();

    final client = getMeshagentClient();

    // get users not in project
    final selected = selectedUsers.value;
    final projUsersMap = projectUsersMap.state.value ?? {};
    final usersToAddToProject = selected.where((u) => !projUsersMap.containsKey(u.email.toLowerCase()));

    final roomGrantsMap = grants.state.value ?? {};

    final usersInRoomMap = {};
    for (final user in projUsersMap.values) {
      final grants = roomGrantsMap[user.id];
      if (grants != null) {
        usersInRoomMap[user.email.toLowerCase()] = grants;
      }
    }

    try {
      // add users to project if needed
      await Future.wait(usersToAddToProject.map((u) => client.addUserToProjectByEmail(widget.projectId, u.email, canCreateRooms: true)));

      // add grants for all selected users
      await Future.wait(
        selected.map((u) {
          final lcEmail = u.email.toLowerCase();

          if (usersInRoomMap.containsKey(lcEmail)) {
            final grant = usersInRoomMap[u.email.toLowerCase()]!;

            return client.updateRoomGrant(
              projectId: widget.projectId,
              roomId: widget.room.id,
              userId: grant.userId,
              permissions: u.role.apiScope,
            );
          }

          return client.createRoomGrantByEmail(
            projectId: widget.projectId,
            roomId: widget.room.id,
            email: u.email,
            permissions: u.role.apiScope,
          );
        }),
      );

      widget.onSaved?.call();
      widget.onBack?.call();
    } catch (e) {
      if (!mounted) return;

      await showShadDialog(
        context: context,
        builder: (context) {
          return ShadDialog.alert(
            useSafeArea: false,
            title: const Text("Something went wrong"),
            description: const Text("An error occurred while adding users to the project. Please try again."),
            actions: [
              ShadButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text("OK"),
              ),
            ],
          );
        },
      );
    } finally {
      if (mounted) {
        setState(() => submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final inputLabelStyle = theme.decoration.labelStyle?.copyWith(fontWeight: .w700);

    final myUser = MeshagentAuth.current.getUser();
    final myUserId = (myUser?['id'] as String?) ?? '';

    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final isMobile = breakpoint == theme.breakpoints.tn;

        return LayoutBuilder(
          builder: (context, constraints) {
            final maxHeight = isMobile
                ? constraints.maxHeight
                : (constraints.maxHeight > 700.0 ? constraints.maxHeight - 100 : constraints.maxHeight);
            final minHeight = isMobile ? constraints.maxHeight : (constraints.maxHeight > 700.0 ? 600.0 : constraints.maxHeight - 100);
            final maxWidth = isMobile ? constraints.maxWidth : 512.0;
            final minWidth = isMobile ? constraints.maxWidth : 512.0;

            return ShadDialog(
              scrollable: true,
              titlePinned: true,
              descriptionPinned: true,
              actionsPinned: true,
              constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth, minHeight: minHeight, maxHeight: maxHeight),
              title: Text(widget.title, style: theme.textTheme.h4),
              description: Text(widget.description),
              actions: [
                if (widget.onBack != null)
                  ShadButton.outline(
                    onPressed: widget.onBack,
                    leading: const Icon(LucideIcons.arrowLeft, size: 16),
                    child: const Text('Back'),
                  ),
                ShadButton(
                  onPressed: onAdded,
                  enabled: !submitting,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: submitting ? [Icon(Icons.hourglass_top, size: 16), SizedBox(width: 6), Text('Saving...')] : [Text('Save')],
                  ),
                ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 420),
                child: SignalBuilder(
                  builder: (context, _) {
                    final selected = selectedUsers.value;

                    final roomGrants = grants.state.value ?? {};
                    final projUsersMap = projectUsersMap.state.value ?? {};
                    final me = projUsersMap.values.firstWhereOrNull((u) => u.id == myUserId);
                    final isMeAdmin = me?.isAdmin ?? false;

                    return Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .stretch,
                      children: [
                        Text('Enter email address', style: inputLabelStyle),
                        const SizedBox(height: 8),
                        SelectUsers(
                          autofocus: true,
                          projectUsers: projUsersMap.values.toList(),
                          controller: controller,
                          textController: textController,
                          onChanged: (value) {
                            final updated = <AddedUser>[];

                            for (final email in value) {
                              final lcEmail = email.toLowerCase().trim();

                              final user = selectedUsers.value.firstWhereOrNull((u) => u.email.toLowerCase() == lcEmail);
                              if (user != null) {
                                updated.add(user);
                                continue;
                              }

                              final projectUser = projUsersMap[lcEmail];
                              final inProject = projectUser != null;

                              if (inProject) {
                                final grants = roomGrants[projectUser.id];
                                final role = grants != null ? grants.role : GrantRole.nonOwner;

                                updated.add(AddedUser(email: email, role: role));
                              } else {
                                if (isMeAdmin) {
                                  updated.add(AddedUser(email: email, role: GrantRole.nonOwner));
                                } else {
                                  showShadDialog(
                                    context: context,
                                    builder: (context) => ShadDialog.alert(
                                      title: Text('User $email is not in project'),
                                      description: Padding(
                                        padding: EdgeInsets.only(bottom: 8),
                                        child: Text(
                                          'User with email $email does not have access to the project. '
                                          'Only users who are already part of the project can be added to rooms. '
                                          'Please ask a project admin to add this user to the project first.',
                                        ),
                                      ),
                                      actions: [
                                        ShadButton.outline(child: const Text('Close'), onPressed: () => Navigator.of(context).pop(false)),
                                      ],
                                    ),
                                  ).then((_) {
                                    if (!mounted) return;

                                    controller.remove(email);
                                  });
                                }
                              }
                            }

                            selectedUsers.value = updated;
                          },
                        ),
                        const SizedBox(height: 30),
                        ValueListenableBuilder(
                          valueListenable: textController,
                          builder: (context, textEditingValue, _) {
                            final text = textEditingValue.text.trim();
                            final isEmail = SelectUsersController.emailRegex.hasMatch(text);
                            final items = isEmail ? [...selected, AddedUser(email: text, role: GrantRole.nonOwner)] : selected;
                            final usersNotInProject = items.where((u) => !projUsersMap.containsKey(u.email.toLowerCase())).toList();

                            if (usersNotInProject.isEmpty) {
                              return const SizedBox.shrink();
                            }

                            const textColor = Color(0xFFE65100);
                            const backgroundColor = Color(0xFFFCEBEB);

                            return Column(
                              crossAxisAlignment: .start,
                              spacing: 30.0,
                              children: [
                                ShadAlert(
                                  icon: Icon(LucideIcons.triangleAlert),
                                  iconColor: textColor,
                                  iconSize: 24,
                                  description: Text(
                                    'These users are not currently project members. '
                                    'Adding these users to the room, will add them to the project.',
                                    style: TextStyle(color: textColor),
                                  ),
                                  decoration: ShadDecoration(
                                    color: backgroundColor,
                                    border: .all(color: textColor),
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: .start,
                                  spacing: 8.0,
                                  children: usersNotInProject.map((addedUser) {
                                    return Text(addedUser.email);
                                  }).toList(),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 30),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/*
class AddUserDialogRow extends StatelessWidget {
  const AddUserDialogRow({
    super.key,
    required this.isMyself,
    required this.isMeAdmin,
    required this.inProject,
    required this.addedUser,
    required this.changeGroup,
  });

  final bool isMyself;
  final bool isMeAdmin;
  final bool inProject;
  final AddedUser addedUser;
  final void Function(GrantRole) changeGroup;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    final cs = theme.colorScheme;
    final tt = theme.textTheme;
    final willBeAdded = isMeAdmin && !inProject;

    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: willBeAdded
              ? Column(
                  mainAxisSize: .min,
                  crossAxisAlignment: .start,
                  children: [
                    Text(addedUser.email, overflow: .ellipsis),
                    Text(
                      "(will be added to project)",
                      style: tt.small.copyWith(fontStyle: .italic, color: cs.primary),
                    ),
                  ],
                )
              : Text(addedUser.email, overflow: .ellipsis),
        ),
        if (isMyself)
          Container(
            padding: const .symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(borderRadius: .circular(4)),
            child: Text(
              'You (${addedUser.role.displayName})',
              style: TextStyle(fontStyle: .italic, color: theme.colorScheme.primary),
            ),
          )
        else
          ShadSelect<GrantRole>(
            initialValue: addedUser.role,
            selectedOptionBuilder: (context, selected) => Text(selected.displayName),
            onChanged: (role) {
              if (role != null) changeGroup(role);
            },
            options: [
              ShadOption(value: GrantRole.nonOwner, child: Text(GrantRole.nonOwner.displayName)),
              ShadOption(value: GrantRole.owner, child: Text(GrantRole.owner.displayName)),
            ],
          ),
      ],
    );
  }
}
*/

Future<void> showUpdateRoomPermsDialog(BuildContext context, {required String projectId, required Room room}) async {
  if (context.mounted == false) return;

  return showShadDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final mode = ValueNotifier<_View>(_View.permissions);

      return ValueListenableBuilder<_View>(
        valueListenable: mode,
        builder: (context, view, _) {
          switch (view) {
            case _View.permissions:
              return _PermissionDialog(
                room: room,
                projectId: projectId,
                title: 'Update room permissions',
                description: 'Adjust who can manage settings and members for this room.',
                onAddUser: () => mode.value = _View.addUser,
              );
            case _View.addUser:
              return AddUserDialog(
                projectId: projectId,
                room: room,
                title: 'Invite user',
                description: 'Invite someone by email to join this room.',
                onBack: () => mode.value = _View.permissions,
              );
          }
        },
      );
    },
  );
}

Future<void> showAddUserToRoomDialog(BuildContext context, {required String projectId, required Room room}) async {
  if (context.mounted == false) return;

  return showShadDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AddUserDialog(
        projectId: projectId,
        room: room,
        title: 'Invite user',
        description: 'Invite someone by email to join this room.',
        onSaved: () {
          Navigator.of(context).pop();
        },
      );
    },
  );
}
