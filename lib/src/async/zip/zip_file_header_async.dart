import '../../util/input_stream.dart';
import '../input_stream_async.dart';
import 'zip_file_async.dart';

class ZipFileHeaderAsync {
  static const int SIGNATURE = 0x02014b50;
  int versionMadeBy = 0; // 2 bytes
  int versionNeededToExtract = 0; // 2 bytes
  int generalPurposeBitFlag = 0; // 2 bytes
  int compressionMethod = 0; // 2 bytes
  int lastModifiedFileTime = 0; // 2 bytes
  int lastModifiedFileDate = 0; // 2 bytes
  int crc32; // 4 bytes
  int compressedSize; // 4 bytes
  int uncompressedSize; // 4 bytes
  int diskNumberStart; // 2 bytes
  int internalFileAttributes; // 2 bytes
  int externalFileAttributes; // 4 bytes
  int localHeaderOffset; // 4 bytes
  String filename = '';
  List<int> extraField = [];
  String fileComment = '';
  ZipFileAsync file;

  ZipFileHeaderAsync();

  init ([InputStreamAsync input, InputStreamAsync bytes, String password]) async {
    if (input != null) {
      versionMadeBy = await input.readUint16();
      versionNeededToExtract = await input.readUint16();
      generalPurposeBitFlag = await input.readUint16();
      compressionMethod = await input.readUint16();
      lastModifiedFileTime = await input.readUint16();
      lastModifiedFileDate = await input.readUint16();
      crc32 = await input.readUint32();
      compressedSize = await input.readUint32();
      uncompressedSize =  await input.readUint32();
      int fname_len = await input.readUint16();
      int extra_len = await input.readUint16();
      int comment_len = await input.readUint16();
      diskNumberStart = await input.readUint16();
      internalFileAttributes = await input.readUint16();
      externalFileAttributes = await input.readUint32();
      localHeaderOffset = await input.readUint32();

      if (fname_len > 0) {
        filename = await input.readString(size: fname_len);
      }

      if (extra_len > 0) {
        InputStreamAsync extra = input.readBytes(extra_len);
        extraField = await extra.toUint8List();

        int id = await extra.readUint16();
        int size = await extra.readUint16();
        if (id == 1) {
          // Zip64 extended information
          // Original
          // Size       8 bytes    Original uncompressed file size
          // Compressed
          // Size       8 bytes    Size of compressed data
          // Relative Header
          // Offset     8 bytes    Offset of local header record
          // Disk Start
          // Number     4 bytes    Number of the disk on which
          // this file starts
          if (size >= 8) {
            uncompressedSize = await extra.readUint64();
          }
          if (size >= 16) {
            compressedSize = await extra.readUint64();
          }
          if (size >= 24) {
            localHeaderOffset = await extra.readUint64();
          }
          if (size >= 28) {
            diskNumberStart = await extra.readUint32();
          }
        }
      }

      if (comment_len > 0) {
        fileComment = await input.readString(size: comment_len);
      }

//      if (bytes != null) {
//        bytes.offset = localHeaderOffset;
//        file = ZipFileAsync(bytes, this, password);
//      }
    }
  }



  String toString() => filename;
}
