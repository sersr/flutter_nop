import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_nop/router.dart';
import 'package:flutter_test/flutter_test.dart';

R _printZoned<R>(R Function() body) {
  return runZoned(body, zoneSpecification: ZoneSpecification(
    print: (self, parent, zone, line) {
      Zone.root.print(line);
    },
  ));
}

void main() {
  test('router test', () {
    RouteQueueEntryPage builder(RouteQueueEntry entry) {
      return MaterialIgnorePage(child: const SizedBox(), entry: entry);
    }

    _printZoned(() {
      var nPage = NPage(path: '/new/:bookId', pageBuilder: builder);
      final root = NPageMain(
        pageBuilder: builder,
        path: '/',
        pages: [
          NPage(path: '/hello', pageBuilder: builder),
          NPage(path: '/path', pageBuilder: builder, pages: [
            NPage(path: '/to/other', pageBuilder: builder, pages: [
              NPage(path: '/hello', pageBuilder: builder),
            ]),
            NPage(path: '/hello/:user', pageBuilder: builder, pages: [
              // 支持空路径名称
              NPage(pageBuilder: builder, pages: [
                nPage,
              ]),
            ]),
          ]),
        ],
      );

      final page = root.getPageFromLocation('/path/to/other/hello');
      expect(page != null, true);

      final userPage = root.getPageFromLocation('/path/hello/newUser');
      expect(userPage != null, true);
      expect(userPage!.fullPath, '/path/hello/:user');
      expect(userPage.params, ['user']);

      final userNewParams = <String, dynamic>{};
      final userNewPage = root.getPageFromLocation(
          '/path/hello/newUser//new/131231', userNewParams);

      expect(userNewPage != null, true);
      expect(userNewPage!.fullPath, '/path/hello/:user//new/:bookId');
      expect(userNewPage.params, ['user', 'bookId']);
      expect(userNewParams, {'user': 'newUser', 'bookId': '131231'});
      expect(nPage.fullPath, '/path/hello/:user//new/:bookId');
    });
  });
}
