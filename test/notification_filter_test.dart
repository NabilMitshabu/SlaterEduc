import 'package:flutter_test/flutter_test.dart';
import 'package:slatereduc/services/api/notification_service.dart';

void main() {
  group('NotificationService.filterIncomingNotifications', () {
    final service = NotificationService();
    const myId = '3fa85f64-5717-4562-b3fc-2c963f66afa6';

    test('exclut les MESSAGE sortants (id_user == myId)', () {
      final list = [
        {
          'id': 'n1',
          'notif_type': 'MESSAGE',
          'title': 'msg out',
          'content': 'hello',
          'id_user': myId,
          'is_read': false,
          'created_at': '2025-12-17T09:08:57.347Z',
        },
        {
          'id': 'n2',
          'notif_type': 'MESSAGE',
          'title': 'msg in',
          'content': 'hey',
          'id_user': 'other',
          'is_read': false,
          'created_at': '2025-12-17T09:08:57.347Z',
        },
        {
          'id': 'n3',
          'notif_type': 'PUNITION',
          'title': 'pun',
          'content': 'bad',
          'id_user': myId,
          'is_read': false,
          'created_at': '2025-12-17T09:08:57.347Z',
        },
      ];

      final res = service.filterIncomingNotifications(list, myId);
      expect(res.length, 2);
      expect(res.any((n) => n['id'] == 'n1'), isFalse, reason: 'le message sortant doit être filtré');
      expect(res.any((n) => n['id'] == 'n2'), isTrue);
      expect(res.any((n) => n['id'] == 'n3'), isTrue);
    });

    test('case insensitive sur notif_type et supporte user_id/idUser', () {
      final list = [
        {
          'id': 'n4',
          'notif_type': 'message',
          'title': 'msg out',
          'content': 'hello',
          'user_id': myId,
        },
        {
          'id': 'n5',
          'notif_type': 'MESSAGE',
          'title': 'msg in',
          'content': 'hey',
          'idUser': 'someone-else',
        },
      ];

      final res = service.filterIncomingNotifications(list, myId);
      expect(res.map((e) => e['id']).toSet(), {'n5'});
    });

    test('si myId est null/empty, ne filtre pas', () {
      final list = [
        {
          'id': 'n6',
          'notif_type': 'MESSAGE',
          'id_user': myId,
        }
      ];
      expect(service.filterIncomingNotifications(list, null).length, 1);
      expect(service.filterIncomingNotifications(list, '').length, 1);
    });
  });
}

