import 'dart:collection';

class Range {
  final int start;
  final int end;
  Range(this.start, this.end);
  @override
  String toString() {
    return '($start:$end)';
  }
}

class RangeManage extends IterableBase<Range> {
  List<Range> list = [];
  add(int startPos,int endPos) {
    if(list.isEmpty) {
      list.add(Range(startPos, endPos));
      return;
    }
    int start = list.indexWhere((v) => v.start <= startPos && v.end >= startPos);
    int end = list.indexWhere((v) => v.start <= endPos && v.end >= endPos);
    bool startContain = true;
    bool endContain = true;
    if(start== -1) {
      startContain = false;
      start = list.indexWhere((v) => v.start > startPos);
      if(start == -1) {
        start = list.length;
      }
    }
    if(end== -1) {
      endContain = false;
      end = list.lastIndexWhere((v) => v.end < endPos);
    }
    if(startContain && endContain) {
      list.replaceRange(start, end + 1, [Range(list[start].start, list[end].end)]);
    }else if(startContain && !endContain) {
      list.replaceRange(start, end + 1, [Range(list[start].start, endPos)]);
    }else if((!startContain) && endContain) {
      list.replaceRange(start, end + 1, [Range(startPos, list[end].end)]);
    }else {
      list.insert(start, Range(startPos, endPos));
    }
  }

  has(int startPos, int endPos) {
    final v = list.indexWhere((v) => v.start <= startPos && v.end >= endPos);
    return v != -1;
  }

  /// 获取缺少的部分
  List<Range> lose(int startPos, int endPos) {
    final sublist = list.where((v)  {
      return (v.start > startPos && v.start < endPos) || (v.end > startPos && v.end < endPos);
    }).toList();

    if(sublist.isEmpty){
      final a = list.indexWhere((v)  {
        return (v.start <= startPos && v.end >= endPos);
      });
      if( -1 == a) {
        return [Range(startPos, endPos)];
      } else {
        return [];
      }
    }
    int firstStart = startPos ;
    int lastEnd = endPos;


    if(sublist.first.end >= startPos && sublist.first.start<= startPos) {
      firstStart = sublist.first.end;
      sublist.removeAt(0);
    }
    if(sublist.isNotEmpty && sublist.last.end >= endPos && sublist.last.start <= endPos) {
      lastEnd = sublist.last.start;
      sublist.removeAt(sublist.length - 1);
    }
    if(sublist.isEmpty) {
      return [Range(firstStart, lastEnd)];
    }else if(sublist.length == 1) {
      return [Range(firstStart, sublist.first.start), Range(sublist.first.end, lastEnd)];
    }else {
      List<Range> loseList = [];
      loseList.add(Range(firstStart, sublist.first.start));
      for(int i = 1; i< sublist.length ; i++) {
        loseList.add(Range(sublist[i-1].end, sublist[i].start));
      }
      loseList.add(Range(sublist.last.end, lastEnd));
      return loseList;
    }
  }

  int getRangesLength(List<Range> list) {
    int l = 0;
    list.forEach((v) {
      l += v.end - v.start;
    });
    return l;
  }


  @override
  Iterator<Range> get iterator => list.iterator;


  printTestProgress(int length, {int barLength = 100}) {
    final blockSize = length ~/ barLength;
    String s = '';
    for(int i = 0; i < barLength; i++ ) {
      double ratio = 1 - getRangesLength(lose(i*blockSize, (i+1) * blockSize))/blockSize;
      if(ratio >= 1){
        s += '█';
      }else if(ratio >= 0.5){
        s += '▓';
      }else if(ratio >= 0.25){
        s += '▒';
      }else if(ratio > 0){
        s += '░';
      }else {
        s += '_';
      }
    }
    return s;
  }

}

