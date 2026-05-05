import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:http/io_client.dart';

enum RockxyRuntime {
  localAppleRuntime,
  androidEmulator,
  physicalDevice,
}

extension RockxyRuntimeLabel on RockxyRuntime {
  String get label {
    switch (this) {
      case RockxyRuntime.localAppleRuntime:
        return 'iOS Simulator / macOS desktop';
      case RockxyRuntime.androidEmulator:
        return 'Android Emulator';
      case RockxyRuntime.physicalDevice:
        return 'Physical iOS or Android device';
    }
  }

  String get hostHint {
    switch (this) {
      case RockxyRuntime.localAppleRuntime:
        return '127.0.0.1';
      case RockxyRuntime.androidEmulator:
        return '10.0.2.2';
      case RockxyRuntime.physicalDevice:
        return '<Device Proxy LAN host>';
    }
  }
}

final class RockxyDebugProxySettings {
  const RockxyDebugProxySettings({
    required this.runtime,
    required this.port,
    required this.physicalDeviceHost,
    this.enabled = true,
    this.allowBadCertificates = true,
  });

  final bool enabled;
  final bool allowBadCertificates;
  final RockxyRuntime runtime;
  final int port;
  final String physicalDeviceHost;

  String get proxyHost {
    switch (runtime) {
      case RockxyRuntime.localAppleRuntime:
        return '127.0.0.1';
      case RockxyRuntime.androidEmulator:
        return '10.0.2.2';
      case RockxyRuntime.physicalDevice:
        return physicalDeviceHost.trim();
    }
  }

  String get proxyHostPort => '$proxyHost:$port';

  bool get hasProxyTarget {
    return enabled &&
        !(runtime == RockxyRuntime.physicalDevice && proxyHost.isEmpty);
  }

  String get displayProxyTarget {
    return hasProxyTarget ? proxyHostPort : 'DIRECT';
  }

  String proxyRuleFor(Uri uri) {
    if (!hasProxyTarget) {
      return 'DIRECT';
    }

    return 'PROXY $proxyHostPort;';
  }

  HttpClient createHttpClient() {
    final client = HttpClient();

    if (enabled) {
      client.findProxy = proxyRuleFor;
    }

    if (allowBadCertificates) {
      // Debug builds only. Remove this before release builds.
      client.badCertificateCallback = (certificate, host, port) => true;
    }

    return client;
  }

  IOClient createPackageHttpClient() {
    return IOClient(createHttpClient());
  }

  Dio createDio() {
    final dio = Dio();
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: createHttpClient,
      validateCertificate:
          allowBadCertificates ? (certificate, host, port) => true : null,
    );
    return dio;
  }
}

enum RockxyHttpClientKind {
  dartHttpClient,
  packageHttp,
  dio,
}

extension RockxyHttpClientKindLabel on RockxyHttpClientKind {
  String get label {
    switch (this) {
      case RockxyHttpClientKind.dartHttpClient:
        return 'Dart HttpClient';
      case RockxyHttpClientKind.packageHttp:
        return 'package:http';
      case RockxyHttpClientKind.dio:
        return 'Dio 5';
    }
  }
}

final class RockxyProbeResult {
  const RockxyProbeResult({
    required this.client,
    required this.statusCode,
    required this.bodyPreview,
    required this.proxyHostPort,
  });

  final RockxyHttpClientKind client;
  final int statusCode;
  final String bodyPreview;
  final String proxyHostPort;
}

final class RockxyDebugProbeClient {
  const RockxyDebugProbeClient(this.settings);

  final RockxyDebugProxySettings settings;

  Future<RockxyProbeResult> get(
    Uri uri, {
    required RockxyHttpClientKind client,
  }) async {
    await _verifyProxyReachable();

    switch (client) {
      case RockxyHttpClientKind.dartHttpClient:
        return _getWithDartHttpClient(uri);
      case RockxyHttpClientKind.packageHttp:
        return _getWithPackageHttp(uri);
      case RockxyHttpClientKind.dio:
        return _getWithDio(uri);
    }
  }

  Future<void> _verifyProxyReachable() async {
    if (!settings.hasProxyTarget) {
      return;
    }

    Socket? socket;
    try {
      socket = await Socket.connect(
        settings.proxyHost,
        settings.port,
        timeout: const Duration(seconds: 2),
      );
    } on SocketException catch (error) {
      throw RockxyProbeException.proxyUnreachable(
        settings: settings,
        error: error,
      );
    } finally {
      socket?.destroy();
    }
  }

  Future<RockxyProbeResult> _getWithDartHttpClient(Uri uri) async {
    final httpClient = settings.createHttpClient();

    try {
      final request = await httpClient.getUrl(uri);
      request.headers.set(HttpHeaders.cacheControlHeader, 'no-cache');

      final response = await request.close();
      final body = await utf8.decodeStream(response);

      return RockxyProbeResult(
        client: RockxyHttpClientKind.dartHttpClient,
        statusCode: response.statusCode,
        bodyPreview: _preview(body),
        proxyHostPort: settings.proxyHostPort,
      );
    } finally {
      httpClient.close(force: true);
    }
  }

  Future<RockxyProbeResult> _getWithPackageHttp(Uri uri) async {
    final client = settings.createPackageHttpClient();

    try {
      final response = await client.get(
        uri,
        headers: const {HttpHeaders.cacheControlHeader: 'no-cache'},
      );

      return RockxyProbeResult(
        client: RockxyHttpClientKind.packageHttp,
        statusCode: response.statusCode,
        bodyPreview: _preview(response.body),
        proxyHostPort: settings.proxyHostPort,
      );
    } finally {
      client.close();
    }
  }

  Future<RockxyProbeResult> _getWithDio(Uri uri) async {
    final dio = settings.createDio();

    try {
      final response = await dio.getUri<Object?>(
        uri,
        options: Options(
          headers: const {HttpHeaders.cacheControlHeader: 'no-cache'},
          responseType: ResponseType.plain,
        ),
      );

      return RockxyProbeResult(
        client: RockxyHttpClientKind.dio,
        statusCode: response.statusCode ?? 0,
        bodyPreview: _preview(response.data?.toString() ?? ''),
        proxyHostPort: settings.proxyHostPort,
      );
    } finally {
      dio.close(force: true);
    }
  }

  static String _preview(String body) {
    final normalized = body.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= 800) {
      return normalized;
    }

    return '${normalized.substring(0, 800)}...';
  }
}

final class RockxyProbeException implements Exception {
  const RockxyProbeException(this.message);

  factory RockxyProbeException.proxyUnreachable({
    required RockxyDebugProxySettings settings,
    required SocketException error,
  }) {
    final socketTarget = error.address == null || error.port == null
        ? ''
        : '\nSocket target: ${error.address!.address}:${error.port}';

    return RockxyProbeException(
      'Rockxy proxy is not reachable at ${settings.proxyHostPort}.\n'
      'Start capture in Rockxy, then make sure the Rockxy port field in this '
      'sample matches the active port shown in Rockxy.$socketTarget',
    );
  }

  final String message;

  @override
  String toString() => message;
}
