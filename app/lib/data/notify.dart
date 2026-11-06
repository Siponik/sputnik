// Уведомления Windows без лишних пакетов: всплывающее сообщение через PowerShell (Windows.UI.Notifications).
import 'dart:io';

String _esc(String s) =>
    s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;').replaceAll("'", "''");

Future<void> notify(String title, String body) async {
  if (!Platform.isWindows) return;
  final xml =
      '<toast><visual><binding template="ToastGeneric"><text>${_esc(title)}</text><text>${_esc(body)}</text></binding></visual></toast>';
  final ps =
      r'[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null;'
      r'[Windows.Data.Xml.Dom.XmlDocument, Windows.Data.Xml.Dom.XmlDocument, ContentType = WindowsRuntime] > $null;'
      r'$x = New-Object Windows.Data.Xml.Dom.XmlDocument;'
      "\$x.LoadXml('$xml');"
      r'$t = New-Object Windows.UI.Notifications.ToastNotification $x;'
      r"[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Спутник').Show($t);";
  try {
    await Process.run('powershell', ['-NoProfile', '-WindowStyle', 'Hidden', '-Command', ps]);
  } catch (_) {}
}
