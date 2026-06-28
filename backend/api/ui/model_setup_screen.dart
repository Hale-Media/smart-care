import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/inference/model_descriptor.dart';
import '../core/inference/inference_provider.dart';

/// First-run gate. Lets the user pick a model, downloads it (with progress),
/// then loads it into memory. Routes onward once an engine is ready.
///
/// On a gated host, collect the auth token here (never hardcode it). For a
/// real product, store it with flutter_secure_storage, not SharedPreferences.
class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key, required this.onReady});

  final VoidCallback onReady;

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  ModelDescriptor _selected = kModelCatalogue.first;
  final _tokenController = TextEditingController();
  bool _working = false;
  String? _error;

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _setup() async {
    setState(() {
      _working = true;
      _error = null;
    });
    final provider = context.read<InferenceProvider>();
    try {
      await provider.ensureDownloaded(
        _selected,
        authToken: _tokenController.text.trim().isEmpty
            ? null
            : _tokenController.text.trim(),
      );
      await provider.activate(_selected);
      if (mounted) widget.onReady();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InferenceProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Set up on-device model')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Choose a model',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            RadioGroup<ModelDescriptor>(
              groupValue: _selected,
              onChanged: (v) {
                if (!_working && v != null) setState(() => _selected = v);
              },
              child: Column(
                children:
                    kModelCatalogue
                        .map(
                          (m) => RadioListTile<ModelDescriptor>(
                            value: m,
                            title: Text(m.displayName),
                            subtitle: Text(
                              '~${m.approxSizeMb} MB'
                              '${m.notes != null ? ' · ${m.notes}' : ''}',
                            ),
                          ),
                        )
                        .toList(),
              ),
            ),
            if (_selected.requiresAuthToken) ...[
              const SizedBox(height: 8),
              TextField(
                controller: _tokenController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Download token (gated host)',
                  helperText: 'Injected at runtime — never committed to source',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (provider.isDownloading) ...[
              LinearProgressIndicator(value: provider.downloadFraction),
              const SizedBox(height: 8),
              Text(provider.downloadFraction == null
                  ? 'Downloading…'
                  : 'Downloading ${(provider.downloadFraction! * 100).toStringAsFixed(0)}%'),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(_error!,
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _working ? null : _setup,
              child: Text(_working ? 'Working…' : 'Download & load'),
            ),
          ],
        ),
      ),
    );
  }
}
