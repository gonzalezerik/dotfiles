// px13-blue glass theme (userChrome.css / userContent.css next to this file)
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("ui.systemUsesDarkTheme", 1);
user_pref("layout.css.prefers-color-scheme.content-override", 0);
user_pref("browser.tabs.allow_transparent_browser", true);
// Built-in dark mode for message bodies (toggle in the message header)
user_pref("mail.dark-reader.enabled", true);
user_pref("mail.dark-reader.show-toggle", true);
// Telemetry off
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("toolkit.telemetry.archive.enabled", false);
// Opaque backstop behind content (message bodies, settings tabs) = foot bg
user_pref("browser.display.background_color.dark", "#0A0D10");
user_pref("browser.display.foreground_color.dark", "#C9D6DE");
