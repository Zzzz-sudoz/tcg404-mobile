import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

http.Client createSessionClient(Uri baseUrl) =>
    BrowserClient()..withCredentials = true;
Future<void> clearClientSession(http.Client client) async {}
