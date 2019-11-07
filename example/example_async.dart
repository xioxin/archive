import 'dart:async';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:archive/src/async/archive_async.dart';
import 'package:archive/src/async/archive_file_async.dart';
import 'package:archive/src/async/input_stream_async.dart';
import 'package:archive/src/async/zip_decoder_async.dart';

void main() async {

  final start = new DateTime.now().millisecondsSinceEpoch;

  final file = await File('test.zip').open(mode: FileMode.read);
  final fileLength = await file.length();

  final ias = InputStreamAsync((int offset, int length) async {
    await file.setPosition(offset);
    final buff = (await file.read(length)).buffer.asUint8List();
    return buff;
  }, fileLength, chunkSize: 1);

  ArchiveAsync archive = await ZipDecoderAsync().decodeBufferAsync(ias, verify: true);

  for (ArchiveFileAsync filePack in archive) {
    String filename = filePack.name;
    if(filePack.isFile) {
      final data = (await filePack.getAsyncFile()).content;
      final file = File('out/' + filename);
      await file.create(recursive: true);
      await file.writeAsBytes(data);
    } else {
      Directory('out/' + filename)
        ..create(recursive: true);
    }
  }

  final end = new DateTime.now().millisecondsSinceEpoch;

  print('timer ${end - start}ms');
}
