import 'dart:async';
import 'dart:io';
import 'package:archive/src/async/archive_async.dart';
import 'package:archive/src/async/archive_file_async.dart';
import 'package:archive/src/async/input_stream_async.dart';
import 'package:archive/src/async/zip_decoder_async.dart';
import 'package:smb2/smb2.dart';

void main() async {
  final start = DateTime.now().millisecondsSinceEpoch;
  final uri = Uri.parse('smb://admin:Zhaoxin110@10.10.10.3/comic/高津/[高津] マイ・ディア・メイド [中国翻訳].zip');

  final serverUri = Uri(scheme: uri.scheme, host: uri.host, userInfo: uri.userInfo, port: uri.port, path: uri.pathSegments.first);
  final fileUri = Uri(pathSegments: uri.pathSegments.sublist(1));
  final fileName = uri.pathSegments.last;

  SMB smb = SMB(serverUri, debug: true);
  await smb.connect();
  final file = await smb.open(fileUri.toString());
  final fileLength = file.fileLength;

  final tempDirPath = Directory.systemTemp.path;
  print(tempDirPath);

  final fileKey = uri.toString();

  final ias = InputStreamAsync.disk((int offset, int length, s) async {
    final buff = smb.readFile(file, offset: offset, length: length);
    return buff;
  }, fileLength, chunkSize: 8 * 1024, fileKey: fileKey, cachePath: tempDirPath, fileName: fileName);

  ArchiveAsync archive = await ZipDecoderAsync().decodeBufferAsync(ias, verify: true);

  print(archive);

  for (ArchiveFileAsync file in archive) {
    String filename = file.name;
    if (file.isFile) {
      await file.getContent().then((data) async {
        if(data == null) {
          print('数据为空');
          return;
        }
        final outFile = File('out/' + filename);
        await outFile.create(recursive: true);
        await outFile.writeAsBytes(data);
      });
    } else {
      Directory('out/' + filename)..create(recursive: true);
    }
  }

  final end = DateTime.now().millisecondsSinceEpoch;

  print('timer ${end - start}ms');
}