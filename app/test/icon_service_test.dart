import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:syspie/shared/services/icon_service.dart';

import 'helpers/fake_syspie_client.dart';

void main() {
  late FakeSysPieClient fake;
  late int ackCount;

  setUp(() {
    IconService.clearCache();
    fake = FakeSysPieClient();
    IconService.client = fake;
    ackCount = 0;
    fake.ackHandler = (cmd) async {
      ackCount++;
      return {};
    };
    addTearDown(() => IconService.client = null);
  });

  group('getCachedIcon / getCachedAumidIcon', () {
    test('both return null when nothing has been loaded', () {
      expect(IconService.getCachedIcon(123), isNull);
      expect(IconService.getCachedAumidIcon('A'), isNull);
    });
  });

  group('loadIconByAumid', () {
    test('returns the icon on the first call and caches it', () async {
      fake.ackHandler = (cmd) async {
        ackCount++;
        expect(cmd, {'cmd': 'get_aumid_icon', 'aumid': 'A'});
        return {'icon': 'data:image/png;base64,AAAA'};
      };

      final icon = await IconService.loadIconByAumid('A');
      expect(icon, 'data:image/png;base64,AAAA');

      final ackCallsAfterFirst = ackCount;
      final cached = await IconService.loadIconByAumid('A');
      expect(cached, 'data:image/png;base64,AAAA');
      expect(ackCount, ackCallsAfterFirst,
          reason: 'cached value should need no ack');
    });

    test('empty aumid returns null without calling the client', () async {
      var clientCalls = 0;
      fake.ackHandler = (cmd) async {
        clientCalls++;
        return {'icon': 'x'};
      };

      final icon = await IconService.loadIconByAumid('');
      expect(icon, isNull);
      expect(clientCalls, 0);
    });

    test('returns null when client is not set', () async {
      IconService.client = null;
      final icon = await IconService.loadIconByAumid('A');
      expect(icon, isNull);
      expect(fake.sentCommands, isEmpty);
    });

    test('returns null and does NOT cache when ack has no icon', () async {
      fake.ackHandler = (cmd) async {
        ackCount++;
        return {'icon': null};
      };

      final icon = await IconService.loadIconByAumid('A');
      expect(icon, isNull);
      expect(IconService.getCachedAumidIcon('A'), isNull);
    });

    test('deduplicates concurrent loads for the same aumid', () async {
      final completer = Completer<Map<String, dynamic>>();
      fake.ackHandler = (cmd) async {
        ackCount++;
        return completer.future;
      };

      final first = IconService.loadIconByAumid('A');
      final second = IconService.loadIconByAumid('A');

      // Give the event loop a tick so the first call registers loading.
      await Future<void>.delayed(Duration.zero);
      completer.complete({'icon': 'data:image/png;base64,BBBB'});

      final results = await Future.wait([first, second]);
      expect(ackCount, 1,
          reason: 'a concurrent load must not issue a duplicate ack');
      expect(results[0], 'data:image/png;base64,BBBB');
    });
  });

  group('loadIconsForPids', () {
    test('caches delivered icons and marks empty/missing pids failed',
        () async {
      fake.ackHandler = (cmd) async {
        ackCount++;
        expect(cmd, {
          'cmd': 'get_icons',
          'pids': [1, 2, 3]
        });
        return {
          'icons': [
            {'pid': 1, 'icon': 'I1'},
            {'pid': 2, 'icon': ''},
          ],
        };
      };

      await IconService.loadIconsForPids([1, 2, 3]);

      expect(IconService.getCachedIcon(1), 'I1');
      expect(IconService.getCachedIcon(2), isNull);
      expect(IconService.getCachedIcon(3), isNull);

      final acksAfterFirst = ackCount;
      await IconService.loadIconsForPids([1, 2, 3]);
      expect(ackCount, acksAfterFirst,
          reason: 'cached and failed pids must be skipped on a retry');
    });

    test('with null client returns without calling the client', () async {
      IconService.client = null;
      await IconService.loadIconsForPids([1, 2, 3]);
      expect(fake.sentCommands, isEmpty);
    });
  });
}
