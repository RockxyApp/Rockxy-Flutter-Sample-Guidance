import 'package:flutter/material.dart';

import 'rockxy_debug_proxy.dart';

void main() {
  runApp(const RockxyFlutterSampleApp());
}

class RockxyFlutterSampleApp extends StatelessWidget {
  const RockxyFlutterSampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Rockxy Flutter Sample',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF246BFE)),
        useMaterial3: true,
      ),
      home: const RockxyProbeScreen(),
    );
  }
}

class RockxyProbeScreen extends StatefulWidget {
  const RockxyProbeScreen({super.key});

  @override
  State<RockxyProbeScreen> createState() => _RockxyProbeScreenState();
}

class _RockxyProbeScreenState extends State<RockxyProbeScreen> {
  final _portController = TextEditingController(text: '9090');
  final _physicalHostController = TextEditingController();
  final _urlController = TextEditingController(
    text:
        'http://127.0.0.1:43210/rockxy-demo/bootstrap?app=storefront&platform=flutter&build=debug',
  );

  RockxyRuntime _runtime = RockxyRuntime.localAppleRuntime;
  RockxyHttpClientKind _clientKind = RockxyHttpClientKind.dartHttpClient;
  bool _proxyEnabled = true;
  bool _allowBadCertificates = true;
  bool _isLoading = false;
  String? _errorMessage;
  RockxyProbeResult? _result;

  @override
  void dispose() {
    _portController.dispose();
    _physicalHostController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settingsFromForm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rockxy Flutter Sample'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _IntroCard(settings: settings),
            const SizedBox(height: 16),
            _RuntimeSection(
              runtime: _runtime,
              onChanged: (value) => setState(() => _runtime = value),
            ),
            const SizedBox(height: 16),
            _TextFieldCard(
              controller: _portController,
              label: 'Rockxy port',
              hint: '9090',
              helper: 'Use the active port shown in Rockxy.',
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _TextFieldCard(
              controller: _physicalHostController,
              label: 'Device Proxy LAN host',
              hint: '192.168.1.10',
              helper: 'Required only for physical iOS or Android devices.',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _TextFieldCard(
              controller: _urlController,
              label: 'Request URL',
              hint: 'http://127.0.0.1:43210/rockxy-demo/bootstrap',
              helper:
                  'Run the local demo API, send a request, then confirm it appears in Rockxy.',
              keyboardType: TextInputType.url,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            _ClientSection(
              clientKind: _clientKind,
              onChanged: (value) => setState(() => _clientKind = value),
            ),
            const SizedBox(height: 16),
            _SwitchCard(
              title: 'Proxy through Rockxy',
              subtitle: 'Disable only when comparing direct network behavior.',
              value: _proxyEnabled,
              onChanged: (value) => setState(() => _proxyEnabled = value),
            ),
            const SizedBox(height: 12),
            _SwitchCard(
              title: 'Allow debug certificates',
              subtitle:
                  'Debug only. Never ship this setting in release builds.',
              value: _allowBadCertificates,
              onChanged: (value) =>
                  setState(() => _allowBadCertificates = value),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _isLoading ? null : _runProbe,
              icon: _isLoading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.play_arrow),
              label: Text(_isLoading ? 'Sending request...' : 'Send Request'),
            ),
            const SizedBox(height: 20),
            _ResultSection(
              errorMessage: _errorMessage,
              result: _result,
            ),
          ],
        ),
      ),
    );
  }

  RockxyDebugProxySettings _settingsFromForm() {
    final parsedPort = int.tryParse(_portController.text.trim());
    return RockxyDebugProxySettings(
      enabled: _proxyEnabled,
      allowBadCertificates: _allowBadCertificates,
      runtime: _runtime,
      port: parsedPort ?? 9090,
      physicalDeviceHost: _physicalHostController.text,
    );
  }

  Future<void> _runProbe() async {
    final uri = Uri.tryParse(_urlController.text.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      setState(() {
        _result = null;
        _errorMessage = 'Enter a valid absolute URL.';
      });
      return;
    }

    if (uri.scheme != 'http' && uri.scheme != 'https') {
      setState(() {
        _result = null;
        _errorMessage = 'Use an HTTP or HTTPS URL.';
      });
      return;
    }

    final settings = _settingsFromForm();
    if (_proxyEnabled && !settings.hasProxyTarget) {
      setState(() {
        _result = null;
        _errorMessage = 'Enter the Device Proxy LAN host shown by Rockxy.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final client = RockxyDebugProbeClient(settings);
      final result = await client.get(uri, client: _clientKind);

      if (!mounted) {
        return;
      }

      setState(() => _result = result);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.settings});

  final RockxyDebugProxySettings settings;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current proxy target',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SelectableText(
              settings.displayProxyTarget,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Run one request, then confirm Rockxy captures it. This confirms '
              'the proxy path, not device or runtime attribution.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _RuntimeSection extends StatelessWidget {
  const _RuntimeSection({
    required this.runtime,
    required this.onChanged,
  });

  final RockxyRuntime runtime;
  final ValueChanged<RockxyRuntime> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Runtime', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...RockxyRuntime.values.map(
              (value) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ChoiceChip(
                  label: Text('${value.label} (${value.hostHint})'),
                  selected: value == runtime,
                  onSelected: (_) => onChanged(value),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientSection extends StatelessWidget {
  const _ClientSection({
    required this.clientKind,
    required this.onChanged,
  });

  final RockxyHttpClientKind clientKind;
  final ValueChanged<RockxyHttpClientKind> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: DropdownButtonFormField<RockxyHttpClientKind>(
          initialValue: clientKind,
          decoration: const InputDecoration(
            labelText: 'Flutter HTTP client',
            border: OutlineInputBorder(),
          ),
          items: RockxyHttpClientKind.values
              .map(
                (value) => DropdownMenuItem(
                  value: value,
                  child: Text(value.label),
                ),
              )
              .toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}

class _TextFieldCard extends StatelessWidget {
  const _TextFieldCard({
    required this.controller,
    required this.label,
    required this.hint,
    required this.helper,
    required this.onChanged,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String helper;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            helperText: helper,
            hintText: hint,
            labelText: label,
          ),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.errorMessage,
    required this.result,
  });

  final String? errorMessage;
  final RockxyProbeResult? result;

  @override
  Widget build(BuildContext context) {
    final errorMessage = this.errorMessage;
    final result = this.result;

    if (errorMessage != null) {
      return Card(
        color: Theme.of(context).colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(errorMessage),
        ),
      );
    }

    if (result == null) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Response', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Client: ${result.client.label}'),
            Text('Proxy: ${result.proxyHostPort}'),
            Text('Status: ${result.statusCode}'),
            const SizedBox(height: 12),
            SelectableText(result.bodyPreview),
          ],
        ),
      ),
    );
  }
}
