import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import './range_manage.dart';
import '../util/archive_exception.dart';
import '../util/byte_order.dart';
import '../util/input_stream.dart';
import 'disk-cache.dart';

typedef Future<List<int>> InputFunction (int offset, int length, InputStreamAsync self);


enum InputStreamCacheType {
  disabled,
  memory,
  disk,
  static,
}


/// A buffer that can be read as a stream of bytes
class InputStreamAsync {
  List<int> _buffer;
  get buffer{
    if(this.parent != null) {
      return parent.buffer;
    }else {
      return _buffer;
    }
  }

  int _count = 0;
  int countingAccumulation () {
    if(this.parent != null) {
      return this.parent.countingAccumulation();
    }else {
      return _count++;
    }
  }

  int offset;
  int start;
  int byteOrder;
  int chunkSize;

  String fileKey;
  String cachePath;

  InputFunction loader;

  DiskCache diskCache;

  RangeManage _loadedRange = RangeManage();
  RangeManage get loadedRange {
    if(type == InputStreamCacheType.disk) {
      return diskCache.range;
    } else {
      return _loadedRange;
    }
  }



  InputStreamAsync parent;

  InputStreamCacheType type = InputStreamCacheType.disabled;

  /// Create a InputStream for reading from a List<int>
  InputStreamAsync(this.loader, int length, {
    this.byteOrder = LITTLE_ENDIAN,
    this.start = 0,
  }): _buffer = null{
    type = InputStreamCacheType.disabled;
    _length = length;
    offset = start;
  }

  InputStreamAsync.memory(this.loader, int length, {
    this.byteOrder = LITTLE_ENDIAN,
    this.start = 0,
    this.chunkSize = 4 * 1024,
  }): _buffer = List(length) {
    type = InputStreamCacheType.memory;
    _length = length;
    offset = start;
  }

  InputStreamAsync.disk(this.loader, int length, {
    this.byteOrder = LITTLE_ENDIAN,
    this.chunkSize = 4 * 1024,
    this.start = 0,
    this.fileKey,
    this.cachePath,
    fileName = 'data',
  }): _buffer = null {
    diskCache = DiskCache(fileKey, length, cachePath: cachePath, fileName: fileName);
    type = InputStreamCacheType.disk;
    _length = length;
    offset = start;
  }

  InputStreamAsync.subset(this.parent, {int length, this.byteOrder = LITTLE_ENDIAN, this.chunkSize = 1000, this.start = 0} ): _buffer = null, this.loader = null {
    offset = start;
    _length =  length != null ? length : this.parent._length;
  }

  Future<List<int>> loadData(int offset, int length) async {
    if(this.parent != null) {
      return await this.parent.loadData(offset, length);
    }
    List<int> data = await loader(offset, length, this);
    if(diskCache != null) {
      diskCache.writeData(data, offset, length);
    }
    if (_buffer != null) {
      int index = offset;
      data.forEach((v) {
        buffer[index] = v;
        index++;
      });
      loadedRange.add(offset, offset + length);
    }
    return data;
  }

  bool integrityCheck(int offset, int length){
    return loadedRange.has(offset, offset + length);
  }

  Future<List<int>> checkAndLoad(int offset, [int length = 1]) async{
    if(this.parent != null) {
      return await this.parent.checkAndLoad(offset, length);
    }
    if(!diskCache.initialized) await diskCache.initialize();
    if(integrityCheck(offset, length)) {
      if(type == InputStreamCacheType.memory) {
        return _buffer.sublist(offset, offset + length);
      }else if(type == InputStreamCacheType.disk){
        return diskCache.readData(offset, length);
      }
    }

    final start = offset;
    final chunkLength = length < chunkSize ? chunkSize : length;
    final end = start + chunkLength > _length ? _length : start + chunkLength;

    final reverseEnd = start + length;
    int reverseStart = reverseEnd - chunkLength;
    if(reverseStart < 0) reverseStart = 0;

    int nullSize = loadedRange.getRangesLength(loadedRange.lose(start, end));
    int reverseNullSize = loadedRange.getRangesLength(loadedRange.lose(reverseStart, reverseEnd));

    List<int> data;

    if(reverseNullSize > nullSize) {
      data = await loadData(reverseStart, reverseEnd - reverseStart);
    }else {
      data = await loadData(start, end - start);
    }

    return data.sublist(offset-start, offset-start+length);
  }

  ///  The current read position relative to the start of the buffer.
  int get position => offset - start;

  /// How many bytes are left in the stream.
  int get length => _length - (offset - start);

  /// Is the current position at the end of the stream?
  bool get isEOS => offset >= (start + _length);

  /// Reset to the beginning of the stream.
  void reset() {
    offset = start;
  }

  /// Rewind the read head of the stream by the given number of bytes.
  void rewind([int length = 1]) {
    offset -= length;
    if (offset < 0) {
      offset = 0;
    }
  }

  /// Access the buffer relative from the current position.
  int operator [](int index) => buffer[offset + index];

