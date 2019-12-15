import 'dart:convert';
import 'dart:io';
import 'package:archive/src/async/range_manage.dart';
import 'package:crypto/crypto.dart';

import '../../archive_async.dart';

class DirectoryStructure {
  String name;
  int offset;
  int length;
  bool isFile;
  int size;

  DirectoryStructure({
    this.name,
    this.offset,
    this.length,
    this.isFile,
    this.size,
  });

  DirectoryStructure.formJson(Map<String, dynamic> data) {
    name = data['name'] ?? '';
    offset = data['offset'] ?? 0;
    length = data['length'] ?? 0;
    isFile = data['isFile'] ?? false;
    size = data['size'] ?? 0;
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'offset': offset,
      'length': length,
      'isFile': isFile,
      'size': size,
    };
  }
}

class CacheInformation {
  String name;
  String key;
  RangeManage cachedDataRange;
  List<ZipFileHeaderAsync> directory;
  int fileLength;
  String password;
  int version = 0;

  CacheInformation(
      {this.name,
      this.key,
      this.cachedDataRange,
      this.directory,
      this.fileLength,
      this.password}) {
    this.directory ??= [];
    this.version = DiskCache.version;
  }

  CacheInformation.formJson(Map<String, dynamic> data) {
    name = data['name'] ?? '';
    key = data['key'] ?? '';
    fileLength = data['fileLength'] ?? '';
    password = data['password'] ?? '';
    version = data['version'] ?? 0;
    directory = (data['directory'] as List<dynamic> ?? [])
        .map((v) => ZipFileHeaderAsync.formJson(v))
        .toList();
    cachedDataRange = RangeManage();
    final List<dynamic> range = data['cachedDataRange'];
    range.forEach((v) => cachedDataRange.add(v[0], v[1]));
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'version': version,
      'name': name,
      'progress': cachedDataRange.printTestProgress(fileLength, barLength: 50),
      'fileLength': fileLength,
      'password': password,
      'key': key,
      'cachedDataRange':
          cachedDataRange.list.map((v) => [v.start, v.end]).toList(),
      'directory': directory.map((v) => v.toJson()).toList(),
    };
    return data;
  }
}

class DiskCache {
  static int version = 5;
  String fileName;
  final String fileKey;
  final String fileKeyHash;
  final String cachePath;
  final bool cacheRawData;
  bool initialized = false;
  bool initializing = false;
  final int fileLength;

  CacheInformation cacheInformation;
  File informationFile;
  RandomAccessFile cacheFileHandle;
  File cacheFile;

  RangeManage get range => cacheInformation.cachedDataRange;

  Directory cacheFilesDir;

  Directory cacheDir;

  DiskCache(
    this.fileKey,
    this.fileLength, {
    this.cachePath,
    this.cacheRawData = false,
    this.fileName = "data",
  }) : fileKeyHash = md5.convert(utf8.encode(fileKey)).toString();

  initialize() async {
    if(initializing || initialized) return;
    initializing = true;
    final cacheRootDir = Directory(this.cachePath);
    if (!await cacheRootDir.exists()) await cacheRootDir.create();
    cacheDir = Directory(cacheRootDir.path + Platform.pathSeparator + fileKeyHash);
    if (!await cacheDir.exists()) await cacheDir.create();

    cacheFilesDir = Directory(cacheRootDir.path +
        Platform.pathSeparator +
        fileKeyHash +
        Platform.pathSeparator +
        'files');

    this.informationFile = File(cacheDir.path + Platform.pathSeparator + 'information.json');

    if (await informationFile.exists()) {
      await loadCacheInformation();
    } else {
      await createCacheInformation();
    }
    cacheFile = File(cacheDir.path + Platform.pathSeparator + this.fileName);

    initialized = true;
    initializing = false;
  }

  openCacheFile() {
    cacheFileHandle = cacheFile.openSync(mode: FileMode.append);
  }

  loadCacheInformation() async {
    final jsonString = await informationFile.readAsString();
    final data = JsonDecoder().convert(jsonString);
    final int _version = data['version'] as int ?? 0;
    final int _fileLength = data['fileLength'] as int ?? 0;
    if(_version != version || _fileLength != fileLength) {
      await cacheDir.delete(recursive: true);
      await cacheDir.create();
      await createCacheInformation();
    } else {
      cacheInformation = CacheInformation.formJson(data);
      this.fileName = cacheInformation.name;
    }
  }

  createCacheInformation() async {
    final range = RangeManage();
    cacheInformation = CacheInformation(
        name: fileName,
        key: fileKeyHash,
        fileLength: fileLength,
        cachedDataRange: range);
    await writeCacheInformation();
  }

  writeCacheInformation() {
    final jsonString =
        JsonEncoder.withIndent('  ').convert(cacheInformation.toJson());
    informationFile.writeAsStringSync(jsonString);
  }

  fillEmptyData() async {
  }

  writeData(List<int> data, int offset, int length) {
    if(cacheFileHandle == null) {
      openCacheFile();
    }
    final end = offset + data.length;
    cacheFileHandle.setPositionSync(offset);
    cacheFileHandle.writeFromSync(data, 0, length);
    cacheFileHandle.flushSync();
    range.add(offset, end);
    writeCacheInformation();
  }

  Future<List<int>> getFile(String path) async {
    final filePath = this.cacheFilesDir.path + Platform.pathSeparator + Uri(path: path).toFilePath(windows: Platform.isWindows);
    final file = File(filePath);
    if(await file.exists()){
      return await file.readAsBytes();
    }
    return null;
  }

  Future saveFile(String path, List<int> data) async {
    if (!await cacheFilesDir.exists()) await cacheFilesDir.create();
    final filePath = this.cacheFilesDir.path + Platform.pathSeparator + Uri(path: path).toFilePath(windows: Platform.isWindows);
    final file = File(filePath);
    await file.writeAsBytes(data);
  }

  Future setArchiveFileHeader(List<ZipFileHeaderAsync> fileHeaders) async {
    cacheInformation.directory = fileHeaders;
    await writeCacheInformation();
  }
  Future<List<ZipFileHeaderAsync>> getArchiveFileHeader() async {
    if(!initialized) await initialize();
    return cacheInformation.directory;
  }

  bool hasData(int offset, int length) {
    final end = offset + length;
    return range.has(offset, end);
  }

  int convertOffset(int offset, int length) {
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
    if (hasData(offset, length)) {
      final handle = await cacheFile.open(mode: FileMode.read);
      await handle.setPosition(offset);
      final data = (await handle.read(length)).buffer.asUint8List();
      await handle.close();
      return data;
    } else {
      return null;
    }
  }

  destroy() {
    if(cacheFileHandle != null)cacheFileHandle.close();
  }
}
