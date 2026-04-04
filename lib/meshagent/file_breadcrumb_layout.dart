class FileBreadcrumbSegment {
  const FileBreadcrumbSegment({required this.label, required this.path});

  final String label;
  final String path;
}

class FileBreadcrumbLayout {
  const FileBreadcrumbLayout({required this.hiddenSegments, required this.visibleSegments});

  final List<FileBreadcrumbSegment> hiddenSegments;
  final List<FileBreadcrumbSegment> visibleSegments;

  bool get isCollapsed => hiddenSegments.isNotEmpty;
}

FileBreadcrumbLayout computeFileBreadcrumbLayout({
  required List<FileBreadcrumbSegment> segments,
  required List<double> segmentWidths,
  required double maxWidth,
  required double separatorWidth,
  required double collapseButtonWidth,
}) {
  if (segments.length != segmentWidths.length) {
    throw ArgumentError('segments and segmentWidths must have the same length');
  }

  if (segments.isEmpty || !maxWidth.isFinite) {
    return FileBreadcrumbLayout(hiddenSegments: const [], visibleSegments: List.unmodifiable(segments));
  }

  double suffixWidth(int startIndex) {
    var width = 0.0;
    for (var i = startIndex; i < segmentWidths.length; i++) {
      if (i > startIndex) {
        width += separatorWidth;
      }
      width += segmentWidths[i];
    }
    return width;
  }

  if (suffixWidth(0) <= maxWidth) {
    return FileBreadcrumbLayout(hiddenSegments: const [], visibleSegments: List.unmodifiable(segments));
  }

  for (var hiddenCount = 1; hiddenCount < segments.length; hiddenCount++) {
    final visibleWidth = suffixWidth(hiddenCount);
    final collapsedWidth = collapseButtonWidth + separatorWidth + visibleWidth;
    if (collapsedWidth <= maxWidth) {
      return FileBreadcrumbLayout(
        hiddenSegments: List.unmodifiable(segments.take(hiddenCount)),
        visibleSegments: List.unmodifiable(segments.skip(hiddenCount)),
      );
    }
  }

  return FileBreadcrumbLayout(
    hiddenSegments: List.unmodifiable(segments.take(segments.length - 1)),
    visibleSegments: List.unmodifiable(segments.skip(segments.length - 1)),
  );
}
