# Rockxy Flutter Sample Guidance

This sample shows how to route Flutter HTTP traffic through Rockxy while keeping
certificate and proxy changes limited to debug builds.

Flutter apps do not always inherit a system proxy automatically. The reliable
manual path is:

1. choose the Rockxy proxy host for the runtime running the app;
2. copy Rockxy's active proxy port from the Rockxy app into the Flutter client;
3. run the local demo API on this Mac;
4. send one known request and confirm it appears in Rockxy.

For HTTPS inspection, complete the iOS or Android certificate trust path after
the HTTP capture path is working.

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
4. Copy the active Rockxy proxy port from the Rockxy toolbar.
5. Paste that value into the sample app's `Rockxy port` field.
6. Use the runtime host from the table above.
7. Run the local demo API:

```sh
fvm dart run tool/rockxy_demo_api.dart --port 43210
```

8. Run the Flutter sample and send the default request.
9. Confirm Rockxy captures `GET http://127.0.0.1:43210/rockxy-demo/bootstrap`.

For HTTPS app traffic, also install and trust the Rockxy certificate for that
runtime:

   - iOS Simulator: install/trust the certificate in the simulator.
   - Physical iPhone or iPad: install the certificate profile and enable full
     trust in iOS settings.
   - Android Emulator: install the user certificate and run a debug build that
     trusts user CAs.
   - Physical Android device: set the Wi-Fi proxy to the Device Proxy LAN host,
     install the user certificate, and run a debug build that trusts user CAs.

## Use This Sample

Install FVM once, then run the sample through the project-pinned Flutter SDK:

```sh
brew install fvm
git clone https://github.com/RockxyApp/Rockxy-Flutter-Sample-Guidance.git
cd Rockxy-Flutter-Sample-Guidance
fvm use stable
fvm flutter pub get
fvm dart run tool/rockxy_demo_api.dart --port 43210
```

In another terminal, run the Flutter app:

```sh
fvm flutter run
```

Before pressing `Send Request`, copy the active proxy port from Rockxy and paste
it into the sample app's `Rockxy port` field. Do not assume `9090`; Rockxy can
run on another configured or fallback port, such as `8888`.

The repository tracks `.fvmrc`, so you can switch versions later without
changing global Flutter:

```sh
fvm use 3.32.8
fvm flutter doctor
fvm flutter test
```

The generated Android debug target already includes the same debug-only trust
configuration shown in `snippets/android/app/src/debug`.

## Create Demo Traffic

Use harmless, clearly fake data when recording a Rockxy demo. The sample app can
send any HTTP or HTTPS `GET` URL. The recommended demo uses the local API in
`tool/rockxy_demo_api.dart` so the capture does not depend on a third-party
service or external network availability.

Rockxy can capture this loopback demo when the Flutter client explicitly routes
the request through Rockxy. Do not rely on the operating system proxy alone for
localhost traffic because system bypass settings commonly exclude `localhost`
and `127.0.0.1`.

### Recommended Demo Flow

Paste these URLs into the sample app one at a time and send each request through
Rockxy:

```text
http://127.0.0.1:43210/rockxy-demo/bootstrap?app=storefront&platform=flutter&build=debug
http://127.0.0.1:43210/rockxy-demo/profile?user_id=demo-user-001&plan=trial&region=us
http://127.0.0.1:43210/rockxy-demo/products?category=coffee&currency=USD&page=1
http://127.0.0.1:43210/rockxy-demo/cart?cart_id=demo-cart-2026&items=3&subtotal=64.50
http://127.0.0.1:43210/rockxy-demo/checkout?order_id=demo-order-1001&payment_method=sandbox_card
```

This creates a professional-looking capture timeline:

- bootstrap request for app startup behavior;
- profile request with fake account metadata;
- product listing request with pagination and currency;
- cart request with fake order state;
- checkout request that uses an obvious sandbox payment label.

### Error And Latency Cases

Capture one or two failure cases after the successful flow so the demo shows how
Rockxy helps inspect edge cases:

