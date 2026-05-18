import 'package:web/web.dart' as web;

void clearTokenFromUrl() {
  web.window.history.replaceState(null, '', '/');
}

void webNavigate(String url) {
  web.window.location.href = url;
}
