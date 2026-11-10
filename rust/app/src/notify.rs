//! Уведомления Windows (пока приложение открыто). Без лишних зависимостей: PowerShell и toast WinRT.
#[cfg(windows)]
pub fn show(title: &str, body: &str) {
    use std::os::windows::process::CommandExt;
    let esc = |x: &str| x.replace('&', "&amp;").replace('<', "&lt;").replace('>', "&gt;").replace('\'', "''");
    let script = format!(
        "[Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]>$null;\
         $x=[Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent(1);\
         $t=$x.GetElementsByTagName('text');$t.Item(0).InnerText='{}';$t.Item(1).InnerText='{}';\
         [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Спутник').Show([Windows.UI.Notifications.ToastNotification]::new($x))",
        esc(title), esc(body));
    let _ = std::process::Command::new("powershell").args(["-NoProfile", "-Command", &script]).creation_flags(0x0800_0000).spawn();
}

#[cfg(not(windows))]
pub fn show(title: &str, body: &str) {
    eprintln!("[уведомление] {title}: {body}");
}
