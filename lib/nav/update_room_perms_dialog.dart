import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:powerboards/ui/adaptive_text_selection_toolbar.dart';
import 'package:powerboards/ui/powerboards_mobile_field_suggestion_menu.dart';
import 'package:powerboards/ui/powerboards_adaptive_input.dart';
import 'package:powerboards/ui/powerboards_shad_dialog.dart';
import 'package:flutter_solidart/flutter_solidart.dart';

import 'package:meshagent/meshagent.dart';
import 'package:meshagent_flutter_auth/meshagent_flutter_auth.dart';

import 'package:powerboards/meshagent/grant.dart';
import 'package:powerboards/meshagent/user_builder.dart';
import 'package:powerboards/meshagent/meshagent.dart';
import 'package:powerboards/ui/adaptive_shad_context_menu.dart';
import 'package:powerboards/ui/avatar_menu_button.dart';
import 'package:powerboards/theme/theme.dart';
import 'package:meshagent_flutter_shadcn/forms/email_address.dart';
import 'package:meshagent_flutter_shadcn/forms/select_users.dart';

enum _View { permissions, addUser }

enum _LoadingState { loading, loaded }

enum _MobileSuggestionMenuDirection { above, below }

bool _usesMobileDialogLayout(BuildContext context) => powerboardsUsesNativeMobileDialogLayout(context);

bool _usesMobileLandscapeDialogLayout(BuildContext context) => powerboardsUsesLandscapeMobileDialogLayout(context);

double _desktopTaskDialogHeight(BoxConstraints constraints) {
  final maxHeight = constraints.maxHeight;
  if (!maxHeight.isFinite) {
    return 600.0;
  }

  return (maxHeight - 100.0).clamp(0.0, 600.0).toDouble();
}

double _desktopTaskDialogWidth(BoxConstraints constraints) {
  final maxWidth = constraints.maxWidth;
  if (!maxWidth.isFinite) {
    return 1024.0;
  }

  return (maxWidth - 100.0).clamp(512.0, 1024.0).toDouble();
}

BoxConstraints? _desktopTaskDialogConstraints(BuildContext context, BoxConstraints constraints) {
  if (_usesMobileDialogLayout(context)) {
    return null;
  }

  final width = _desktopTaskDialogWidth(constraints);
  final height = _desktopTaskDialogHeight(constraints);
  return BoxConstraints(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height);
}

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
    final items = [
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
    ];

    final triggerButton = ShadButton.ghost(
      onPressed: _usesMobileDialogLayout(context) ? controller.toggle : controller.show,
      padding: EdgeInsets.zero,
      child: const SizedBox(width: 40, height: 30, child: Icon(LucideIcons.settings, size: 16)),
    );

    if (!_usesMobileDialogLayout(context)) {
      return ShadContextMenuRegion(
        controller: controller,
        constraints: const BoxConstraints(minWidth: 220),
        items: items,
        child: triggerButton,
      );
    }

    return AdaptiveShadContextMenu(
      controller: controller,
      constraints: const BoxConstraints(minWidth: 220),
      estimatedMenuWidth: 220,
      estimatedMenuHeight: (widget.role == GrantRole.owner || widget.role == GrantRole.nonOwner) ? 88 : 48,
      items: items,
      child: triggerButton,
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
    final cs = ShadTheme.of(context).colorScheme;
    final avatarInitials = userAvatarInitialsFromEmail(user.email);
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Row(
      crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: isMobile ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              UserAvatarCircle(initials: avatarInitials, variant: UserAvatarVariant.standard),
              const SizedBox(width: 18),
              Expanded(
                child: isMobile
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.email,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: powerboardsInterTextStyle(color: cs.foreground, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 6),
                          Text(grantSummary.role.displayName, style: TextStyle(color: cs.foreground)),
                        ],
                      )
                    : Text(
                        user.email,
                        overflow: TextOverflow.ellipsis,
                        style: powerboardsInterTextStyle(color: cs.foreground, fontWeight: FontWeight.w600),
                      ),
              ),
            ],
          ),
        ),
        if (!isMobile) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 90,
            child: Text(grantSummary.role.displayName, style: TextStyle(color: cs.foreground)),
          ),
        ] else ...[
          const SizedBox(width: 12),
        ],

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
    super.key,
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
      padding: const EdgeInsets.symmetric(vertical: 9),
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
    final sortedGrants = grants.values.where((g) => !isMe(g.userId)).toList()
      ..sort((a, b) => _grantToEmail(a).toLowerCase().compareTo(_grantToEmail(b).toLowerCase()));

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = _usesMobileDialogLayout(context);
        final permissionsList = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [if (myGrant != null) _userRowBuilder(context, myGrant!), ...sortedGrants.map((g) => _userRowBuilder(context, g))],
        );

        return PowerboardsShadDialog.task(
          scrollable: false,
          constraints: _desktopTaskDialogConstraints(context, constraints),
          title: Text(widget.title),
          description: Text(widget.description),
          mobileKeyboardBehavior: PowerboardsDialogMobileKeyboardBehavior.ignore,
          actions: [
            ShadButton.outline(onPressed: () => Navigator.of(context).pop(null), child: const Text('Close')),
            if (canEdit) ShadButton(onPressed: widget.onAddUser, child: const Text('Add user')),
          ],
          child: isMobile
              ? ScrollConfiguration(
                  behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                  child: (state == _LoadingState.loading)
                      ? const Center(child: CircularProgressIndicator())
                      : Padding(
                          padding: const EdgeInsets.only(top: powerboardsDialogScrollViewportVerticalInset),
                          child: permissionsList,
                        ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                    Expanded(
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: (state == _LoadingState.loading)
                            ? const Center(child: CircularProgressIndicator())
                            : SingleChildScrollView(child: permissionsList),
                      ),
                    ),
                    const SizedBox(height: powerboardsDialogScrollViewportVerticalInset),
                  ],
                ),
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

