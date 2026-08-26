import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _contact = TextEditingController();
  final _storage = const FlutterSecureStorage();
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final saved = await _storage.read(key: 'emergency_contact');
    if (saved != null && mounted) {
      setState(() => _contact.text = saved);
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _save() async {
    await _storage.write(key: 'emergency_contact', value: _contact.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Emergency contact saved')),
    );
  }

  @override
  void dispose() {
    _contact.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          TextField(
            controller: _contact,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: 'Emergency contact phone',
              hintText: '+919800000000',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _loaded ? _save : null,
            child: const Text('Save'),
          ),
          const SizedBox(height: 32),
          Text(
            'This contact is notified automatically via SMS '
            'if you enter a flagged unsafe zone.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
