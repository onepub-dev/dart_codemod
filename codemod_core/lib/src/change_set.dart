import 'dart:io';

import 'package:source_span/source_span.dart';

import '../codemod_core.dart';

/// List of [Patch]es to be applied to [sourcePath]
class ChangeSet {
  ChangeSet(this.sourceFile, this.patches, {this.destinationPath});

  ChangeSet.fromPatchs(this.sourceFile, List<Patch> patches,
      {this.destinationPath}) {
    this.patches =
        patches.map((patch) => SourcePatch.from(patch, sourceFile)).toList();
  }
  late final List<SourcePatch> patches;
  final SourceFile sourceFile;
  final Path? destinationPath;

  /// Returns the result of applying all of the [patches]
  /// (insertions/deletions/replacements) to the contents of [sourceFile]
  /// as a String.
  /// [sourceFile] isn't modified as part of this operation.
  ///
  /// @see [applyAndSave]
  ///
  /// Throws an [Exception] if any two of the given [patches] overlap.
  String apply({bool skipOverlapping = false}) {
    final buffer = StringBuffer();
    final sortedPatches =
        patches.map((p) => SourcePatch.from(p, sourceFile)).toList()..sort();

    var lastEdgeOffset = 0;
    late Patch prev;
    for (final patch in sortedPatches) {
      if (patch.startOffset < lastEdgeOffset) {
        final cause = 'Previous patch:\n'
            '  $prev\n'
            '  Updated text: ${prev.updatedText}\n'
            'Overlapping patch:\n'
            '  $patch\n'
            '  Updated text: ${patch.updatedText}\n';

        if (skipOverlapping) {
          logger.warning('Skipping overlapping patch: $cause');
          continue;
        }
        throw Exception('''
Codemod terminated due to overlapping patch.
$cause
        ''');
      }

      // Write unmodified text from end of last patch to beginning of this patch
      buffer.write(sourceFile.getText(lastEdgeOffset, patch.startOffset));
      // Write the patched text (and do nothing with the original text, which is
      // effectively the same as replacing it)
      buffer.write(patch.updatedText);

      lastEdgeOffset = patch.endOffset;
      prev = patch;
    }

    buffer.write(sourceFile.getText(lastEdgeOffset));
    return buffer.toString();
  }

  /// Applies all of the [patches] (insertions/deletions/replacements) to the
  /// contents of [sourceFile] and writes the result to disk.
  ///
  /// Throws an [ArgumentError] if [sourceFile] has a null value for
  /// [SourceFile.url], as it is required to open the file and write the new
  /// contents.
  /// if [destPath] is passed then then [sourceFile] is left unchanged
  /// and the contents of [sourceFile] are written to [destPath] with
  /// the patches applied.
  void applyAndSave({String? destPath, bool skipOverlapping = false}) {
    if (patches.isEmpty) {
      return;
    }
    if (sourceFile.url == null) {
      throw ArgumentError('sourceFile.url cannot be null');
    }
    final updatedContents = apply(skipOverlapping: skipOverlapping);

    if (destPath == null) {
      File.fromUri(sourceFile.url!).writeAsStringSync(updatedContents);
    } else {
      File(destPath)
        ..createSync(recursive: true)
        ..writeAsStringSync(updatedContents);
    }
  }
}