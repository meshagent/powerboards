import 'package:flutter/material.dart';

import '../theme/pb_colors.dart';

enum PbAttachmentCategory { generic, businessDocument, code, media, archive, transcript }

enum PbAttachmentFileType {
  generic,
  archive,
  type,
  mediaGeneric,
  image,
  video,
  sound,
  music,
  businessGeneric,
  spreadsheet,
  document,
  presentation,
  codeGeneric,
  script,
  code,
  key,
  settings,
  transcript,
}

class PbAttachmentListItemData {
  const PbAttachmentListItemData({required this.title, required this.subtitle, required this.fileType});

  final String title;
  final String subtitle;
  final PbAttachmentFileType fileType;

  PbAttachmentCategory get category {
    return switch (fileType) {
      PbAttachmentFileType.generic => PbAttachmentCategory.generic,
      PbAttachmentFileType.archive || PbAttachmentFileType.type => PbAttachmentCategory.archive,
      PbAttachmentFileType.transcript => PbAttachmentCategory.transcript,
      PbAttachmentFileType.mediaGeneric ||
      PbAttachmentFileType.image ||
      PbAttachmentFileType.video ||
      PbAttachmentFileType.sound ||
      PbAttachmentFileType.music => PbAttachmentCategory.media,
      PbAttachmentFileType.businessGeneric ||
      PbAttachmentFileType.spreadsheet ||
      PbAttachmentFileType.document ||
      PbAttachmentFileType.presentation => PbAttachmentCategory.businessDocument,
      PbAttachmentFileType.codeGeneric ||
      PbAttachmentFileType.script ||
      PbAttachmentFileType.code ||
      PbAttachmentFileType.key ||
      PbAttachmentFileType.settings => PbAttachmentCategory.code,
    };
  }

  String get iconAssetName {
    return switch (fileType) {
      PbAttachmentFileType.generic => 'file',
      PbAttachmentFileType.archive => 'file-archive',
      PbAttachmentFileType.type => 'file-type-corner',
      PbAttachmentFileType.mediaGeneric => 'file',
      PbAttachmentFileType.image => 'file-image',
      PbAttachmentFileType.video => 'file-video-camera',
      PbAttachmentFileType.sound => 'file-volume',
      PbAttachmentFileType.music => 'file-music',
      PbAttachmentFileType.businessGeneric => 'file',
      PbAttachmentFileType.spreadsheet => 'file-spreadsheet',
      PbAttachmentFileType.document => 'file-text',
      PbAttachmentFileType.presentation => 'file-chart-pie',
      PbAttachmentFileType.codeGeneric => 'file',
      PbAttachmentFileType.script => 'file-braces-corner',
      PbAttachmentFileType.code => 'file-code-corner',
      PbAttachmentFileType.key => 'file-key',
      PbAttachmentFileType.settings => 'file-cog',
      PbAttachmentFileType.transcript => 'file-play',
    };
  }

  Color get iconColor {
    return switch (category) {
      PbAttachmentCategory.generic => PbColors.customGray,
      PbAttachmentCategory.businessDocument => PbColors.customBlue,
      PbAttachmentCategory.code => PbColors.customViolet,
      PbAttachmentCategory.media => PbColors.customTeal,
      PbAttachmentCategory.archive => PbColors.customAmber,
      PbAttachmentCategory.transcript => PbColors.customRose,
    };
  }
}
