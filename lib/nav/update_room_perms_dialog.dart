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
            final width = isMobile ? constraints.maxWidth : 512.0;
            final height = isMobile ? constraints.maxHeight : (constraints.maxHeight > 700.0 ? 600.0 : constraints.maxHeight - 100);

            return ShadDialog(
              scrollable: true,
              titlePinned: true,
              descriptionPinned: true,
              actionsPinned: true,
              constraints: BoxConstraints(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height),
              title: Text(widget.title),
              description: Text(widget.description),
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
                    : Padding(
                        padding: const .symmetric(vertical: 8.0),
                        child: Column(
                          mainAxisSize: .min,
                          crossAxisAlignment: .stretch,
                          children: [
                            if (myGrant != null) _userRowBuilder(context, myGrant!),

                            ...sortedGrants.map((g) => _userRowBuilder(context, g)),
                          ],
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

    try {
      await projectUsersMap.untilReady();

      final client = getMeshagentClient();

      // get users not in project
      final selected = selectedUsers.value;
      final projUsersMap = projectUsersMap.state.value ?? {};

      final usersToAddToProject = selected.where((u) => !projUsersMap.containsKey(u.email.toLowerCase()));

      final myUser = MeshagentAuth.current.getUser();
      final myUserId = (myUser?['id'] as String?) ?? '';
      final me = projUsersMap.values.firstWhereOrNull((u) => u.id == myUserId);
      final isMeAdmin = me?.isAdmin ?? false;

      final roomGrantsMap = grants.state.value ?? {};

      final usersInRoomMap = {};
      for (final user in projUsersMap.values) {
        final grants = roomGrantsMap[user.id];
        if (grants != null) {
          usersInRoomMap[user.email.toLowerCase()] = grants;
        }
      }

      if (selected.isEmpty) {
        setState(() => submitting = false);

        widget.onSaved?.call();
        widget.onBack?.call();

        return;
      }

      if (usersToAddToProject.isNotEmpty) {
        if (isMeAdmin) {
          // add users to project if needed
          await Future.wait(
            usersToAddToProject.map((u) => client.addUserToProjectByEmail(widget.projectId, u.email, canCreateRooms: true)),
          );
        } else {
          if (!mounted) return;

          final emails = usersToAddToProject.map((u) => u.email).join(', ');
          final plural = usersToAddToProject.length > 1;

          final cont = await showShadDialog<bool>(
            context: context,
            builder: (context) => ShadDialog.alert(
              title: plural ? Text('Users are not in project') : Text('User is not in project'),
              description: Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: RichText(
                  text: TextSpan(
                    style: TextStyle(height: 1.4),
                    children: [
                      TextSpan(text: plural ? 'The following users with emails ' : 'The user with email '),
                      TextSpan(
                        text: emails,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: plural
                            ? ' do not have access to the project. Only users who are already part of the project can be added to rooms. Please ask a project admin to add these users to the project first.'
                            : ' does not have access to the project. Only users who are already part of the project can be added to rooms. Please ask a project admin to add this user to the project first.',
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                ShadButton.outline(child: const Text('Cancel'), onPressed: () => Navigator.of(context).pop(false)),
                ShadButton(child: const Text('Continue'), onPressed: () => Navigator.of(context).pop(true)),
              ],
            ),
          );

          if (cont != true) {
            setState(() => submitting = false);

            return;
          }
        }
      }

      final Set<String> excludedUsers = isMeAdmin ? <String>{} : usersToAddToProject.map((u) => u.email.toLowerCase()).toSet();

      // add grants for all selected users
      await Future.wait(
        selected.map((u) {
          final lcEmail = u.email.toLowerCase();

          if (excludedUsers.contains(lcEmail)) {
            return Future.value();
          }

          if (usersInRoomMap.containsKey(lcEmail)) {
            return Future.value();
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

    return ShadResponsiveBuilder(
      builder: (context, breakpoint) {
        final isMobile = breakpoint == theme.breakpoints.tn;

        return LayoutBuilder(
          builder: (context, constraints) {
            final width = isMobile ? constraints.maxWidth : 512.0;
            final height = isMobile ? constraints.maxHeight : (constraints.maxHeight > 700.0 ? 600.0 : constraints.maxHeight - 100);

            return ShadDialog(
              scrollable: true,
              titlePinned: true,
              descriptionPinned: true,
              actionsPinned: true,
              constraints: BoxConstraints(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height),
              title: Text(widget.title),
              description: Padding(padding: .only(bottom: 15.0), child: Text(widget.description)),
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
                constraints: const BoxConstraints(minHeight: 415),
                child: SignalBuilder(
                  builder: (context, _) {
                    final selected = selectedUsers.value;

                    final roomGrants = grants.state.value ?? {};
                    final projUsersMap = projectUsersMap.state.value ?? {};

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
                                updated.add(AddedUser(email: email, role: GrantRole.nonOwner));
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
                            final usersNotInProject = items
                                .where((u) => !projUsersMap.containsKey(u.email.toLowerCase()))
                                .map((u) => u.email)
                                .join(', ');

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
                                  description: RichText(
                                    text: TextSpan(
                                      style: TextStyle(color: textColor),
                                      children: [
                                        TextSpan(
                                          text: 'The following email addresses',
                                          style: TextStyle(color: textColor, height: 1.4),
                                        ),
                                        TextSpan(
                                          text: ' ($usersNotInProject) ',
                                          style: TextStyle(fontWeight: .bold, color: textColor, height: 1.4),
                                        ),
                                        TextSpan(
                                          text: 'are not project members. Adding them to the room will add them as members to the project.',
                                          style: TextStyle(color: textColor, height: 1.4),
                                        ),
                                      ],
                                    ),
                                  ),
                                  decoration: ShadDecoration(
                                    color: backgroundColor,
                                    border: .all(color: textColor),
                                  ),
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
