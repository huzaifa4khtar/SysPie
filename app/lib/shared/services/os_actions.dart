import 'dart:io';

/// Searches Google for the given process name.
void searchOnline(String processName) {
  if (processName.isEmpty) return;
  final query = Uri.encodeComponent(processName);
  Process.run(
      'cmd', ['/c', 'start', '', 'https://www.google.com/search?q=$query']);
}
