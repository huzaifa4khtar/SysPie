/// API response model for service data from the native library.
class ServiceModel {
  final String serviceName;
  final String displayName;
  final int pid;
  final String status;
  final String group;
  final String type;

  const ServiceModel({
    required this.serviceName,
    required this.displayName,
    required this.pid,
    required this.status,
    required this.group,
    required this.type,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      serviceName: json['serviceName'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      pid: json['pid'] as int? ?? 0,
      status: json['status'] as String? ?? 'Unknown',
      group: json['group'] as String? ?? '',
      type: json['type'] as String? ?? '',
    );
  }

  /// Whether this service is currently running.
  bool get isRunning => status == 'Running';

  /// Whether this service is stopped.
  bool get isStopped => status == 'Stopped';
}
