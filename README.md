# Rockxy Flutter Sample Guidance

This sample shows how to route Flutter HTTP traffic through Rockxy while keeping
certificate and proxy changes limited to debug builds.

Flutter apps do not always inherit a system proxy automatically. The reliable
manual path is:

1. choose the Rockxy proxy host for the runtime running the app;
2. configure the Flutter HTTP client to use that proxy;
3. complete the iOS or Android certificate trust path;
4. send one known HTTPS request and confirm it appears in Rockxy.

## Runtime Proxy Hosts

| Runtime | Host value |
| --- | --- |
| iOS Simulator | `127.0.0.1:<Rockxy port>` |
| macOS desktop Flutter | `127.0.0.1:<Rockxy port>` |
| Android Emulator | `10.0.2.2:<Rockxy port>` |
| Physical iPhone, iPad, or Android device | `<Device Proxy LAN host>:<Rockxy port>` |

The active Rockxy port is shown in the Rockxy toolbar. For physical devices, use
the Device Proxy LAN host shown in Developer Setup Hub and keep the device on the
same local network as the Mac.

## Step-By-Step Setup

1. Start Rockxy and keep capture enabled.
2. Open Developer Setup Hub > Flutter.
3. Pick the runtime that matches where the Flutter app is running.
4. Use the host and port from the table above.
5. Install and trust the Rockxy certificate for that runtime:
   - iOS Simulator: install/trust the certificate in the simulator.
   - Physical iPhone or iPad: install the certificate profile and enable full
     trust in iOS settings.
   - Android Emulator: install the user certificate and run a debug build that
     trusts user CAs.
   - Physical Android device: set the Wi-Fi proxy to the Device Proxy LAN host,
     install the user certificate, and run a debug build that trusts user CAs.
6. Send one known HTTPS request and confirm it appears in Rockxy.

## Use This Sample

Install FVM once, then run the sample through the project-pinned Flutter SDK:

```sh
brew install fvm
git clone https://github.com/RockxyApp/Rockxy-Flutter-Sample-Guidance.git
cd Rockxy-Flutter-Sample-Guidance
fvm use stable
fvm flutter pub get
fvm flutter run
```

The repository tracks `.fvmrc`, so you can switch versions later without
changing global Flutter:

```sh
fvm use 3.32.8
fvm flutter doctor
fvm flutter test
```

The generated Android debug target already includes the same debug-only trust
configuration shown in `snippets/android/app/src/debug`.

## Copy The Client Setup

The reusable code lives in `lib/rockxy_debug_proxy.dart`. Copy that file into a
debug-only area of your app, choose the runtime, then create the client that your
app already uses.

### Dart HttpClient

```dart
final settings = RockxyDebugProxySettings(
  runtime: RockxyRuntime.localAppleRuntime,
  port: 9090,
  physicalDeviceHost: '',
);

final client = settings.createHttpClient();
final request = await client.getUrl(Uri.parse('https://httpbin.org/get'));
final response = await request.close();
client.close(force: true);
```

### package:http

```dart
final settings = RockxyDebugProxySettings(
  runtime: RockxyRuntime.androidEmulator,
  port: 9090,
  physicalDeviceHost: '',
);

final client = settings.createPackageHttpClient();
final response = await client.get(Uri.parse('https://httpbin.org/get'));
client.close();
```

### Dio 5

```dart
final settings = RockxyDebugProxySettings(
  runtime: RockxyRuntime.physicalDevice,
  port: 9090,
  physicalDeviceHost: '192.168.1.10',
);

final dio = settings.createDio();
final response = await dio.getUri(Uri.parse('https://httpbin.org/get'));
dio.close(force: true);
```

## What To Edit

The app has a small form where you can choose:

- runtime: local Apple runtime, Android Emulator, or physical device;
- Rockxy port;
- Device Proxy LAN host for physical devices;
- HTTPS URL to request;
- client type: Dart `HttpClient`, `package:http`, or Dio 5.

The reusable implementation lives in:

- `lib/rockxy_debug_proxy.dart`
- `lib/main.dart`

## Debug-Only Safety

This sample intentionally uses debug-only certificate bypass code so Rockxy can
inspect HTTPS while you are learning the setup path.

Do not ship release builds with:

- `badCertificateCallback`;
- Dio `validateCertificate` returning `true`;
- Android user-CA trust in release manifests.

For Android, keep user-CA trust under `app/src/debug`, not `app/src/main`.

## Validate In Rockxy

1. Start Rockxy and keep capture running.
2. Open Developer Setup Hub > Flutter.
3. Pick the same runtime host shown in this sample.
4. Run one request from the sample app.
5. Confirm Rockxy captures the request.

Rockxy validation confirms that the request reached Rockxy through the proxy. It
does not prove which device, simulator, emulator, Dart isolate, app, or process
emitted the traffic.
