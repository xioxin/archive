import 'dart:isolate';

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





    ArchiveAsync archive = ArchiveAsync();
    archive.input = input;

    directory = await ZipDirectoryAsync();
    final fileHeaders =  await input.diskCache.getArchiveFileHeader();
    if (input.diskCache != null && fileHeaders.length > 0) {
      directory.fileHeaders = fileHeaders;
    } else {
      await directory.read(input, password: password);
    }

    for (ZipFileHeaderAsync zfh in directory.fileHeaders) {
      final mode = zfh.externalFileAttributes;
      final compress = zfh.compressionMethod != ZipFileAsync.STORE;
      var file = ArchiveFileAsync.async(
          zfh.filename, zfh.uncompressedSize, null, zfh.compressionMethod);
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
          if(file.isFile && zf.rawContent != null) {
            input.diskCache.saveFile(file.name, zf.rawContent);
          }
        }
        return zf.rawContent;
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


void unzipFile(SendPort port) async {
  await Future.delayed(Duration(seconds: 5));
  port.send("Job's done"); //2.子线程完成任务，回报数据
}