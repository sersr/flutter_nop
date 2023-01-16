import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_nop/src/nop/router.dart';
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
    Page builder(RouteQueueEntry entry) {
      return const MaterialPage(child: SizedBox());
    }

    _printZoned(() {
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
              NPage(path: '/', pageBuilder: builder, pages: [
                NPage(path: '/new', pageBuilder: builder),
              ]),
            ]),
          ]),
        ],
      );

      final page = root.getPageFromLocation('/path/to/other/hello');
      expect(page != null, true);
      final userPage = root.getPageFromLocation('/path/hello/newUser');
      final userNewPage = root.getPageFromLocation('/path/hello/newUser//new');

      expect(userPage != null, true);
      expect(userPage!.fullPath, '/path/hello/:user');
      expect(userPage.params, ['user']);
      expect(userNewPage != null, true);
    });
  });
}
