import 'package:archive/archive.dart';

import '../util/input_stream.dart';
import '../zlib/inflate.dart';


typedef Future<ArchiveFile> ArchiveFileFunction();

/// A file contained in an Archive.
class ArchiveFileAsync {

  static const int STORE = 0;
  static const int DEFLATE = 8;

  String name;

  /// The uncompressed size of the file
  int size = 0;
  int mode = 0;
  int ownerId = 0;
  int groupId = 0;
  int lastModTime = 0;
  bool isFile = true;
  bool isSymbolicLink = false;
  String nameOfLinkedFile = "";

  /// The crc32 checksum of the uncompressed content.
  int crc32;
  String comment;

  /// If false, this file will not be compressed when encoded to an archive
  /// format such as zip.
  bool compress = true;

  int get unixPermissions {
    return mode & 0x1FF;
  }

  ArchiveFileFunction getArchiveFile;
  ArchiveFile file;


  ArchiveFileAsync(this.name, this.size, content, [this._compressionType = STORE]) {
    if (content is List<int>) {
      _content = content;
      _rawContent = InputStream(_content);
    } else if (content is InputStream) {
      _rawContent = InputStream.from(content);
    }
  }

  ArchiveFileAsync.async(this.name,this.size, ArchiveFileFunction getArchiveFile, [this._compressionType = STORE]){
    _content = null;
    this.getArchiveFile = getArchiveFile;
  }

  Future<ArchiveFile> getAsyncFile() async {
    if(file != null) {
      return file;
    }else {
      file = await getArchiveFile();
      getArchiveFile = null;
      return file;
    }
  }

  ArchiveFileAsync.noCompress(this.name, this.size, content) {
    compress = false;
    if (content is List<int>) {
      _content = content;
      _rawContent = InputStream(_content);
    } else if (content is InputStream) {
      _rawContent = InputStream.from(content);
    }
  }

  ArchiveFileAsync.stream(this.name, this.size, content_stream) {
    compress = true;
    _content = content_stream;
    //_rawContent = content_stream;
    _compressionType = STORE;
  }

  /// Get the content of the file, decompressing on demand as necessary.
  dynamic get content {
    if (_content == null) {
      decompress();
    }
    return _content;
  }

  /// If the file data is compressed, decompress it.
  void decompress() {
    if (_content == null && _rawContent != null) {
      if (_compressionType == DEFLATE) {
        _content = Inflate.buffer(_rawContent, size).getBytes();
      } else {
        _content = _rawContent.toUint8List();
      }
      _compressionType = STORE;
    }
  }

  /// Is the data stored by this file currently compressed?
  bool get isCompressed => _compressionType != STORE;

  /// What type of compression is the raw data stored in
  int get compressionType => _compressionType;

  /// Get the content without decompressing it first.
  InputStream get rawContent => _rawContent;

  String toString() => name;

  int _compressionType;
  InputStream _rawContent;
  dynamic _content;

}
