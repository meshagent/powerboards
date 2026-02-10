import 'package:flutter/material.dart';

class _BannerItem {
  _BannerItem({required this.id, required this.banner, required this.height});

  final String id;
  final Widget banner;
  final double height;
}

class TopBanner extends StatefulWidget {
  const TopBanner({super.key, required this.child});

  final Widget child;

  @override
  State<StatefulWidget> createState() => TopBannerState();
}

class TopBannerState extends State<TopBanner> {
  final _banners = <_BannerItem>[];

  void showBanner({required String id, required Widget banner, double height = 50}) {
    final found = _banners.any((item) => item.id == id);

    if (!found) {
      setState(() {
        _banners.add(_BannerItem(id: id, banner: banner, height: height));
      });
    }
  }

  void hideBanner(String id) {
    setState(() {
      _banners.removeWhere((item) => item.id == id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final banner = _banners.isNotEmpty ? _banners.first : null;

    return Stack(
      children: [
        if (banner != null) ...[
          Positioned(key: ValueKey(banner.id), top: 0, left: 0, right: 0, height: banner.height, child: banner.banner),
        ],
        Positioned(key: const Key('child'), top: banner?.height ?? 0, left: 0, right: 0, bottom: 0, child: widget.child),
      ],
    );
  }
}
