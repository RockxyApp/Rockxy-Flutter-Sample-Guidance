import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rockxy_flutter_sample_guidance/rockxy_debug_proxy.dart';

void main() {
  group('RockxyDebugProxySettings', () {
    test('uses localhost for iOS Simulator and desktop Flutter', () {
      const settings = RockxyDebugProxySettings(
        runtime: RockxyRuntime.localAppleRuntime,
        port: 9090,
        physicalDeviceHost: '192.168.1.20',
      );

      expect(settings.proxyHostPort, '127.0.0.1:9090');
      expect(settings.proxyRuleFor(Uri.parse('https://example.com')),
          'PROXY 127.0.0.1:9090;');
    });

    test('uses 10.0.2.2 for Android Emulator', () {
      const settings = RockxyDebugProxySettings(
        runtime: RockxyRuntime.androidEmulator,
        port: 9090,
        physicalDeviceHost: '192.168.1.20',
      );

      expect(settings.proxyHostPort, '10.0.2.2:9090');
      expect(settings.proxyRuleFor(Uri.parse('https://example.com')),
          'PROXY 10.0.2.2:9090;');
    });

    test('uses the Device Proxy LAN host for physical devices', () {
      const settings = RockxyDebugProxySettings(
        runtime: RockxyRuntime.physicalDevice,
        port: 9090,
        physicalDeviceHost: '192.168.1.20',
      );

      expect(settings.proxyHostPort, '192.168.1.20:9090');
      expect(settings.proxyRuleFor(Uri.parse('https://example.com')),
          'PROXY 192.168.1.20:9090;');
    });

    test('falls back to DIRECT when physical host is missing', () {
      const settings = RockxyDebugProxySettings(
        runtime: RockxyRuntime.physicalDevice,
        port: 9090,
        physicalDeviceHost: '',
      );

      expect(settings.hasProxyTarget, isFalse);
      expect(settings.displayProxyTarget, 'DIRECT');
      expect(settings.proxyRuleFor(Uri.parse('https://example.com')), 'DIRECT');
    });

    test('proxy unreachable message points to the configured Rockxy port', () {
      const settings = RockxyDebugProxySettings(
        runtime: RockxyRuntime.localAppleRuntime,
        port: 9090,
        physicalDeviceHost: '',
      );
      final error = SocketException(
        'Connection refused',
        address: InternetAddress.loopbackIPv4,
        port: 58325,
      );

      final exception = RockxyProbeException.proxyUnreachable(
        settings: settings,
        error: error,
      );

      expect(exception.toString(), contains('127.0.0.1:9090'));
      expect(exception.toString(), isNot(contains('Socket target')));
      expect(exception.toString(), isNot(contains('127.0.0.1:58325')));
    });
  });
}