enum _InviteUserSuggestionState { projectMember, inviteAllowed, inviteBlocked }

class _InviteUserSuggestion {
  const _InviteUserSuggestion({
    required this.email,
    required this.label,
    required this.description,
    required this.state,
    this.supportingText,
  });

  final String email;
  final String label;
  final String description;
  final _InviteUserSuggestionState state;
  final String? supportingText;

  bool get isProjectUser => state == _InviteUserSuggestionState.projectMember;

  bool get canSelect => state != _InviteUserSuggestionState.inviteBlocked;
}

class _InviteUserMobileContextMenu extends StatefulWidget {
  const _InviteUserMobileContextMenu({required this.editableTextState});

  final EditableTextState editableTextState;

  @override
  State<_InviteUserMobileContextMenu> createState() => _InviteUserMobileContextMenuState();
}

class _InviteUserMobileContextMenuState extends State<_InviteUserMobileContextMenu> {
  bool _clipboardChecked = false;
  bool _hasClipboardText = false;

  @override
  void initState() {
    super.initState();
    _refreshClipboard();
  }

  @override
  void didUpdateWidget(covariant _InviteUserMobileContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editableTextState != widget.editableTextState) {
      _refreshClipboard();
    }
  }

  Future<void> _refreshClipboard() async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) {
      return;
    }

    setState(() {
      _clipboardChecked = true;
      _hasClipboardText = (clipboardData?.text?.trim().isNotEmpty ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final selection = widget.editableTextState.textEditingValue.selection;
    final hasSelection = selection.isValid && !selection.isCollapsed;

    if (!_clipboardChecked) {
      return const SizedBox.shrink();
    }

    final buttonItems = widget.editableTextState.contextMenuButtonItems
        .where((item) {
          return switch (item.type) {
            ContextMenuButtonType.cut || ContextMenuButtonType.copy => hasSelection,
            ContextMenuButtonType.paste => _hasClipboardText,
            ContextMenuButtonType.selectAll => false,
            _ => false,
          };
        })
        .toList(growable: false);

    if (buttonItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final fieldRenderBox = widget.editableTextState.context.findRenderObject() as RenderBox?;
    final fieldHeight = fieldRenderBox?.size.height ?? 44.0;
    final baseAnchor = widget.editableTextState.contextMenuAnchors.primaryAnchor;
    final belowFieldAnchor = Offset(baseAnchor.dx, baseAnchor.dy + fieldHeight + 12.0);

    return TextFieldTapRegion(
      groupId: widget.editableTextState.widget.groupId,
      child: FocusScope(
        canRequestFocus: false,
        child: AdaptiveTextSelectionToolbar.buttonItems(
          anchors: TextSelectionToolbarAnchors(primaryAnchor: belowFieldAnchor, secondaryAnchor: belowFieldAnchor),
          buttonItems: buttonItems,
        ),
      ),
    );
  }
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
  static const double _mobileSuggestionListMaxHeight = 224.0;
  static const double _mobileSuggestionMenuGap = 12.0;
  static const double _mobileSuggestionMenuViewportPadding = 12.0;
  static const double _mobileSuggestionMenuMinHeight = 72.0;
  static const double _mobileSuggestionTitleLineHeight = 24.0;
  static const int _initialMobileFocusMaxAttempts = 12;

  bool submitting = false;
  final selectedUsers = Signal<List<AddedUser>>([]);
  final controller = SelectUsersController();
  final textController = TextEditingController();
  final _mobileEmailFocusNode = FocusNode();
  final _mobileSuggestionsAnchorKey = GlobalKey();
  final _mobileSuggestionsGroupId = Object();
  int _initialMobileFocusRequestId = 0;
  bool _initialMobileFocusScheduled = false;

  late final projectUsersMap = Resource<Map<String, User>>(lazy: false, () async {
    final client = getMeshagentClient();

    final results = await client.getUsersInProject(widget.projectId);
    final users = results.map((json) => User.fromJson(json)).toList();

    return {for (final u in users) u.email.toLowerCase(): u};
  });

  late final grants = Resource<Map<String, GrantSummary>>(lazy: false, () {
    return roomGrantSummaries(projectId: widget.projectId, roomName: widget.room.name);
  });

  void _scheduleInitialMobileFocus() {
    if (_initialMobileFocusScheduled) {
      return;
    }

    _initialMobileFocusScheduled = true;
    final requestId = ++_initialMobileFocusRequestId;
    unawaited(_requestInitialMobileFocusUntilFocused(requestId, remainingAttempts: _initialMobileFocusMaxAttempts));
  }

  Future<void> _requestInitialMobileFocusUntilFocused(int requestId, {required int remainingAttempts}) async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || requestId != _initialMobileFocusRequestId || !_usesMobileDialogLayout(context) || _mobileEmailFocusNode.hasFocus) {
      return;
    }

    final editableTextState = _findEditableTextState(_mobileEmailFocusNode.context);
    if (editableTextState != null && _mobileEmailFocusNode.canRequestFocus) {
      editableTextState.requestKeyboard();
    }

    final focusContext = _mobileEmailFocusNode.context;
    if (!_mobileEmailFocusNode.hasFocus && focusContext != null && focusContext.mounted && _mobileEmailFocusNode.canRequestFocus) {
      FocusScope.of(focusContext).requestFocus(_mobileEmailFocusNode);
    }

    if (_mobileEmailFocusNode.hasFocus || remainingAttempts <= 1) {
      return;
    }

    unawaited(_requestInitialMobileFocusUntilFocused(requestId, remainingAttempts: remainingAttempts - 1));
  }

  EditableTextState? _findEditableTextState(BuildContext? rootContext) {
    if (rootContext == null) {
      return null;
    }

    EditableTextState? result;

    void visit(Element element) {
      if (result != null) {
        return;
      }

      if (element case StatefulElement(state: final EditableTextState editableTextState)) {
        result = editableTextState;
        return;
      }

      element.visitChildElements(visit);
    }

    rootContext.visitChildElements(visit);
    return result;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_usesMobileDialogLayout(context)) {
      _scheduleInitialMobileFocus();
    }
  }

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
    _mobileEmailFocusNode.dispose();

    super.dispose();
  }

  List<AddedUser> _updatedSelectedUsers(
    Iterable<String> emails, {
    required Map<String, User> projectUsersMap,
    required Map<String, GrantSummary> roomGrants,
  }) {
    final existingUsers = {for (final user in selectedUsers.value) user.email.toLowerCase(): user};
    final dedupedEmails = <String>[];
    final seenEmails = <String>{};

    for (final rawEmail in emails) {
      final email = rawEmail.trim();
      final normalizedEmail = email.toLowerCase();
      if (email.isEmpty || !seenEmails.add(normalizedEmail)) {
        continue;
      }
      dedupedEmails.add(email);
    }

    return dedupedEmails
        .map((email) {
          final normalizedEmail = email.toLowerCase();
          final existingUser = existingUsers[normalizedEmail];
          if (existingUser != null) {
            return existingUser;
          }

          final projectUser = projectUsersMap[normalizedEmail];
          if (projectUser == null) {
            return AddedUser(email: email, role: GrantRole.nonOwner);
          }

          final currentGrant = roomGrants[projectUser.id];
          return AddedUser(email: email, role: currentGrant?.role ?? GrantRole.nonOwner);
        })
        .toList(growable: false);
  }

  void _setSelectedUsersFromEmails(
    Iterable<String> emails, {
    required Map<String, User> projectUsersMap,
    required Map<String, GrantSummary> roomGrants,
  }) {
    selectedUsers.value = _updatedSelectedUsers(emails, projectUsersMap: projectUsersMap, roomGrants: roomGrants);
  }

  void _updateInputFocusAfterSelectionChange() {
    if (!mounted) {
      return;
    }

    if (_usesMobileDialogLayout(context)) {
      _mobileEmailFocusNode.unfocus();
      return;
    }

    _mobileEmailFocusNode.requestFocus();
  }

  bool _isCurrentProjectAdmin(Map<String, User> projectUsersMap) {
    final myUser = MeshagentAuth.current.getUser();
    final myUserId = (myUser?['id'] as String?) ?? '';
    final me = projectUsersMap.values.firstWhereOrNull((u) => u.id == myUserId);
    return me?.isAdmin ?? false;
  }

  void _showInviteBlockedToast(Iterable<String> emails) {
    final blockedEmails = emails.toList(growable: false);
    if (blockedEmails.isEmpty) {
      return;
    }

    final toaster = ShadToaster.maybeOf(context);
    if (toaster == null) {
      return;
    }

    final plural = blockedEmails.length > 1;
    final message = plural
        ? 'Ask a project admin to add these users to the project before inviting them to this room.'
        : 'Ask a project admin to add this user to the project before inviting them to this room.';
    toaster.show(ShadToast.destructive(description: Text(message)));
  }

  void _addEmailToSelection(String email, {required Map<String, User> projectUsersMap, required Map<String, GrantSummary> roomGrants}) {
    _setSelectedUsersFromEmails(
      [...selectedUsers.value.map((user) => user.email), email],
      projectUsersMap: projectUsersMap,
      roomGrants: roomGrants,
    );
    textController.clear();
    _updateInputFocusAfterSelectionChange();
  }

  void _removeEmailFromSelection(
    String email, {
    required Map<String, User> projectUsersMap,
    required Map<String, GrantSummary> roomGrants,
  }) {
    _setSelectedUsersFromEmails(
      selectedUsers.value.where((user) => user.email.toLowerCase() != email.toLowerCase()).map((user) => user.email),
      projectUsersMap: projectUsersMap,
      roomGrants: roomGrants,
    );
    if (mounted) {
      _mobileEmailFocusNode.requestFocus();
    }
  }

  bool _submitEmailsFromText(String rawText, {required Map<String, User> projectUsersMap, required Map<String, GrantSummary> roomGrants}) {
    final parsedEmails = parseEmailList(
      rawText,
    ).map((address) => address.sanitizedAddress.trim()).where(SelectUsersController.emailRegex.hasMatch).toList(growable: false);
    if (parsedEmails.isEmpty) {
      return false;
    }

    final isCurrentUserAdmin = _isCurrentProjectAdmin(projectUsersMap);
    final allowedEmails = <String>[];
    final blockedEmails = <String>[];

    for (final email in parsedEmails) {
      final normalizedEmail = email.toLowerCase();
      if (!isCurrentUserAdmin && !projectUsersMap.containsKey(normalizedEmail)) {
        blockedEmails.add(email);
        continue;
      }
      allowedEmails.add(email);
    }

    if (blockedEmails.isNotEmpty) {
      _showInviteBlockedToast(blockedEmails);
    }

    if (allowedEmails.isEmpty) {
      return false;
    }

    _setSelectedUsersFromEmails(
      [...selectedUsers.value.map((user) => user.email), ...allowedEmails],
      projectUsersMap: projectUsersMap,
      roomGrants: roomGrants,
    );

    if (blockedEmails.isEmpty) {
      textController.clear();
    } else {
      final blockedEmailText = blockedEmails.join(', ');
      textController.value = TextEditingValue(
        text: blockedEmailText,
        selection: TextSelection.collapsed(offset: blockedEmailText.length),
      );
      if (mounted) {
        _mobileEmailFocusNode.requestFocus();
      }
      return true;
    }

    _updateInputFocusAfterSelectionChange();
    return true;
  }

  List<_InviteUserSuggestion> _mobileSuggestions(Map<String, User> projectUsersMap) {
    final query = textController.text.trim();
    if (query.isEmpty) {
      return const [];
    }

    final selectedEmails = selectedUsers.value.map((user) => user.email.toLowerCase()).toSet();
    final queryLower = query.toLowerCase();
    final suggestions = <_InviteUserSuggestion>[];
    final isCurrentUserAdmin = _isCurrentProjectAdmin(projectUsersMap);

    for (final projectUser in projectUsersMap.values) {
      final email = projectUser.email;
      final emailLower = email.toLowerCase();
      if (selectedEmails.contains(emailLower) || !emailLower.contains(queryLower)) {
        continue;
      }

      suggestions.add(
        _InviteUserSuggestion(email: email, label: email, description: 'Project member', state: _InviteUserSuggestionState.projectMember),
      );
    }

    suggestions.sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));

    if (SelectUsersController.emailRegex.hasMatch(query) &&
        !selectedEmails.contains(queryLower) &&
        suggestions.every((suggestion) => suggestion.email.toLowerCase() != queryLower)) {
      final isProjectUser = projectUsersMap.containsKey(queryLower);
      final suggestionState = switch ((isProjectUser, isCurrentUserAdmin)) {
        (true, _) => _InviteUserSuggestionState.projectMember,
        (false, true) => _InviteUserSuggestionState.inviteAllowed,
        (false, false) => _InviteUserSuggestionState.inviteBlocked,
      };
      suggestions.insert(
        0,
        _InviteUserSuggestion(
          email: query,
          label: query,
          description: switch (suggestionState) {
            _InviteUserSuggestionState.projectMember => 'Project member',
            _InviteUserSuggestionState.inviteAllowed => 'Invite to project and room',
            _InviteUserSuggestionState.inviteBlocked => 'Not in project',
          },
          supportingText: switch (suggestionState) {
            _InviteUserSuggestionState.projectMember => null,
            _InviteUserSuggestionState.inviteAllowed =>
              'Not a member of this project yet. Adding them to the room also adds them to the project.',
            _InviteUserSuggestionState.inviteBlocked =>
              'Ask a project admin to add this user to the project before inviting them to this room.',
          },
          state: suggestionState,
        ),
      );
    }

    return suggestions;
  }

  Widget _buildMobileSuggestionsMenu(
    BuildContext context, {
    required List<_InviteUserSuggestion> suggestions,
    required Map<String, User> projectUsersMap,
    required Map<String, GrantSummary> roomGrants,
    required double width,
    required double maxHeight,
  }) {
    const menuBorderRadius = BorderRadius.all(Radius.circular(16));
    final theme = ShadTheme.of(context);
    final destructiveTextColor = theme.colorScheme.destructive;
    final destructiveSupportingColor = theme.colorScheme.destructive.withValues(alpha: .78);
    final showsInviteSuggestion = suggestions.any((suggestion) => suggestion.state != _InviteUserSuggestionState.projectMember);
    final menuBorderColor = showsInviteSuggestion ? destructiveTextColor.withValues(alpha: .6) : theme.colorScheme.border;
    final menuDecoration = BoxDecoration(
      color: theme.colorScheme.card,
      borderRadius: menuBorderRadius,
      border: Border.all(color: menuBorderColor),
      boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 8))],
    );

    Widget buildSuggestionIcon(_InviteUserSuggestion suggestion) {
      final iconColor = suggestion.state == _InviteUserSuggestionState.inviteBlocked
          ? destructiveTextColor
          : theme.colorScheme.foreground.withValues(alpha: .74);

      if (suggestion.state != _InviteUserSuggestionState.inviteBlocked) {
        return Icon(suggestion.isProjectUser ? LucideIcons.userRoundCheck : LucideIcons.userRoundPlus, size: 18, color: iconColor);
      }

      return SizedBox(
        width: 18,
        height: 18,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: Icon(LucideIcons.userRound, size: 18, color: iconColor)),
            Positioned(
              right: -2,
              bottom: -1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: theme.colorScheme.card, borderRadius: BorderRadius.circular(999)),
                child: Icon(LucideIcons.x, size: 9, color: destructiveTextColor),
              ),
            ),
          ],
        ),
      );
    }

    Widget buildSuggestionRow(int index) {
      final suggestion = suggestions[index];
      final primaryTextStyle = TextStyle(color: theme.colorScheme.foreground, fontWeight: FontWeight.w600, height: 1.15);

      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: suggestion.canSelect
            ? () {
                _addEmailToSelection(suggestion.email, projectUsersMap: projectUsersMap, roomGrants: roomGrants);
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: _mobileSuggestionTitleLineHeight,
                child: Center(child: buildSuggestionIcon(suggestion)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: _mobileSuggestionTitleLineHeight,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(suggestion.label, overflow: TextOverflow.ellipsis, maxLines: 1, style: primaryTextStyle),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.description,
                      style: TextStyle(
                        color: suggestion.isProjectUser ? theme.colorScheme.mutedForeground : destructiveTextColor,
                        fontWeight: suggestion.isProjectUser ? FontWeight.w400 : FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    if (suggestion.supportingText case final supportingText?) ...[
                      const SizedBox(height: 4),
                      Text(supportingText, style: TextStyle(color: destructiveSupportingColor, fontSize: 12, height: 1.3)),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return PowerboardsMobileFieldSuggestionMenu<_InviteUserSuggestion>(
      width: width,
      items: suggestions,
      groupId: _mobileSuggestionsGroupId,
      maxHeight: maxHeight,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: menuDecoration,
      itemBuilder: (context, suggestion, index) => buildSuggestionRow(index),
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Divider(height: 1, color: theme.colorScheme.border),
      ),
    );
  }

  (_MobileSuggestionMenuDirection, double) _mobileSuggestionMenuLayout() {
    final mediaQuery = MediaQuery.maybeOf(context);
    final anchorContext = _mobileSuggestionsAnchorKey.currentContext;
    final anchorRenderBox = anchorContext?.findRenderObject() as RenderBox?;
    if (mediaQuery == null || anchorRenderBox == null || !anchorRenderBox.hasSize) {
      return (_MobileSuggestionMenuDirection.below, _mobileSuggestionListMaxHeight);
    }

    final screenHeight = mediaQuery.size.height;
    final safeTop = mediaQuery.padding.top + _mobileSuggestionMenuViewportPadding;
    final visibleBottom = (screenHeight - mediaQuery.viewInsets.bottom - _mobileSuggestionMenuViewportPadding).clamp(0.0, screenHeight);
    final anchorOffset = anchorRenderBox.localToGlobal(Offset.zero);
    final anchorTop = anchorOffset.dy;
    final anchorBottom = anchorTop + anchorRenderBox.size.height;
    final spaceBelow = (visibleBottom - anchorBottom - _mobileSuggestionMenuGap).clamp(0.0, screenHeight).toDouble();
    final spaceAbove = (anchorTop - safeTop - _mobileSuggestionMenuGap).clamp(0.0, screenHeight).toDouble();
    final preferAbove = spaceBelow < _mobileSuggestionMenuMinHeight && spaceAbove > spaceBelow;
    final availableHeight = preferAbove ? spaceAbove : spaceBelow;

    return (
      preferAbove ? _MobileSuggestionMenuDirection.above : _MobileSuggestionMenuDirection.below,
      availableHeight.clamp(0.0, _mobileSuggestionListMaxHeight).toDouble(),
    );
  }

  Widget _buildMobileSelectedUserBadge(
    BuildContext context,
    AddedUser user, {
    required Map<String, User> projectUsersMap,
    required Map<String, GrantSummary> roomGrants,
  }) {
    final theme = ShadTheme.of(context);
    final isProjectMember = projectUsersMap.containsKey(user.email.toLowerCase());
    final removeIconColor = isProjectMember ? theme.colorScheme.background : theme.colorScheme.destructiveForeground;
    final child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: Text(user.email, overflow: TextOverflow.ellipsis)),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => _removeEmailFromSelection(user.email, projectUsersMap: projectUsersMap, roomGrants: roomGrants),
          child: Icon(LucideIcons.x, size: 14, color: removeIconColor),
        ),
      ],
    );

    if (isProjectMember) {
      return ShadBadge(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: child);
    }

    return ShadBadge.destructive(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), child: child);
  }

  Future<void> onAdded() async {
    setState(() => submitting = true);

    try {
      await projectUsersMap.untilReady();

      final client = getMeshagentClient();

      // get users not in project
      final selected = selectedUsers.value;
      var projUsersMap = projectUsersMap.state.value ?? {};

      final usersToAddToProject = selected.where((u) => !projUsersMap.containsKey(u.email.toLowerCase())).toList(growable: false);
      final isMeAdmin = _isCurrentProjectAdmin(projUsersMap);

      if (selected.isEmpty) {
        setState(() => submitting = false);

        widget.onSaved?.call();
        widget.onBack?.call();

        return;
      }

      if (usersToAddToProject.isNotEmpty) {
        if (isMeAdmin) {
          // Add project membership first so the room-grant step sees the latest state.
          for (final user in usersToAddToProject) {
            await client.addUserToProjectByEmail(widget.projectId, user.email, inviteRedirectUrl: MeshagentConfig.current!.appUrl);
          }

          projectUsersMap.refresh();
          await projectUsersMap.untilReady();
          projUsersMap = projectUsersMap.state.value ?? projUsersMap;
        } else {
          if (!mounted) return;

          final emails = usersToAddToProject.map((u) => u.email).join(', ');
          final plural = usersToAddToProject.length > 1;

          final cont = await showPowerboardsAlertDialog<bool>(
            context: context,
            builder: (context) => PowerboardsShadDialog.compactAlert(
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

      final roomGrantsMap = grants.state.value ?? {};
      final usersInRoomMap = <String, GrantSummary>{};
      for (final user in projUsersMap.values) {
        final grant = roomGrantsMap[user.id];
        if (grant != null) {
          usersInRoomMap[user.email.toLowerCase()] = grant;
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
            inviteRedirectUrl: MeshagentConfig.current!.appUrl,
          );
        }),
      );

      widget.onSaved?.call();
      widget.onBack?.call();
    } catch (e) {
      if (!mounted) return;

      await showPowerboardsAlertDialog(
        context: context,
        builder: (context) {
          return PowerboardsShadDialog.compactAlert(
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
    final inputLabelStyle = powerboardsFieldLabelTextStyle(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = _usesMobileDialogLayout(context);

        final desktopFormBody = SignalBuilder(
          builder: (context, _) {
            final selected = selectedUsers.value;

            final roomGrants = grants.state.value ?? {};
            final projUsersMap = projectUsersMap.state.value ?? {};

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Enter email address', style: inputLabelStyle),
                const SizedBox(height: 8),
                SelectUsers(
                  autofocus: true,
                  projectEmails: projUsersMap.values.map((user) => user.email).toList(),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                  style: TextStyle(fontWeight: FontWeight.bold, color: textColor, height: 1.4),
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
                            border: ShadBorder.all(color: textColor),
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
        );

        final mobileFormBody = SignalBuilder(
          builder: (context, _) {
            final selected = selectedUsers.value;
            final roomGrants = grants.state.value ?? {};
            final projUsersMap = projectUsersMap.state.value ?? {};
            final showsLandscapeRotatePrompt = _usesMobileLandscapeDialogLayout(context);

            final mobileSelectionContent = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (selected.isNotEmpty) ...[
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final user in selected)
                        _buildMobileSelectedUserBadge(context, user, projectUsersMap: projUsersMap, roomGrants: roomGrants),
                    ],
                  ),
                  const SizedBox(height: 18),
                ],
              ],
            );

            Widget buildLandscapeRotatePrompt() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.smartphone, size: 22, color: theme.colorScheme.foreground.withValues(alpha: .78)),
                  const SizedBox(height: 14),
                  Text(
                    'Rotate to portrait to add users comfortably.',
                    style: theme.textTheme.large.copyWith(color: theme.colorScheme.foreground, fontWeight: FontWeight.w600),
                  ),
                ],
              );
            }

            Widget buildTopSection() {
              if (showsLandscapeRotatePrompt) {
                return buildLandscapeRotatePrompt();
              }

              return AnimatedBuilder(
                animation: Listenable.merge([textController, _mobileEmailFocusNode]),
                builder: (context, _) {
                  final suggestions = _mobileSuggestions(projUsersMap);
                  final showsSuggestionsMenu = _mobileEmailFocusNode.hasFocus && suggestions.isNotEmpty;
                  final helperTextStyle = theme.textTheme.muted.copyWith(color: theme.colorScheme.mutedForeground);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Enter email address', style: inputLabelStyle),
                      const SizedBox(height: 8),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final (menuDirection, menuMaxHeight) = _mobileSuggestionMenuLayout();
                          final menuAnchor = switch (menuDirection) {
                            _MobileSuggestionMenuDirection.below => ShadAnchor(
                              childAlignment: Alignment.topLeft,
                              overlayAlignment: Alignment.bottomLeft,
                              offset: Offset(0, _mobileSuggestionMenuGap),
                            ),
                            _MobileSuggestionMenuDirection.above => ShadAnchor(
                              childAlignment: Alignment.bottomLeft,
                              overlayAlignment: Alignment.topLeft,
                              offset: Offset(0, -_mobileSuggestionMenuGap),
                            ),
                          };

                          return ShadPortal(
                            visible: showsSuggestionsMenu && menuMaxHeight > 0,
                            anchor: menuAnchor,
                            portalBuilder: (context) {
                              return _buildMobileSuggestionsMenu(
                                context,
                                suggestions: suggestions,
                                projectUsersMap: projUsersMap,
                                roomGrants: roomGrants,
                                width: constraints.maxWidth,
                                maxHeight: menuMaxHeight,
                              );
                            },
                            child: TextFieldTapRegion(
                              key: _mobileSuggestionsAnchorKey,
                              groupId: _mobileSuggestionsGroupId,
                              child: PowerboardsAdaptiveInput(
                                controller: textController,
                                focusNode: _mobileEmailFocusNode,
                                groupId: _mobileSuggestionsGroupId,
                                autofocus: true,
                                textInputAction: TextInputAction.done,
                                keyboardType: TextInputType.emailAddress,
                                autocorrect: false,
                                enableSuggestions: true,
                                scrollPadding: const EdgeInsets.fromLTRB(20, 20, 20, 55),
                                placeholder: const Text('Type an email'),
                                contextMenuBuilder: (context, editableTextState) => powerboardsUsesSystemAdaptiveTextSelectionToolbar()
                                    ? powerboardsAdaptiveInputContextMenuBuilder(context, editableTextState)
                                    : _InviteUserMobileContextMenu(editableTextState: editableTextState),
                                onPressedOutside: (_) {
                                  _mobileEmailFocusNode.unfocus();
                                },
                                onChanged: (value) {
                                  final shouldCommitParsedEmails =
                                      value.contains(',') || value.contains(';') || value.endsWith(' ') || value.endsWith('\n');
                                  if (shouldCommitParsedEmails) {
                                    _submitEmailsFromText(value, projectUsersMap: projUsersMap, roomGrants: roomGrants);
                                  }
                                },
                                onSubmitted: (value) {
                                  _submitEmailsFromText(value, projectUsersMap: projUsersMap, roomGrants: roomGrants);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                      if (selected.isEmpty) ...[const SizedBox(height: 24), Text(widget.description, style: helperTextStyle)],
                    ],
                  );
                },
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [buildTopSection(), const SizedBox(height: 24), mobileSelectionContent],
            );
          },
        );

        final dialog = PowerboardsShadDialog.formTask(
          scrollable: false,
          constraints: _desktopTaskDialogConstraints(context, constraints),
          title: Text(widget.title),
          description: isMobile ? null : Padding(padding: .only(bottom: 15.0), child: Text(widget.description)),
          actions: [
            if (widget.onBack != null)
              ShadButton.outline(
                onPressed: widget.onBack,
                leading: isMobile ? null : const Icon(LucideIcons.arrowLeft, size: 16),
                child: const Text('Back'),
              ),
            ShadButton(
              onPressed: onAdded,
              enabled: !submitting && (!(_usesMobileLandscapeDialogLayout(context)) || selectedUsers.value.isNotEmpty),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: submitting
                    ? [
                        const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                        const SizedBox(width: 8),
                        const Text('Saving...'),
                      ]
                    : [const Text('Save')],
              ),
            ),
          ],
          mobilePresentation: isMobile ? PowerboardsDialogMobilePresentation.fullScreen : PowerboardsDialogMobilePresentation.flowSheet,
          mobileFlowBodyBehavior: isMobile
              ? PowerboardsDialogMobileFlowBodyBehavior.formScrollable
              : PowerboardsDialogMobileFlowBodyBehavior.fill,
          child: isMobile
              ? Padding(padding: const EdgeInsets.only(bottom: 12), child: mobileFormBody)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        child: ConstrainedBox(constraints: const BoxConstraints(minHeight: 415), child: desktopFormBody),
                      ),
                    ),
                  ],
                ),
        );

        return dialog;
      },
    );
  }
}

