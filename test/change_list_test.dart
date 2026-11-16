import 'package:flutter/foundation.dart';
import 'package:flutter_nop/change_notifier.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('delegates list reads to the wrapped notifier value', () {
    final list = AutoListenList<int>(ValueNotifier([1, 2, 3]));

    expect(list.length, 3);
    expect(list.first, 1);
    expect(list.last, 3);
    expect(list[1], 2);
    expect(list.where((element) => element.isOdd).toList(), [1, 3]);
    expect(list.sublist(1), [2, 3]);
  });

  test('list mutations update the value and notify listeners', () {
    final notifier = ValueNotifier([1, 2, 3]);
    final list = AutoListenList<int>(notifier);
    var notifications = 0;
    notifier.addListener(() => notifications++);

    list.add(4);
    list.insert(0, 0);
    list[1] = 9;
    list.fillRange(2, 3, 8);
    list.removeWhere((element) => element == 3);
    list.replaceRange(2, 4, [6, 7]);

    expect(list.toList(), [0, 9, 6, 7]);
    expect(notifications, 6);

    list.value = [10];
    expect(notifier.value, [10]);
    expect(notifications, 7);

    list.notify();
    expect(notifications, 8);
  });

  test('does not notify when remove or clear changes nothing', () {
    final notifier = ValueNotifier(<int>[]);
    final list = AutoListenList<int>(notifier);
    var notifications = 0;
    notifier.addListener(() => notifications++);

    expect(list.remove(1), isFalse);
    list.clear();

    expect(notifications, 0);
  });
}
