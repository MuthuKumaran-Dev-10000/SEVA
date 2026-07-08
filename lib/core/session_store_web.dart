import 'dart:html' as html;

String? getSessionCode() {
  try {
    return html.window.sessionStorage['active_session_code'];
  } catch (_) {
    return null;
  }
}

void setSessionCode(String code) {
  try {
    html.window.sessionStorage['active_session_code'] = code;
  } catch (_) {}
}
