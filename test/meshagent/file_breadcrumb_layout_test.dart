import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/meshagent/file_breadcrumb_layout.dart';

void main() {
  const segments = [
    FileBreadcrumbSegment(label: 'Files', path: ''),
    FileBreadcrumbSegment(label: 'agents', path: 'agents'),
    FileBreadcrumbSegment(label: 'assistant', path: 'agents/assistant'),
    FileBreadcrumbSegment(label: 'threads', path: 'agents/assistant/threads'),
    FileBreadcrumbSegment(label: 'heartbeats', path: 'agents/assistant/threads/heartbeats'),
  ];

  test('keeps all breadcrumbs visible when they fit', () {
    final layout = computeFileBreadcrumbLayout(
      segments: segments,
      segmentWidths: const [80, 80, 90, 80, 100],
      maxWidth: 600,
      separatorWidth: 20,
      collapseButtonWidth: 48,
    );

    expect(layout.isCollapsed, isFalse);
    expect(layout.hiddenSegments, isEmpty);
    expect(layout.visibleSegments.map((segment) => segment.label).toList(), ['Files', 'agents', 'assistant', 'threads', 'heartbeats']);
  });

  test('hides the full prefix and keeps the largest visible suffix that fits', () {
    final layout = computeFileBreadcrumbLayout(
      segments: segments,
      segmentWidths: const [80, 80, 90, 80, 100],
      maxWidth: 268,
      separatorWidth: 20,
      collapseButtonWidth: 48,
    );

    expect(layout.isCollapsed, isTrue);
    expect(layout.hiddenSegments.map((segment) => segment.label).toList(), ['Files', 'agents', 'assistant']);
    expect(layout.visibleSegments.map((segment) => segment.label).toList(), ['threads', 'heartbeats']);
  });

  test('falls back to the last breadcrumb when only one visible item can fit', () {
    final layout = computeFileBreadcrumbLayout(
      segments: segments,
      segmentWidths: const [80, 80, 90, 80, 100],
      maxWidth: 150,
      separatorWidth: 20,
      collapseButtonWidth: 48,
    );

    expect(layout.isCollapsed, isTrue);
    expect(layout.hiddenSegments.map((segment) => segment.label).toList(), ['Files', 'agents', 'assistant', 'threads']);
    expect(layout.visibleSegments.map((segment) => segment.label).toList(), ['heartbeats']);
  });
}
