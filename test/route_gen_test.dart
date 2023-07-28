import 'package:flutter_test/flutter_test.dart';

import 'src/route_gen.dart';

void main() {
  test('route gen test', () {
    Routes.init();
    expect(Routes.page02.groupKey, Routes.page03.groupKey);
    expect(Routes.page02.groupName, Routes.page03.groupName);
    expect(Routes.page02.groupOwner, Routes.page03.groupOwner);
  });
}
