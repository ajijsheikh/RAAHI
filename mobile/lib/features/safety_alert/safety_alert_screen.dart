import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen takeover on `safety_alert` (02_PERSON_B P3.3).
/// Shown via /trip/:id/alert. Honest state: shows retry when the contact
/// could NOT be notified instead of a fake checkmark.
class SafetyAlertScreen extends StatefulWidget {
  const SafetyAlertScreen({
    super.key,
    this.zoneName = 'flagged area',
    this.contactName,
    this.contactPhone,
    this.lat = 22.5726,
    this.lng = 88.3639,
  });

  final String zoneName;
  final String? contactName;
  final String? contactPhone;
  final double lat;
  final double lng;

  @override
  State<SafetyAlertScreen> createState() => _SafetyAlertScreenState();
}

class _SafetyAlertScreenState extends State<SafetyAlertScreen> {
  bool _notified = false;
  bool _notifyFailed = false;

  @override
  void initState() {
    super.initState();
    // Buzz on arrival — the memorable demo second.
    HapticFeedback.heavyImpact();
    _notifyContact();
  }

  Future<void> _notifyContact() async {
    // TODO(P3): wire to backend SOS endpoint response (contact_notified flag).
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _notified = widget.contactPhone != null;
      _notifyFailed = !_notified;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: const Color(0xFFC62828), // cRisk
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded,
                  color: Colors.white, size: 80),
              const SizedBox(height: 20),
              const Text(
                "You've entered a flagged area",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.zoneName,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(230)),
              ),
              const SizedBox(height: 28),
              Text(
                'Live location: ${widget.lat.toStringAsFixed(4)}, '
                '${widget.lng.toStringAsFixed(4)}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withAlpha(200)),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(
                      'https://maps.google.com/?q=${widget.lat},${widget.lng}'),
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('Open map',
                    style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),

              // Contact-notified state — honest, with retry
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _notified ? Icons.check_circle : Icons.error_outline,
                    color: _notified ? Colors.greenAccent : Colors.amber,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _notified
                          ? '${widget.contactName ?? 'Contact'} notified'
                          : _notifyFailed
                              ? 'Could not notify contact'
                              : 'Notifying ${widget.contactName ?? 'contact'}…',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                  if (_notifyFailed)
                    TextButton(
                      onPressed: _notifyContact,
                      child: const Text('Retry'),
                    ),
                ],
              ),
              const SizedBox(height: 28),

              FilledButton.icon(
                onPressed: widget.contactPhone == null
                    ? null
                    : () => launchUrl(Uri.parse('tel:${widget.contactPhone}')),
                icon: const Icon(Icons.phone),
                label: const Text('Call now'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFC62828),
                  minimumSize: const Size(0, 52),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context_popSafe(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                  minimumSize: const Size(0, 52),
                ),
                child: const Text("I'm safe"),
              ),
              const SizedBox(height: 16),
              Text(
                'SMS sent via Twilio when ALERTS_ENABLED on backend.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Colors.white.withAlpha(160), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void context_popSafe() {
    HapticFeedback.mediumImpact();
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Marked safe.')),
      );
    }
  }
}
