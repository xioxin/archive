import '../../archive_async.dart';
import 'archive_file_async.dart';
import 'dart:collection';

/// A collection of files
class ArchiveAsync extends IterableBase<ArchiveFileAsync> {

  InputStreamAsync input;

  /// The list of files in the archive.
  List<ArchiveFileAsync> files = [];

  /// A global comment for the archive.
  String comment;

  /// Add a file to the archive.
  void addFile(ArchiveFileAsync file) {
    files.add(file);
  }

  /// The number of files in the archive.
  int get length => files.length;

  /// Get a file from the archive.
  ArchiveFileAsync operator [](int index) => files[index];

  /// Find a file with the given [name] in the archive. If the file isn't found,
  /// null will be returned.
  ArchiveFileAsync findFile(String name) {
    for (ArchiveFileAsync f in files) {
      if (f.name == name) {
        return f;
      }
    }
    return null;
  }

  /// The number of files in the archive.
  int numberOfFiles() {
    return files.length;
  }

  /// The name of the file at the given [index].
  String fileName(int index) {
    return files[index].name;
  }

  /// The decompressed size of the file at the given [index].
  int fileSize(int index) {
    return files[index].size;
  }

  /// The decompressed data of the file at the given [index].
  List<int> fileData(int index) {
    return files[index].content;
  }

  ArchiveFileAsync get first => files.first;

  ArchiveFileAsync get last => files.last;

  bool get isEmpty => files.isEmpty;

  // Returns true if there is at least one element in this collection.
  bool get isNotEmpty => files.isNotEmpty;

  Iterator<ArchiveFileAsync> get iterator => files.iterator;

  destroy() {
    this.input.destroy();
    this.input = null;
    this.files.forEach((v) => v.destroy());
    this.files.clear();
  }
}
