import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../util/archive_exception.dart';
import '../util/byte_order.dart';
import '../util/input_stream.dart';

typedef Future<List<int>> InputFunction (int offset, int length);

/// A buffer that can be read as a stream of bytes
class InputStreamAsync {
  final List<int> _buffer;
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
  final int start;
  final int byteOrder;
  final int chunkSize;
  final InputFunction loader;

  InputStreamAsync parent;

  /// Create a InputStream for reading from a List<int>
  InputStreamAsync(this.loader, int length, {this.byteOrder = LITTLE_ENDIAN, this.chunkSize = 8 * 1024, this.start = 0}):
        _buffer = new List(length){
    _length = length;
    offset = start;
  }

  InputStreamAsync.subset(this.parent, {int length, this.byteOrder = LITTLE_ENDIAN, this.chunkSize = 1000, this.start = 0} ): _buffer = null, this.loader = null {
    offset = start;
    _length =  length != null ? length : this.parent._length;
  }

  printProgressBar() {
    final barLength = 100;
    final blockSize = _length ~/ barLength;
    int index = 0;
    final list = new List(barLength).map((v) {

      final sub = buffer.sublist(index * blockSize, (index + 1) * blockSize);
      final v1 = sub.length.toDouble();
      final v2 = sub.where((v) => v != null).length.toDouble();
      final double b = v2 / v1;
      index++;

      if(b == 1){
        return '█';
      }

      if(b > 75){
        return '▓';
      }

      if(b > 50){
        return '▒';
      }
      if(b > 25){
        return '░';
      }
      if(b > 0){
        return '.';
      }
      return '_';
    });
    print(list.join(''));
  }

  Future loadData(int offset, int length) async {
    if(this.parent != null) {
      return await this.parent.loadData(offset, length);
    }
    final data = await loader(offset, length);
    int index = offset;
    data.forEach((v) {
      buffer[index] = v;
      index++;
    });
  }

  bool integrityCheck(int offset, int length){
    final b = buffer.sublist(offset, offset+length).every((v) => v != null);
    return b;
  }

  checkAndLoad(int offset, [int length = 1]) async{
    if(this.parent != null) {
      return await this.parent.checkAndLoad(offset, length);
    }
    if(!integrityCheck(offset, length)){

        final start = offset;
        final chunkLength = length < chunkSize ? chunkSize : length;
        final end = start + chunkLength > _length ? _length : start + chunkLength;

        final reverseEnd = start + length;
        int reverseStart = reverseEnd - chunkLength;
        if(reverseStart < 0) reverseStart = 0;

        int nullSize = buffer.sublist(start, end).where((v) => v == null).length;
        int reverseNullSize = buffer.sublist(reverseStart, reverseEnd).where((v) => v == null).length;

        if(reverseNullSize > nullSize) {
          await loadData(reverseStart, reverseEnd - reverseStart);
        }else {
          await loadData(start, end - start);
        }
//
//      final start = offset;
//      final end = offset + length;
//      if(length < chunkSize) {
//        final rightList = buffer.sublist(offset, offset + chunkSize);
//
//        int leftStart = offset - chunkSize + length;
//        if(leftStart < 0) leftStart = 0;
//
//        final leftList = buffer.sublist(leftStart, leftStart + chunkSize);
//
//      }
//        await loadData(start, end);
//


//    print('loadData($start, $length)');
//      await loadData(offset, length);
    }
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
    await checkAndLoad(position, length);
    return InputStream(buffer,
        byteOrder: byteOrder, start: position, length: length);
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
//    print('readByte $offset');
//    print(buffer.sublist(0, 10));
    await checkAndLoad(offset);
    return buffer[offset++];
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
    await checkAndLoad(offset, 2);
    int b1 = buffer[offset++] & 0xff;
    int b2 = buffer[offset++] & 0xff;
    if (byteOrder == BIG_ENDIAN) {
      return (b1 << 8) | b2;
    }
    return (b2 << 8) | b1;
  }

  /// Read a 24-bit word from the stream.
  Future<int> readUint24() async {
    await checkAndLoad(offset, 3);
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
    await checkAndLoad(offset, 4);
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
    await checkAndLoad(offset, 8);
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
    if (buffer is Uint8List) {
      Uint8List b = buffer;
      if ((offset + len) > b.length) {
        len = b.length - offset;
      }
      Uint8List bytes =
          Uint8List.view(b.buffer, b.offsetInBytes + offset, len);
      return bytes;
    }
    int end = offset + len;
    if (end > buffer.length) {
      end = buffer.length;
    }
    await checkAndLoad(offset, len);
    return Uint8List.fromList(buffer.sublist(offset, end));
  }

  int _length;
}
