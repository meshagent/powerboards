import 'package:flutter_test/flutter_test.dart';
import 'package:powerboards/powerboards_ui/v1/models/pb_attachment_file_metadata.dart';

void main() {
  test('resolves Powerboards-native file types from extensions', () {
    final thread = _resolved('Launch planning.thread');
    expect(thread.fileType, PbAttachmentFileType.thread);
    expect(thread.displayTitle, 'Launch planning');
    expect(thread.displayType, 'Thread');
    expect(thread.iconAssetName, 'file-thread');

    final transcript = _resolved('2026-06-01 12-40 PM.transcript');
    expect(transcript.fileType, PbAttachmentFileType.transcript);
    expect(transcript.displayTitle, '2026-06-01 12-40 PM');
    expect(transcript.displayType, 'Transcript');
    expect(thread.iconColor, transcript.iconColor);

    final widget = _resolved('Customer intake.widget');
    expect(widget.fileType, PbAttachmentFileType.widget);
    expect(widget.displayTitle, 'Customer intake.widget');
    expect(widget.displayType, 'Widget');
    expect(widget.iconAssetName, 'file-cog');
    expect(widget.iconColor, transcript.iconColor);

    expect(_resolved('Product brief.document').fileType, PbAttachmentFileType.document);
    expect(_resolved('Roadmap.presentation').fileType, PbAttachmentFileType.presentation);
    expect(_resolved('Moodboard.gallery').fileType, PbAttachmentFileType.image);
    expect(_resolved('Signup form.form').fileType, PbAttachmentFileType.document);
  });

  test('resolves explicit Powerboards-native file type keys after display names remove extensions', () {
    expect(_resolved('Launch planning', fileTypeKey: 'thread').fileType, PbAttachmentFileType.thread);
    expect(_resolved('June transcript', fileTypeKey: 'transcript').fileType, PbAttachmentFileType.transcript);
    expect(_resolved('Customer intake', fileTypeKey: 'widget').fileType, PbAttachmentFileType.widget);
  });
}

PbResolvedAttachmentMetadata _resolved(String title, {String? fileTypeKey}) {
  return PbResolvedAttachmentMetadata.resolve(title: title, explicitFileTypeKey: fileTypeKey);
}
