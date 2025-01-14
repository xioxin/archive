import '../../../archive_async.dart';
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
  int fileNameLength = 0;
  int extraLength = 0;
  int commentLength = 0;

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
      fileNameLength = await input.readUint16();
      extraLength = await input.readUint16();
      commentLength = await input.readUint16();
      diskNumberStart = await input.readUint16();
      internalFileAttributes = await input.readUint16();
      externalFileAttributes = await input.readUint32();
      localHeaderOffset = await input.readUint32();

      if (fileNameLength > 0) {
        filename = await input.readString(size: fileNameLength);
      }

      if (extraLength > 0) {
        InputStreamAsync extra = input.readBytes(extraLength);
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

      if (commentLength > 0) {
        fileComment = await input.readString(size: commentLength);
      }

//      if (bytes != null) {
//        bytes.offset = localHeaderOffset;
//        file = ZipFileAsync(bytes, this, password);
//      }
    }
  }

  String toString() => filename;

  ZipFileHeaderAsync.formJson(Map<String, dynamic> data) {
    versionMadeBy = data['versionMadeBy'] ?? 0;
    versionNeededToExtract = data['versionNeededToExtract'] ?? 0;
    generalPurposeBitFlag = data['compressionMethod'] ?? 0;
    compressionMethod = data['compressionMethod'] ?? 0;
    lastModifiedFileTime = data['lastModifiedFileTime'] ?? 0;
    lastModifiedFileDate = data['lastModifiedFileDate'] ?? 0;
    crc32 = data['crc32'] ?? 0;
    compressedSize = data['compressedSize'] ?? 0;
    uncompressedSize = data['uncompressedSize'] ?? 0;
    diskNumberStart = data['diskNumberStart'] ?? 0;
    internalFileAttributes = data['internalFileAttributes'] ?? 0;
    externalFileAttributes = data['externalFileAttributes'] ?? 0;
    localHeaderOffset = data['localHeaderOffset'] ?? 0;
    filename = data['filename'] ?? '';
    extraField = data['extraField'].cast<int>() as List<int> ?? [];
    fileNameLength = data['fileNameLength'] ?? 0;
    extraLength = data['extraLength'] ?? 0;
    commentLength = data['commentLength'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'versionMadeBy': versionMadeBy,
      'versionNeededToExtract': versionNeededToExtract,
      'generalPurposeBitFlag': generalPurposeBitFlag,
      'compressionMethod': compressionMethod,
      'lastModifiedFileTime': lastModifiedFileTime,
      'lastModifiedFileDate': lastModifiedFileDate,
      'crc32': crc32,
      'compressedSize': compressedSize,
      'uncompressedSize': uncompressedSize,
      'diskNumberStart': diskNumberStart,
      'internalFileAttributes': internalFileAttributes,
      'externalFileAttributes': externalFileAttributes,
      'localHeaderOffset': localHeaderOffset,
      'filename': filename,
      'extraField': extraField,
      'fileNameLength': fileNameLength,
      'extraLength': extraLength,
      'commentLength': commentLength,
    };
  }


  ZipFileHeader getSync() {
    final header = ZipFileHeader();
    header.versionMadeBy = versionMadeBy;
    header.versionNeededToExtract = versionNeededToExtract;
    header.generalPurposeBitFlag = generalPurposeBitFlag;
    header.compressionMethod = compressionMethod;
    header.lastModifiedFileTime = lastModifiedFileTime;
    header.lastModifiedFileDate = lastModifiedFileDate;
    header.crc32 = crc32;
    header.compressedSize = compressedSize;
    header.uncompressedSize = uncompressedSize;
    header.diskNumberStart = diskNumberStart;
    header.internalFileAttributes = internalFileAttributes;
    header.externalFileAttributes = externalFileAttributes;
    header.localHeaderOffset = localHeaderOffset;
    header.filename = filename;
    header.extraField = extraField;


    return header;
  }

}
