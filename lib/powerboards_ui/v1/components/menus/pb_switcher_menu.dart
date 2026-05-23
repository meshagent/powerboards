import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pb_menu_card.dart';
import 'pb_menu_divider.dart';
import 'pb_menu_filter_field.dart';
import 'pb_menu_list.dart';
import 'pb_menu_option.dart';

class PbSwitcherMenuItem {
  const PbSwitcherMenuItem({required this.title, this.selected = false, this.onPressed});

  final String title;
  final bool selected;
  final VoidCallback? onPressed;
}

class PbSwitcherMenu extends StatefulWidget {
  const PbSwitcherMenu({
    super.key,
    required this.items,
    this.actionLabel,
    this.emptyLabel = 'No items',
    this.filterPlaceholder = 'Filter...',
    this.filterController,
    this.onFilterChanged,
    this.actionLeadingIconAssetName = 'plus',
    this.actionLeadingIconTurns = 0,
    this.onActionPressed,
    this.onItemPressed,
    this.width = 240,
  });

  final List<PbSwitcherMenuItem> items;
  final String? actionLabel;
  final String emptyLabel;
  final String filterPlaceholder;
  final TextEditingController? filterController;
  final ValueChanged<String>? onFilterChanged;
  final String? actionLeadingIconAssetName;
  final double actionLeadingIconTurns;
  final VoidCallback? onActionPressed;
  final ValueChanged<String>? onItemPressed;
  final double width;

  @override
  State<PbSwitcherMenu> createState() => _PbSwitcherMenuState();
}

class _PbSwitcherMenuState extends State<PbSwitcherMenu> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedActionLabel = widget.actionLabel?.trim();
    final showAction = resolvedActionLabel != null && resolvedActionLabel.isNotEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        final viewportHeight = MediaQuery.sizeOf(context).height;
        final maxMenuHeight = math.min(constraints.maxHeight.isFinite ? constraints.maxHeight : double.infinity, viewportHeight * (2 / 3));

        return SizedBox(
          width: widget.width,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxMenuHeight),
            child: PbMenuCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PbMenuFilterField(
                    placeholder: widget.filterPlaceholder,
                    controller: widget.filterController,
                    onChanged: widget.onFilterChanged,
                  ),
                  ScrollbarTheme(
                    data: ScrollbarTheme.of(context).copyWith(
                      thumbColor: const WidgetStatePropertyAll(Color.fromRGBO(17, 24, 39, 0.2)),
                      thickness: const WidgetStatePropertyAll(10),
                      radius: const Radius.circular(999),
                      minThumbLength: 36,
                      crossAxisMargin: 0,
                      mainAxisMargin: 0,
                    ),
                    child: Flexible(
                      fit: FlexFit.loose,
                      child: ScrollConfiguration(
                        behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
                        child: Scrollbar(
                          controller: _scrollController,
                          child: SingleChildScrollView(
                            controller: _scrollController,
                            primary: false,
                            child: Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: PbMenuList(
                                children: [
                                  if (widget.items.isEmpty)
                                    PbMenuOption(title: widget.emptyLabel, singleLine: true, state: PbMenuOptionVisualState.disabled)
                                  else
                                    for (final item in widget.items)
                                      PbMenuOption(
                                        title: item.title,
                                        singleLine: true,
                                        trailingIconAssetName: item.selected ? 'circle-check-big' : null,
                                        onPressed: item.onPressed ?? () => widget.onItemPressed?.call(item.title),
                                      ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showAction) ...[
                    const PbMenuDivider(),
                    PbMenuList(
                      children: [
                        PbMenuOption(
                          title: resolvedActionLabel,
                          singleLine: true,
                          leadingIconAssetName: widget.actionLeadingIconAssetName,
                          leadingIconTurns: widget.actionLeadingIconTurns,
                          onPressed: widget.onActionPressed,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
