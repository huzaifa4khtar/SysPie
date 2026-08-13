class ChartFormatters {
  const ChartFormatters._();

  static String formatCacheKB(int kb) {
    if (kb >= 1024) {
      final mb = kb / 1024;
      return '${mb.toStringAsFixed(1)} MB';
    }
    return '$kb KB';
  }

  static String formatMemory(double mb) {
    if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
    return '${mb.toStringAsFixed(1)} MB';
  }

  static String formatMemoryPair(double usedMB, double totalMB) {
    if (usedMB >= 1024 || totalMB >= 1024) {
      return '${(usedMB / 1024).toStringAsFixed(1)}/${(totalMB / 1024).toStringAsFixed(1)} GB';
    }
    return '${usedMB.toStringAsFixed(1)}/${totalMB.toStringAsFixed(0)} MB';
  }

  static String formatSpeed(double bytesPerSec) {
    if (bytesPerSec >= 1024 * 1024) {
      return '${(bytesPerSec / (1024 * 1024)).toStringAsFixed(1)} MB/s';
    }
    if (bytesPerSec >= 1024) {
      return '${(bytesPerSec / 1024).toStringAsFixed(1)} KB/s';
    }
    return '${bytesPerSec.toStringAsFixed(0)} B/s';
  }

  static String formatNetworkSpeed(double bytesPerSec) {
    final kbps = bytesPerSec * 8.0 / 1000.0;
    if (kbps >= 1000) {
      return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
    }
    if (kbps >= 1) {
      return '${kbps.toStringAsFixed(0)} Kbps';
    }
    return '0 Kbps';
  }

  static String formatDuration(int seconds) {
    final days = seconds ~/ 86400;
    final hrs = (seconds % 86400) ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '$days:${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }
}
