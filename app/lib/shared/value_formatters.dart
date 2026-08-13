/// Shared value formatters that convert raw resource readings like CPU
/// percent, memory in MB, disk and network throughput, and GPU percent into
/// the readable strings shown in the data tables.
library;

String formatCpuPercent(double percent) {
  if (percent <= 0) return '0%';
  if (percent < 0.1) return '<0.1%';
  return '${percent.toStringAsFixed(1)}%';
}

String formatMemoryMB(double mb) {
  if (mb >= 1024) return '${(mb / 1024).toStringAsFixed(1)} GB';
  if (mb <= 0) return '0 MB';
  return '${mb.toStringAsFixed(1)} MB';
}

String formatDiskMBps(double mbPerSec) {
  if (mbPerSec <= 0) return '0 KB/s';
  double kBps = mbPerSec * 1024.0;
  if (kBps >= 1024) return '${(kBps / 1024).toStringAsFixed(1)} MB/s';
  return '${kBps.toStringAsFixed(1)} KB/s';
}

String formatNetworkBps(double bps) {
  if (bps <= 0) return '0 Kbps';
  double kbps = bps * 8.0 / 1000.0;
  if (kbps >= 1000) return '${(kbps / 1000).toStringAsFixed(1)} Mbps';
  return '${kbps.toStringAsFixed(1)} Kbps';
}

String formatGpuPercent(double percent) {
  if (percent <= 0) return '0.0%';
  return '${percent.toStringAsFixed(1)}%';
}
