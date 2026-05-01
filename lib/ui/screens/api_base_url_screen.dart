import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_config.dart';
import '../../core/brand_palette.dart';
import '../../state/app_state.dart';

class ApiBaseUrlScreen extends StatefulWidget {
  const ApiBaseUrlScreen({super.key});

  @override
  State<ApiBaseUrlScreen> createState() => _ApiBaseUrlScreenState();
}

class _ApiBaseUrlScreenState extends State<ApiBaseUrlScreen> {
  final TextEditingController _controller = TextEditingController();

  String? _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await ApiConfig.loadSavedOverride();
    if (!mounted) {
      return;
    }
    _controller.text = saved ?? '';
    setState(() {});
  }

  String? _validate(String raw) {
    final value = raw.trim();
    if (value.isEmpty) {
      return null;
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'Invalid URL. Example: http://192.168.1.10:3006';
    }

    if (kReleaseMode && uri.scheme.toLowerCase() != 'https') {
      return 'Release builds require HTTPS.';
    }

    return null;
  }

  Future<void> _save() async {
    final raw = _controller.text.trim();

    if (raw == '_xotk') {
      final app = context.read<AppState>();
      await app.setDeveloperAuraEnabled(true);
      if (!mounted) {
        return;
      }
      setState(() {
        _status =
            'Developer Aura activated. Secret title unlocked: aura devolper.';
      });
      return;
    }

    final error = _validate(raw);
    if (error != null) {
      setState(() {
        _status = error;
      });
      return;
    }

    setState(() {
      _saving = true;
      _status = null;
    });

    try {
      await ApiConfig.saveOverride(raw);
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Saved. Restart app if needed.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Save failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      await ApiConfig.saveOverride(null);
      if (!mounted) {
        return;
      }
      _controller.text = '';
      setState(() {
        _status = 'Cleared.';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _status = 'Clear failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidates = ApiConfig.candidateBaseUrls();

    return Scaffold(
      appBar: AppBar(title: const Text('Backend Configuration')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'API Base URL',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _controller,
                    enabled: !_saving,
                    autocorrect: false,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API_BASE_URL override',
                      hintText: 'http://192.168.1.10:3006',
                      prefixIcon: Icon(Icons.dns_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Save'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _clear,
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Clear'),
                      ),
                    ],
                  ),
                  if (_status != null) ...<Widget>[
                    const SizedBox(height: 10),
                    Text(
                      _status!,
                      style: TextStyle(
                        color: (_status!.toLowerCase().contains('fail') ||
                                _status!.toLowerCase().contains('invalid') ||
                                _status!.toLowerCase().contains('require'))
                            ? Theme.of(context).colorScheme.error
                            : BrandPalette.primaryDeep,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Tips', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text('Make sure PC and phone are on the same Wi-Fi.'),
                  const SizedBox(height: 6),
                  const Text('Android Emulator: use http://10.0.2.2:3006'),
                  const SizedBox(height: 6),
                  const Text(
                    'Phone on LAN: use http://<PC_LAN_IP>:3006 (example: http://192.168.1.10:3006)',
                  ),
                  if (kReleaseMode) ...<Widget>[
                    const SizedBox(height: 6),
                    const Text(
                      'Release builds require HTTPS.',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 6),
                  const Text(
                    'Easter egg: type _xotk then Save.',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Candidate URLs (current)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (candidates.isEmpty)
                    const Text('No candidates (check configuration).')
                  else
                    ...candidates.map(
                      (u) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(u),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