  /// Return a InputStream to read a subset of this stream.  It does not
  /// move the read position of this stream.  [position] is specified relative
  /// to the start of the buffer.  If [position] is not specified, the current
  /// read position is used. If [length] is not specified, the remainder of this
  /// stream is used.
  InputStreamAsync subset([int position, int length]) {
    if (position == null) {
      position = this.offset;
    } else {
      position += start;
    }
    if (length == null || length < 0) {
      length = _length - (position - start);
    }
    return InputStreamAsync.subset(this, byteOrder: byteOrder, start: position, length: length);
  }

  Future<InputStream> subsetSync([int position, int length]) async {
    if (position == null) {
      position = this.offset;
    } else {
      position += start;
    }
    if (length == null || length < 0) {
      length = _length - (position - start);
    }
    final data = await checkAndLoad(position, length);
    return InputStream(data, byteOrder: byteOrder, start: 0, length: length);
  }

  /// Returns the position of the given [value] within the buffer, starting
  /// from the current read position with the given [offset].  The position
  /// returned is relative to the start of the buffer, or -1 if the [value]
  /// was not found.
  int indexOf(int value, [int offset = 0]) {
    for (int i = this.offset + offset, end = this.offset + length;
        i < end;
        ++i) {
      if (buffer[i] == value) {
        return i - this.start;
      }
    }
    return -1;
  }

  /// Read [count] bytes from an [offset] of the current read position, without
  /// moving the read position.
  InputStreamAsync peekBytes(int count, [int offset = 0]) {
    return subset((this.offset - start) + offset, count);
  }

  /// Move the read position by [count] bytes.
  void skip(int count) {
    offset += count;
  }

  /// Read a single byte.
  Future<int> readByte() async {
    final data = await checkAndLoad(offset);
    this.skip(1);
    return data[0];
  }

  /// Read [count] bytes from the stream.
  InputStreamAsync readBytes(int count) {
    InputStreamAsync bytes = subset(this.offset - start, count);
    offset += count;
    return bytes;
  }

  /// Read [count] bytes from the stream.
  Future<InputStream> readSyncBytes(int count) async {
    InputStream bytes = await subsetSync(this.offset - start, count);
    offset += bytes.length;
    return bytes;
  }

  /// Read a null-terminated string, or if [len] is provided, that number of
  /// bytes returned as a string.
  Future<String> readString({int size, bool utf8 = true}) async {
    if (size == null) {
      List<int> codes = [];
      while (!isEOS) {
        int c = await readByte();
        if (c == 0) {
          return utf8
              ? Utf8Decoder().convert(codes)
              : String.fromCharCodes(codes);
        }
        codes.add(c);
      }
      throw ArchiveException(
          'EOF reached without finding string terminator');
    }
    InputStream s = await readSyncBytes(size);
    Uint8List bytes = s.toUint8List();
    String str = utf8
        ? Utf8Decoder().convert(bytes)
        : String.fromCharCodes(bytes);
    return str;
  }

  /// Read a 16-bit word from the stream.
  Future<int> readUint16() async {
    final buffer = await checkAndLoad(this.offset, 2);
    this.skip(2);

    int offset = 0;
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 8) | b2;
    }
    return (b2 << 8) | b1;
  }

  /// Read a 24-bit word from the stream.
  Future<int> readUint24() async {
    final buffer = await checkAndLoad(this.offset, 3);
    this.skip(3);

    int offset = 0;
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return b3 | (b2 << 8) | (b1 << 16);
    }
    return b1 | (b2 << 8) | (b3 << 16);
  }

  /// Read a 32-bit word from the stream.
  Future<int> readUint32() async {
    final buffer = await checkAndLoad(this.offset, 4);
    this.skip(4);

    int offset = 0;
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    int b4 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 24) | (b2 << 16) | (b3 << 8) | b4;
    }
    return (b4 << 24) | (b3 << 16) | (b2 << 8) | b1;
  }

  /// Read a 64-bit word form the stream.
  Future<int> readUint64() async {
    final buffer = await checkAndLoad(this.offset, 8);
    this.skip(8);
    int offset = 0;
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    int b3 = buffer[offset++] & 0xff;
    int b4 = buffer[offset++] & 0xff;
    int b5 = buffer[offset++] & 0xff;
    int b6 = buffer[offset++] & 0xff;
    int b7 = buffer[offset++] & 0xff;
    int b8 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 56) |
          (b2 << 48) |
          (b3 << 40) |
          (b4 << 32) |
          (b5 << 24) |
          (b6 << 16) |
          (b7 << 8) |
          b8;
    }
    return (b8 << 56) |
        (b7 << 48) |
        (b6 << 40) |
        (b5 << 32) |
        (b4 << 24) |
        (b3 << 16) |
        (b2 << 8) |
        b1;
  }

  Future<Uint8List> toUint8List() async {
    int len = length;
//    if (buffer is Uint8List) {
//      Uint8List b = buffer;
//      if ((offset + len) > b.length) {
//        len = b.length - offset;
//      }
//      Uint8List bytes =
//          Uint8List.view(b.buffer, b.offsetInBytes + offset, len);
//      return bytes;
//    }

    final buffer = await checkAndLoad(offset, len);
    int end = offset + len;
    if (end > buffer.length) {
      end = buffer.length;
    }
    return Uint8List.fromList(buffer);
  }

  int _length;

  destroy() {
    this.loader = null;
    _buffer = null;
    this.diskCache.destroy();
  }
}
