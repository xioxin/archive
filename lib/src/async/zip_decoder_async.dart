import '../../archive.dart';
import '../util/archive_exception.dart';
import '../util/crc32.dart';
import '../util/input_stream.dart';
import 'zip/zip_directory_async.dart';
import 'zip/zip_file_header_async.dart';
import 'zip/zip_file_async.dart';
import 'archive_async.dart';
import 'archive_file_async.dart';
import 'input_stream_async.dart';
import 'package:computer/computer.dart';

/// Decode a zip formatted buffer into an [Archive] object.
class ZipDecoderAsync {
  ZipDirectoryAsync directory;

/*
  ArchiveAsync decodeBytes(List<int> data, {bool verify = false, String password}) {
    return decodeBuffer(InputStream(data),
        verify: verify, password: password);
  }

  ArchiveAsync decodeBuffer(InputStream input,
      {bool verify = false, String password}) {
    directory = ZipDirectory.read(input, password: password);
    ArchiveAsync archive = ArchiveAsync();

    for (ZipFileHeader zfh in directory.fileHeaders) {
      ZipFile zf = zfh.file;

      // The attributes are stored in base 8
      final mode = zfh.externalFileAttributes;
      final compress = zf.compressionMethod != ZipFile.STORE;

      if (verify) {
        int computedCrc = getCrc32(zf.content);
        if (computedCrc != zf.crc32) {
          throw ArchiveException('Invalid CRC for file in archive.');
        }
      }

      var content = zf.rawContent;
      var file = ArchiveFileAsync(zf.filename, zf.uncompressedSize, content,
          zf.compressionMethod);

      file.mode = mode >> 16;

      // see https://github.com/brendan-duncan/archive/issues/21
      // UNIX systems has a creator version of 3 decimal at 1 byte offset
      if (zfh.versionMadeBy >> 8 == 3) {
        //final bool isDirectory = file.mode & 0x7000 == 0x4000;
        final bool isFile = file.mode & 0x3F000 == 0x8000;
        file.isFile = isFile;
      } else {
        file.isFile = !file.name.endsWith('/');
      }

      file.crc32 = zf.crc32;
      file.compress = compress;
      file.lastModTime = zf.lastModFileDate << 16 | zf.lastModFileTime;

      archive.addFile(file);
    }

    return archive;
  }

*/

  Future<ArchiveAsync> decodeBufferAsync(InputStreamAsync input,
      {bool verify = false, String password}) async {

//
//    final computer = Computer();
//    await computer.turnOn(
//      workersCount: 2,
//      areLogsEnabled: false, // optional, default false
//    );

    ArchiveAsync archive = ArchiveAsync();
    archive.input = input;

    directory = await ZipDirectoryAsync();
    final fileHeaders =  await input.diskCache.getArchiveFileHeader();
    if (input.diskCache != null && fileHeaders.isNotEmpty) {
      directory.fileHeaders = fileHeaders;
    } else {
      await directory.read(input, password: password);
    }

    for (ZipFileHeaderAsync zfh in directory.fileHeaders) {
      final mode = zfh.externalFileAttributes;
      final compress = zfh.compressionMethod != ZipFileAsync.STORE;
      var file = ArchiveFileAsync.async(
          zfh.filename, zfh.uncompressedSize, null, zfh.compressionMethod);

/*      file.getArchiveFile = () async {
        if (input.diskCache != null) {
          if(file.isFile) {
            final cacheData = await input.diskCache.getFile(zfh.filename);
            if(cacheData != null) {
              return cacheData;
            }
          }
        }

        final int length = 38 + zfh.fileNameLength + zfh.extraLength + zfh.compressedSize;

        final subInput = await input.subsetSync(zfh.localHeaderOffset, length);

        var data = await computer.compute<Map<String, dynamic>, List<int>>(
          unzipFileThreadTask,
          param: {
            'header': zfh.toJson(),
            'data': subInput.toUint8List().toList()
          }, // optional
        );
        if (input.diskCache != null) {
          if(file.isFile && data != null) {
            await input.diskCache.saveFile(file.name, data);
          }
        }
        return data;
      };*/

      file.getArchiveFile = () async {
        if (input.diskCache != null) {
          if(file.isFile) {
            final cacheData = await input.diskCache.getFile(zfh.filename);
            if(cacheData != null) {
              return cacheData;
            }
          }
        }
        final zf = ZipFileAsync(zfh);
        final zfInput = input.subset(zfh.localHeaderOffset);
        await zf.init(zfInput, password);
        if (verify) {
          int computedCrc = getCrc32(zf.content);
          if (computedCrc != zf.crc32) {
            throw ArchiveException('Invalid CRC for file in archive.');
          }
        }
        file.name = zf.filename;
        file.size = zf.uncompressedSize;
//        file.setContent(zf.rawContent);
        file.lastModTime = zf.lastModFileDate << 16 | zf.lastModFileTime;
        if (input.diskCache != null) {
          if(file.isFile && zf.content != null) {
            input.diskCache.saveFile(file.name, zf.content);
          }
        }
        return zf.content;
      };

      file.mode = mode >> 16;
      if (zfh.versionMadeBy >> 8 == 3) {
        final bool isFile = file.mode & 0x3F000 == 0x8000;
        file.isFile = isFile;
      } else {
        file.isFile = !file.name.endsWith('/');
      }

      file.crc32 = zfh.crc32;
      file.compress = compress;
      archive.addFile(file);
    }

    if (input.diskCache != null) {
      await input.diskCache.setArchiveFileHeader(directory.fileHeaders);
    }

    return archive;
  }


}


Future<List<int>> unzipFileThreadTask(Map<String, dynamic> data) async {

  final start = DateTime.now().millisecondsSinceEpoch;

  final zfh = ZipFileHeaderAsync.formJson(data["header"]).getSync();
  final zf = ZipFile(InputStream(data["data"]), zfh, data["password"]);
  List<int> content = zf.content;

  final end = DateTime.now().millisecondsSinceEpoch;
  print('timer ${zfh.filename} : ${end - start}ms');
  return content;
}