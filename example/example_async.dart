import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:archive/src/async/archive_async.dart';
import 'package:archive/src/async/archive_file_async.dart';
import 'package:archive/src/async/input_stream_async.dart';
import 'package:archive/src/async/range_manage.dart';
import 'package:archive/src/async/zip_decoder_async.dart';

// 2020ms

void main() async {
  final start = DateTime.now().millisecondsSinceEpoch;

  final file = await File('test.zip').open(mode: FileMode.read);
  final fileLength = await file.length();

  final ias =
      InputStreamAsync((int offset, int length, InputStreamAsync self) async {
    final file = await File('test.zip').open(mode: FileMode.read);
    await file.setPosition(offset);
    final buff = (await file.read(length)).buffer.asUint8List();
    return buff;
  }, fileLength, chunkSize: 1024 * 4);

  ArchiveAsync archive =
      await ZipDecoderAsync().decodeBufferAsync(ias, verify: true);

  List<Future> p = [];

  for (ArchiveFileAsync file in archive) {
    String filename = file.name;
    if (file.isFile) {
      p.add(file.loadContent().then((file) async {
        final data = file.content;
        final outFile = File('out/' + filename);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      }));
    } else {
      Directory('out/' + filename)..create(recursive: true);
    }
  }

  await Future.wait(p);

  final end = DateTime.now().millisecondsSinceEpoch;

  print('timer ${end - start}ms');
}