class _UpdateRoomPermsFlow extends StatefulWidget {
  const _UpdateRoomPermsFlow({required this.projectId, required this.room});

  final String projectId;
  final Room room;

  @override
  State<_UpdateRoomPermsFlow> createState() => _UpdateRoomPermsFlowState();
}

class _UpdateRoomPermsFlowState extends State<_UpdateRoomPermsFlow> {
  _View view = _View.permissions;
  int permissionsVersion = 0;

  void _showPermissions() {
    setState(() {
      view = _View.permissions;
    });
  }

  void _showAddUser() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      view = _View.addUser;
    });
  }

  void _refreshPermissions() {
    setState(() {
      permissionsVersion += 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (view) {
      case _View.permissions:
        return _PermissionDialog(
          key: ValueKey('permissions-$permissionsVersion'),
          room: widget.room,
          projectId: widget.projectId,
          title: 'Update room permissions',
          description: 'Adjust who can manage settings and members for this room.',
          onAddUser: _showAddUser,
        );
      case _View.addUser:
        return AddUserDialog(
          projectId: widget.projectId,
          room: widget.room,
          title: 'Invite user',
          description: 'Invite someone by email to join this room.',
          onBack: _showPermissions,
          onSaved: _refreshPermissions,
        );
    }
  }
}

Future<void> showUpdateRoomPermsDialog(BuildContext context, {required String projectId, required Room room}) async {
  if (context.mounted == false) return;

  return showPowerboardsFlowDialog<void>(
    context: context,
    builder: (context) => _UpdateRoomPermsFlow(projectId: projectId, room: room),
  );
}

Future<void> showAddUserToRoomDialog(BuildContext context, {required String projectId, required Room room}) async {
  if (context.mounted == false) return;

  return showPowerboardsFlowDialog<void>(
    context: context,
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
