// test/utils/pagination_helper_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide/utils/pagination_helper.dart';

void main() {
  group('PaginationHelper', () {
    test('دەبێت ٢٠ دانە لە جارێک بهێنێت', () async {
      final pagination = PaginationHelper<int>(pageSize: 20);

      await pagination.loadFirstPage((from, to) async {
        return List.generate(to - from + 1, (i) => from + i);
      });

      expect(pagination.items.length, 20);
      expect(pagination.currentPage, 1);
      expect(pagination.hasMore, isTrue);
    });

    test('دەبێت hasMore = false کاتێک داتا کەمە', () async {
      final pagination = PaginationHelper<int>(pageSize: 20);

      await pagination.loadFirstPage((from, to) async {
        return List.generate(5, (i) => i);
      });

      expect(pagination.hasMore, isFalse);
    });
  });
}