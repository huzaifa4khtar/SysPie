import 'package:flutter_test/flutter_test.dart';
import 'package:syspie/features/charts/chart_formatters.dart';

void main() {
  group('ChartFormatters.formatCacheKB', () {
    test('keeps small values in KB', () {
      expect(ChartFormatters.formatCacheKB(0), '0 KB');
      expect(ChartFormatters.formatCacheKB(384), '384 KB');
      expect(ChartFormatters.formatCacheKB(1023), '1023 KB');
    });

    test('converts to MB at or above 1024 KB with one decimal', () {
      expect(ChartFormatters.formatCacheKB(1024), '1.0 MB');
      expect(ChartFormatters.formatCacheKB(2048), '2.0 MB');
      expect(ChartFormatters.formatCacheKB(6144), '6.0 MB');
    });

    test('keeps MB fraction for non-whole values', () {
      expect(ChartFormatters.formatCacheKB(1536), '1.5 MB');
      expect(ChartFormatters.formatCacheKB(12288), '12.0 MB');
    });
  });
}