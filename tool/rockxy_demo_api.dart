import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final port = _portFrom(arguments) ?? 43210;
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

  stdout.writeln('Rockxy demo API listening on http://127.0.0.1:$port');
  stdout.writeln('Press Ctrl+C to stop.');

  await for (final request in server) {
    unawaited(_handle(request));
  }
}

int? _portFrom(List<String> arguments) {
  final portIndex = arguments.indexOf('--port');
  if (portIndex == -1 || portIndex + 1 >= arguments.length) {
    return null;
  }

  return int.tryParse(arguments[portIndex + 1]);
}

Future<void> _handle(HttpRequest request) async {
  final startedAt = DateTime.now().toUtc();
  final path = request.uri.path;

  if (path.startsWith('/rockxy-demo/status/')) {
    final code = int.tryParse(path.split('/').last) ?? HttpStatus.badRequest;
    _writeJSON(
      request.response,
      statusCode: code,
      body: {
        'ok': code >= 200 && code < 400,
        'scenario': 'status',
        'statusCode': code,
        'requestId': _requestId(startedAt),
      },
    );
    return;
  }

  if (path.startsWith('/rockxy-demo/delay/')) {
    final seconds = int.tryParse(path.split('/').last) ?? 1;
    await Future<void>.delayed(Duration(seconds: seconds.clamp(0, 10)));
    _writeJSON(
      request.response,
      body: _demoBody(request, startedAt, scenario: 'delayed-response'),
    );
    return;
  }

  if (path.startsWith('/rockxy-demo/')) {
    _writeJSON(
      request.response,
      body: _demoBody(
        request,
        startedAt,
        scenario: path.replaceFirst('/rockxy-demo/', ''),
      ),
    );
    return;
  }

  _writeJSON(
    request.response,
    statusCode: HttpStatus.notFound,
    body: {
      'ok': false,
      'error': 'Unknown demo route',
      'path': path,
    },
  );
}

Map<String, Object?> _demoBody(
  HttpRequest request,
  DateTime startedAt, {
  required String scenario,
}) {
  return {
    'ok': true,
    'scenario': scenario,
    'requestId': _requestId(startedAt),
    'receivedAt': startedAt.toIso8601String(),
    'method': request.method,
    'path': request.uri.path,
    'query': request.uri.queryParameters,
    'demoAccount': {
      'userId': 'demo-user-001',
      'plan': 'trial',
      'region': 'us',
    },
    'demoCart': {
      'cartId': 'demo-cart-2026',
      'items': 3,
      'subtotal': 64.50,
      'currency': 'USD',
    },
  };
}

String _requestId(DateTime startedAt) {
  return 'demo-${startedAt.microsecondsSinceEpoch}';
}

void _writeJSON(
  HttpResponse response, {
  int statusCode = HttpStatus.ok,
  required Map<String, Object?> body,
}) {
  final payload = const JsonEncoder.withIndent('  ').convert(body);

  response
    ..statusCode = statusCode
    ..headers.contentType = ContentType.json
    ..headers.set(HttpHeaders.cacheControlHeader, 'no-store')
    ..write(payload);

  unawaited(response.close());
}
