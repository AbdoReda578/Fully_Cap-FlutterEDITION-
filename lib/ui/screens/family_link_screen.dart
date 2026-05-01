import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_exception.dart';
import '../../state/app_state.dart';
import 'scan_invite_code_screen.dart';

class FamilyLinkScreen extends StatefulWidget {
  const FamilyLinkScreen({super.key});

  @override
  State<FamilyLinkScreen> createState() => _FamilyLinkScreenState();
}

class _FamilyLinkScreenState extends State<FamilyLinkScreen> {
  final TextEditingController _inviteController = TextEditingController();
  bool _joining = false;

  @override
  void dispose() {
    _inviteController.dispose();
    super.dispose();
  }

  Future<void> _join(AppState state) async {
    final raw = _inviteController.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter invite code first.')),
      );
      return;
    }

    setState(() => _joining = true);
    try {
      await state.joinFamilyByInviteCode(raw);
      await state.refreshCareData();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Linked to patient family.')));
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not join using invite code.')),
      );
    } finally {
      if (mounted) {
        setState(() => _joining = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final family = state.family;
        final patients = state.carePatients;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Link to Patient',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Scan the patient invite QR or paste invite code to join care circle.',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _inviteController,
                      enabled: !_joining,
                      decoration: const InputDecoration(
                        labelText: 'Invite Code',
                        hintText: 'MEDFAM-XXXXXXXX',
                        prefixIcon: Icon(Icons.qr_code_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        FilledButton.icon(
                          onPressed: _joining ? null : () => _join(state),
                          icon: _joining
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.link),
                          label: Text(_joining ? 'Joining...' : 'Join via Code'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _joining
                              ? null
                              : () async {
                                  final scanned = await Navigator.of(context)
                                      .push<String>(
                                        MaterialPageRoute<String>(
                                          builder: (_) =>
                                              const ScanInviteCodeScreen(),
                                        ),
                                      );
                                  if (!mounted || scanned == null) {
                                    return;
                                  }
                                  _inviteController.text = scanned;
                                  await _join(state);
                                },
                          icon: const Icon(Icons.qr_code_scanner),
                          label: const Text('Scan QR'),
                        ),
                      ],
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
                      'Current Care Circle',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (family == null) ...<Widget>[
                      const Text('Not linked to any family yet.'),
                    ] else ...<Widget>[
                      Text('Family ID: ${family.familyId}'),
                      Text('Title: ${family.title}'),
                      Text('Admin: ${family.admin}'),
                      Text('Members: ${family.memberCount}'),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () async {
                          try {
                            await state.leaveFamily();
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('You left the family group.'),
                              ),
                            );
                          } catch (_) {
                            if (!context.mounted) {
                              return;
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Could not leave family group.'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('Leave Family'),
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
                    Text(
                      'Linked Patients',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (patients.isEmpty)
                      const Text('No patients linked yet.')
                    else
                      ...patients.map(
                        (p) {
                          final canViewLocation =
                              p.permissions['view_location'] ?? true;
                          final canViewEvents =
                              p.permissions['view_events'] ?? true;
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              p.isOnline ? Icons.circle : Icons.circle_outlined,
                              color: p.isOnline
                                  ? const Color(0xFF22C55E)
                                  : Theme.of(context).disabledColor,
                              size: 14,
                            ),
                            title: Text(p.patientEmail),
                            subtitle: Text(
                              'Last update: ${p.lastUpdateAt ?? '-'}',
                            ),
                            trailing: (!canViewLocation || !canViewEvents)
                                ? const Icon(Icons.lock_outline)
                                : null,
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