```text
http://127.0.0.1:43210/rockxy-demo/status/404
http://127.0.0.1:43210/rockxy-demo/status/500
http://127.0.0.1:43210/rockxy-demo/delay/2?scenario=slow_checkout&order_id=demo-order-1001
```

Use these to demonstrate status filtering, retry debugging, and slow request
inspection.

### Generate Your Own Safe Demo URLs

Keep demo values descriptive and fake. Prefer IDs such as `demo-user-001`,
`demo-cart-2026`, and `sandbox_card` instead of names, email addresses, access
tokens, session cookies, or production identifiers.

```dart
final demoUrl = Uri.http(
  '127.0.0.1:43210',
  '/rockxy-demo/products',
  {
    'category': 'coffee',
    'currency': 'USD',
    'page': '1',
    'source': 'flutter_debug_sample',
  },
);
```

Then paste `demoUrl.toString()` into the sample app or pass it directly to the
client code in `lib/rockxy_debug_proxy.dart`.

## Copy The Client Setup

The reusable code lives in `lib/rockxy_debug_proxy.dart`. Copy that file into a
debug-only area of your app, choose the runtime, then create the client that your
app already uses.

### Dart HttpClient

```dart
final settings = RockxyDebugProxySettings(
  runtime: RockxyRuntime.localAppleRuntime,
  // Replace this with the active proxy port copied from Rockxy.
  port: 8888,
  physicalDeviceHost: '',
);

final client = settings.createHttpClient();
final request = await client.getUrl(
  Uri.parse('http://127.0.0.1:43210/rockxy-demo/bootstrap'),
);
final response = await request.close();
client.close(force: true);
```

### package:http

```dart
final settings = RockxyDebugProxySettings(
  runtime: RockxyRuntime.androidEmulator,
  // Replace this with the active proxy port copied from Rockxy.
  port: 8888,
  physicalDeviceHost: '',
);

final client = settings.createPackageHttpClient();
final response = await client.get(
  Uri.parse('http://127.0.0.1:43210/rockxy-demo/bootstrap'),
);
client.close();
```

### Dio 5

```dart
final settings = RockxyDebugProxySettings(
  runtime: RockxyRuntime.physicalDevice,
  // Replace this with the active proxy port copied from Rockxy.
  port: 8888,
  physicalDeviceHost: '192.168.1.10',
);

final dio = settings.createDio();
final response = await dio.getUri(
  Uri.parse('http://127.0.0.1:43210/rockxy-demo/bootstrap'),
);
dio.close(force: true);
```

## What To Edit

The app has a small form where you can choose:

- runtime: local Apple runtime, Android Emulator, or physical device;
- Rockxy port copied from the active Rockxy app;
- Device Proxy LAN host for physical devices;
- HTTP or HTTPS URL to request;
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
4. Copy the active Rockxy proxy port into the sample app.
5. Run one request from the sample app.
6. Confirm Rockxy captures the request.

Rockxy validation confirms that the request reached Rockxy through the proxy. It
does not prove which device, simulator, emulator, Dart isolate, app, or process
emitted the traffic.

## Troubleshooting

### Connection refused on 127.0.0.1

If the app shows an error like:

```text
Rockxy proxy is not reachable at 127.0.0.1:<copied Rockxy port>.
```

use the `Rockxy proxy is not reachable at ...` line as the attempted proxy
endpoint. Raw Dart `SocketException` details can include an OS-assigned local
socket port, so do not copy that raw port into the Rockxy port field.

When `Proxy through Rockxy` is enabled, this usually means the Rockxy proxy is
not listening on the port entered in the sample app.

Check these in order:

1. Start capture in Rockxy.
2. Copy the active Rockxy port from the Rockxy toolbar.
3. Paste that value into the sample app's `Rockxy port` field.
4. Keep the runtime set to `iOS Simulator / macOS desktop` when running on macOS.
5. Keep the local demo API running in a separate terminal:

```sh
fvm dart run tool/rockxy_demo_api.dart --port 43210
```

For the default local demo, Rockxy and the sample should use two different
ports:

- Rockxy proxy: the active port shown in Rockxy, for example `8888` or `9090`.
- Demo API: `43210`.

Do not put the demo API port into the `Rockxy port` field.
