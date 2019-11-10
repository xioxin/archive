import 'dart:io';
import 'package:archive/src/async/archive_async.dart';
import 'package:archive/src/async/archive_file_async.dart';
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

  final ias = InputStreamAsync((int offset, int length) async {
    print('bytes=${offset}-${offset + length}');
    final testData = await dio.get(url,
        options: Options(
          headers: {'Range': 'bytes=${offset}-${offset + length}'},
          responseType: ResponseType.bytes,
        ));
    return testData.data;
  }, fileLength);

  ArchiveAsync archive =
      await ZipDecoderAsync().decodeBufferAsync(ias, verify: true);

  for (ArchiveFileAsync filePack in archive) {
    String filename = filePack.name;
    print(filename);
  }

  ArchiveFileAsync filePack =
      archive.findFile('jonas-vincent-xulIYVIbYIc-unsplash.jpg');
  final file = await filePack.getAsyncFile();

  File('out/' + 'jonas-vincent-xulIYVIbYIc-unsplash.jpg')
    ..createSync(recursive: true)
    ..writeAsBytesSync(file.content);
}
