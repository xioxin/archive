import '../../util/archive_exception.dart';
import '../../util/input_stream.dart';
import '../input_stream_async.dart';
import 'zip_file_header_async.dart';

class ZipDirectoryAsync {
  // End of Central Directory Record
  static const int SIGNATURE = 0x06054b50;
  static const int ZIP64_EOCD_LOCATOR_SIGNATURE = 0x07064b50;
  static const int ZIP64_EOCD_LOCATOR_SIZE = 20;
  static const int ZIP64_EOCD_SIGNATURE = 0x06064b50;
  static const int ZIP64_EOCD_SIZE = 56;

  int filePosition = -1;
  int numberOfThisDisk = 0; // 2 bytes
  int diskWithTheStartOfTheCentralDirectory = 0; // 2 bytes
  int totalCentralDirectoryEntriesOnThisDisk = 0; // 2 bytes
  int totalCentralDirectoryEntries = 0; // 2 bytes
  int centralDirectorySize; // 4 bytes
  int centralDirectoryOffset; // 2 bytes
  String zipFileComment = ''; // 2 bytes, n bytes
  // Central Directory
  List<ZipFileHeaderAsync> fileHeaders = [];

  ZipDirectoryAsync();

  read(InputStreamAsync input, {String password}) async {
    filePosition = await _findSignature(input);
    input.offset = filePosition;
    int signature = await input.readUint32(); // ignore: unused_local_variable
    numberOfThisDisk = await input.readUint16();
    diskWithTheStartOfTheCentralDirectory = await input.readUint16();
    totalCentralDirectoryEntriesOnThisDisk = await input.readUint16();
    totalCentralDirectoryEntries = await input.readUint16();
    centralDirectorySize = await input.readUint32();
    centralDirectoryOffset = await input.readUint32();

    int len = await input.readUint16();
    if (len > 0) {
      zipFileComment = await input.readString(size: len);
    }

    await _readZip64Data(input);

    InputStreamAsync dirContent = input.subset(centralDirectoryOffset, centralDirectorySize);

    while (!dirContent.isEOS) {
      int fileSig = await dirContent.readUint32();
      if (fileSig != ZipFileHeaderAsync.SIGNATURE) {
        break;
      }

      final fileHeader = ZipFileHeaderAsync();
      await fileHeader.init(dirContent, input, password);
      fileHeaders.add(fileHeader);
    }
  }

  void _readZip64Data(InputStreamAsync input) async {
    int ip = input.offset;
    // Check for zip64 data.

    // Zip64 end of central directory locator
    // signature                       4 bytes  (0x07064b50)
    // number of the disk with the
    // start of the zip64 end of
    // central directory               4 bytes
    // relative offset of the zip64
    // end of central directory record 8 bytes
    // total number of disks           4 bytes

    int locPos = filePosition - ZIP64_EOCD_LOCATOR_SIZE;
    if (locPos < 0) {
      return;
    }
    InputStreamAsync zip64 = input.subset(locPos, ZIP64_EOCD_LOCATOR_SIZE);

    int sig = await zip64.readUint32();
    // If this ins't the signature we're looking for, nothing more to do.
    if (sig != ZIP64_EOCD_LOCATOR_SIGNATURE) {
      input.offset = ip;
      return;
    }

    int startZip64Disk = await zip64.readUint32(); // ignore: unused_local_variable
    int zip64DirOffset = await zip64.readUint64();
    int numZip64Disks = await zip64.readUint32(); // ignore: unused_local_variable

    input.offset = zip64DirOffset;

    // Zip64 end of central directory record
    // signature                       4 bytes  (0x06064b50)
    // size of zip64 end of central
    // directory record                8 bytes
    // version made by                 2 bytes
    // version needed to extract       2 bytes
    // number of this disk             4 bytes
    // number of the disk with the
    // start of the central directory  4 bytes
    // total number of entries in the
    // central directory on this disk  8 bytes
    // total number of entries in the
    // central directory               8 bytes
    // size of the central directory   8 bytes
    // offset of start of central
    // directory with respect to
    // the starting disk number        8 bytes
    // zip64 extensible data sector    (variable size)
    sig = await input.readUint32();
    if (sig != ZIP64_EOCD_SIGNATURE) {
      input.offset = ip;
      return;
    }

    int zip64EOCDSize = await input.readUint64(); // ignore: unused_local_variable
    int zip64Version = await input.readUint16(); // ignore: unused_local_variable
    int zip64VersionNeeded = await input.readUint16(); // ignore: unused_local_variable
    int zip64DiskNumber = await input.readUint32();
    int zip64StartDisk = await input.readUint32();
    int zip64NumEntriesOnDisk = await input.readUint64();
    int zip64NumEntries = await input.readUint64();
    int dirSize = await input.readUint64();
    int dirOffset = await input.readUint64();

    numberOfThisDisk = zip64DiskNumber;
    diskWithTheStartOfTheCentralDirectory = zip64StartDisk;
    totalCentralDirectoryEntriesOnThisDisk = zip64NumEntriesOnDisk;
    totalCentralDirectoryEntries = zip64NumEntries;
    centralDirectorySize = dirSize;
    centralDirectoryOffset = dirOffset;

    input.offset = ip;
  }

  Future<int> _findSignature(InputStreamAsync input) async {
    int pos = input.offset;
    int length = input.length;

    // The directory and archive contents are written to the end of the zip
    // file.  We need to search from the end to find these structures,
    // starting with the 'End of central directory' record (EOCD).
    for (int ip = length - 4; ip >= 0; --ip) {
      input.offset = ip;
      int sig = await input.readUint32();
      if (sig == SIGNATURE) {
        input.offset = pos;
        return ip;
      }
    }

    throw ArchiveException(
        'Could not find End of Central Directory Record');
  }
}
