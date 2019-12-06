import 'dart:convert';
import 'dart:io';
import 'package:archive/src/async/range_manage.dart';
import 'package:crypto/crypto.dart';

class DirectoryStructure {
  String name;
  int offset;
  int length;

  DirectoryStructure.formJson(Map<String, dynamic> data) {
    name = data['name'] ?? '';
    offset = data['offset'] ?? '';
    length = data['length'] ?? '';
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'offset': offset,
      'length': length,
    };
  }
}

class CacheInformation {
  String name;
  String key;
  RangeManage cachedDataRange;
  List<DirectoryStructure> directory;
  int fileLength;
  String password;

  CacheInformation({this.name, this.key, this.cachedDataRange, this.directory, this.fileLength, this.password}) {
    this.directory ??= [];
  }

  CacheInformation.formJson(Map<String, dynamic> data) {
    name = data['name'] ?? '';
    key = data['key'] ?? '';
    fileLength = data['fileLength'] ?? '';
    password = data['password'] ?? '';
    directory = (data['directory'] as List<dynamic> ?? []).map((v) => DirectoryStructure.formJson(v)).toList();
    cachedDataRange = RangeManage();
    final List<dynamic> range = data['cachedDataRange'];
    range.forEach((v) => cachedDataRange.add(v[0], v[1]));
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'name': name,
      'progress': cachedDataRange.printTestProgress(fileLength, barLength: 50),
      'fileLength': fileLength,
      'password': password,
      'key': key,
      'cachedDataRange': cachedDataRange.list.map((v) => [v.start, v.end]).toList(),
      'directory': directory.map((v) => v.toJson()).toList(),
    };
    return data;
  }

}

class DiskCache {
  String fileName;
  final String fileKey;
  final String fileKeyHash;
  final String cachePath;
  final bool cacheRawData;
  bool initialized = false;
  final int fileLength;

  CacheInformation cacheInformation;
  File informationFile;
  RandomAccessFile cacheFileHandle;
  File cacheFile;

  RangeManage get range => cacheInformation.cachedDataRange;


  DiskCache(this.fileKey, this.fileLength,  {
    this.cachePath,
    this.cacheRawData = false,
    this.fileName,
  }) : fileKeyHash = md5.convert(utf8.encode(fileKey)).toString();

  initialize() async {
    final cacheRootDir = Directory(this.cachePath);
    if(!await cacheRootDir.exists()) await cacheRootDir.create();
    final cacheDir = Directory(cacheRootDir.path + Platform.pathSeparator + fileKeyHash);
    if(!await cacheDir.exists()) await cacheDir.create();
    this.informationFile = File(cacheDir.path + Platform.pathSeparator + 'information.json');

    if(await informationFile.exists()) {
     await loadCacheInformation();
    } else {
      await createCacheInformation();
    }

    cacheFile = File(cacheDir.path + Platform.pathSeparator + this.fileName);
    if(!await cacheFile.exists()) {
      await cacheFile.create();
    }
    cacheFileHandle = await cacheFile.open(mode: FileMode.append);
    initialized = true;
  }

  loadCacheInformation() {
    final jsonString = informationFile.readAsStringSync();
    final data = JsonDecoder().convert(jsonString);
    cacheInformation = CacheInformation.formJson(data);
    this.fileName = cacheInformation.name;
  }

  createCacheInformation() async {
    final range = RangeManage();
    cacheInformation = CacheInformation(name: fileName, key: fileKeyHash, fileLength: fileLength, cachedDataRange: range);
    await writeCacheInformation();
  }

  writeCacheInformation() {
    final jsonString = JsonEncoder.withIndent('  ').convert(cacheInformation.toJson());
    informationFile.writeAsStringSync(jsonString);
  }

  writeData(List<int> data, int offset, int length) {
    final end = offset + data.length;
    cacheFileHandle.setPositionSync(offset);
    cacheFileHandle.writeFromSync(data, 0, length);
    cacheFileHandle.flushSync();
    range.add(offset, end);
    writeCacheInformation();
  }

  bool hasData(int offset, int length) {
    final end = offset + length;
    return range.has(offset, end);
  }

  int convertOffset (int offset, int length) {
    final end = offset + length;
    int missLength = 0;
    int lastEnd = 0;
    range.list.indexWhere((range) {
      missLength += range.start - lastEnd;
      lastEnd = range.end;
      return range.start <= offset && range.end >= end;
    });

    final newOffset = offset - missLength;
    return newOffset;
  }

  Future<List<int>> readData(int offset, int length) async {
    if(hasData(offset, length)) {
      final handle = await cacheFile.open(mode: FileMode.read);
      await handle.setPosition(offset);
      final data = (await handle.read(length)).buffer.asUint8List();
      await handle.close();
      return data;
    } else {
      return null;
    }
  }

  close () {
    cacheFileHandle.close();
  }

}