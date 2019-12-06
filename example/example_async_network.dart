import 'dart:io';
import 'package:archive/src/async/archive_async.dart';
import 'package:archive/src/async/archive_file_async.dart';
import 'package:archive/src/async/disk-cache.dart';
import 'package:archive/src/async/input_stream_async.dart';
import 'package:archive/src/async/zip_decoder_async.dart';
import 'package:dio/dio.dart';

void main() async {
  /* Accept-Ranges: bytes */
  final dio = Dio();
  final url = 'https://files.catbox.moe/tuvxhg.zip';
  final headInfo = await dio.head(url);
  final fileLength =
      int.parse(headInfo.headers['content-length']?.first ?? '0');
  final acceptRanges = headInfo.headers['accept-ranges']?.first ?? '';
  final contentType = headInfo.headers['content-type']?.first ?? '';
  print('fileLength: ${fileLength}');
  print('acceptRanges: ${acceptRanges}');
  print('contentType: ${contentType}');

  print(Directory.systemTemp.path);

  final diskCache = DiskCache(url, fileLength, cachePath: Directory.systemTemp.path, fileName: 'tuvxhg.zip');
  await diskCache.initialize();

  final ias = InputStreamAsync((int offset, int length, InputStreamAsync self) async {
    print('bytes=${offset}-${offset + length}');
    final testData = await dio.get(url,
        options: Options(
          headers: {'Range': 'bytes=${offset}-${offset + length}'},
          responseType: ResponseType.bytes,
        ), onReceiveProgress: (int count, int total) { print('download: ${count / total * 100}'); });
    return testData.data;
  }, fileLength, diskCache: diskCache, chunkSize: 1024 * 4);

  ArchiveAsync archive = await ZipDecoderAsync().decodeBufferAsync(ias);

  for (ArchiveFileAsync filePack in archive) {
    String filename = filePack.name;
    await filePack.loadContent();
    print(filename);
  }

  ArchiveFileAsync file =
      archive.findFile('jonas-vincent-xulIYVIbYIc-unsplash.jpg');
  await file.loadContent();

  File('out/' + 'jonas-vincent-xulIYVIbYIc-unsplash.jpg')
    ..createSync(recursive: true)
    ..writeAsBytesSync(file.content);
}
