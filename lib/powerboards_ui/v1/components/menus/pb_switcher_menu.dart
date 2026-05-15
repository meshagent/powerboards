import 'package:flutter/material.dart';

import 'pb_menu_card.dart';
import 'pb_menu_divider.dart';
import 'pb_menu_filter_field.dart';
import 'pb_menu_list.dart';
import 'pb_menu_option.dart';

class PbSwitcherMenuItem {
  const PbSwitcherMenuItem({required this.title, this.selected = false});

  final String title;
  final bool selected;
}

class PbSwitcherMenu extends StatelessWidget {
  const PbSwitcherMenu({
    super.key,
    required this.items,
    required this.actionLabel,
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
  final String actionLabel;
  final String filterPlaceholder;
  final TextEditingController? filterController;
  final ValueChanged<String>? onFilterChanged;
  final String? actionLeadingIconAssetName;
  final double actionLeadingIconTurns;
  final VoidCallback? onActionPressed;
  final ValueChanged<String>? onItemPressed;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: PbMenuCard(
        child: Column(
          children: [
            PbMenuFilterField(
              placeholder: filterPlaceholder,
              controller: filterController,
              onChanged: onFilterChanged,
            ),
            PbMenuList(
              children: [
                for (final item in items)
                  PbMenuOption(
                    title: item.title,
                    singleLine: true,
                    trailingIconAssetName: item.selected
                        ? 'circle-check-big'
                        : null,
                    onPressed: () => onItemPressed?.call(item.title),
                  ),
                const PbMenuDivider(),
                PbMenuOption(
                  title: actionLabel,
                  singleLine: true,
                  leadingIconAssetName: actionLeadingIconAssetName,
                  leadingIconTurns: actionLeadingIconTurns,
                  onPressed: onActionPressed,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
