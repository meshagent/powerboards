import 'package:flutter/material.dart';

import '../../theme/pb_colors.dart';
import '../../theme/pb_tokens.dart';
import '../../theme/pb_typography.dart';

class PbAgentEmailField extends StatefulWidget {
  const PbAgentEmailField({
    super.key,
    required this.controller,
    required this.domain,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String domain;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<PbAgentEmailField> createState() => _PbAgentEmailFieldState();
}

class _PbAgentEmailFieldState extends State<PbAgentEmailField> {
  late final FocusNode _focusNode;
  bool _hovered = false;

  String get _suffix {
    final normalizedDomain = widget.domain.trim();
    return normalizedDomain.startsWith('@') ? normalizedDomain : '@$normalizedDomain';
  }

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode()..addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focusNode.hasFocus;
    final focusHalo = PbColors.dynamicBorderStateSelected.withValues(alpha: 0.36);
    final outlineColor = focused ? PbColors.dynamicBorderStateSelected : PbColors.dynamicBorderSoft;

    return Semantics(
      textField: true,
      label: 'Agent email name before $_suffix',
      child: MouseRegion(
        cursor: SystemMouseCursors.text,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Transform.translate(
          offset: Offset(0, _hovered && !focused ? -1 : 0),
          child: AnimatedContainer(
            key: const ValueKey('agent-email-field-shell'),
            duration: PbMotion.state,
            curve: Curves.easeOut,
            height: 44,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: PbColors.dynamicSurfacePanel.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(PbRadii.medium),
              boxShadow: focused
                  ? [BoxShadow(color: focusHalo, blurRadius: 0, spreadRadius: 3), ...PbShadows.card]
                  : _hovered
                  ? PbShadows.stateHover
                  : null,
            ),
            foregroundDecoration: BoxDecoration(
              borderRadius: BorderRadius.circular(PbRadii.medium),
              border: Border.all(color: outlineColor),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      key: const ValueKey('agent-email-local-part'),
                      controller: widget.controller,
                      focusNode: _focusNode,
                      autofocus: widget.autofocus,
                      maxLines: 1,
                      maxLength: 48,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      autocorrect: false,
                      enableSuggestions: false,
                      onChanged: widget.onChanged,
                      onSubmitted: widget.onSubmitted,
                      cursorColor: PbColors.textPrimary,
                      style: PowerboardsTypography.small.copyWith(color: PbColors.textPrimary),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        counterText: '',
                        hintText: 'Enter',
                        hintStyle: PowerboardsTypography.small.copyWith(color: PbColors.textMuted),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    key: const ValueKey('agent-email-domain'),
                    height: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: PbColors.dynamicSurfaceStateSelected,
                      border: Border(left: BorderSide(color: PbColors.dynamicBorderStateSelected)),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(_suffix, maxLines: 1, style: PowerboardsTypography.small.copyWith(color: PbColors.dynamicCustomBlue)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
