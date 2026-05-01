import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api_exception.dart';
import '../../models/family_model.dart';
import '../../state/app_state.dart';
import 'scan_invite_code_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final TextEditingController _createFamilyController = TextEditingController();
  final TextEditingController _joinFamilyController = TextEditingController();
  final TextEditingController _addMemberController = TextEditingController();
  final TextEditingController _familyTitleController = TextEditingController();

  bool _busy = false;
  bool _inviteRequested = false;
  String? _seededFamilyTitleForId;

  @override
  void dispose() {
    _createFamilyController.dispose();
    _joinFamilyController.dispose();
    _addMemberController.dispose();
    _familyTitleController.dispose();
    super.dispose();
  }

  Future<void> _runAction(Future<void> Function() action) async {
    setState(() {
      _busy = true;
    });

    try {
      await action();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Operation failed. Please try again.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _showPermissionEditor(
    AppState state,
    FamilyMemberModel member,
  ) async {
    final current = Map<String, bool>.from(member.permissions);
    final next = <String, bool>{...current};

    final save = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocal) {
            return AlertDialog(
              title: Text('Permissions - ${member.email}'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  SwitchListTile(
                    value: next['view_location'] ?? true,
                    onChanged: (v) =>
                        setLocal(() => next['view_location'] = v),
                    title: const Text('View location'),
                  ),
                  SwitchListTile(
                    value: next['view_events'] ?? true,
                    onChanged: (v) => setLocal(() => next['view_events'] = v),
                    title: const Text('View events'),
                  ),
                  SwitchListTile(
                    value: next['receive_alerts'] ?? true,
                    onChanged: (v) =>
                        setLocal(() => next['receive_alerts'] = v),
                    title: const Text('Receive alerts'),
                  ),
                  SwitchListTile(
                    value: next['manage_geofence'] ?? false,
                    onChanged: (v) =>
                        setLocal(() => next['manage_geofence'] = v),
                    title: const Text('Manage geofence'),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (save != true) {
      return;
    }

    await _runAction(() async {
      await state.updateFamilyMemberPermissions(
        memberEmail: member.email,
        permissions: next,
      );
    });
  }

  Future<void> _confirmRemoveMember(AppState state, String email) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Remove member?'),
          content: Text('Remove $email from care circle?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Remove'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(() => state.removeFamilyMember(email));
  }

  Future<void> _saveFamilyTitle(AppState state) async {
    await _runAction(() async {
      await state.updateFamilyTitle(_familyTitleController.text.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        final family = state.family;

        if (family != null &&
            state.isPatientRole &&
            !_inviteRequested &&
            state.familyInvite == null) {
          _inviteRequested = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            state.refreshFamilyInviteCode();
          });
        }
        if (family == null) {
          _inviteRequested = false;
          _seededFamilyTitleForId = null;
        } else if (_seededFamilyTitleForId != family.familyId) {
          _familyTitleController.text = family.title;
          _seededFamilyTitleForId = family.familyId;
        }

        if (state.isFamilyRole) {
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
                        'Family account',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This account can monitor linked patients from Family Dashboard. '
                        'Use the Link tab to join by invite QR/code.',
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        if (family == null) {
          return _buildSetup(state);
        }

        return _buildPatientFamilyManagement(state, family);
      },
    );
  }

  Widget _buildSetup(AppState state) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text(
          'Care Circle Setup',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text('Create a family group, or join one using invite code/ID.'),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Create Family',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _createFamilyController,
                  decoration: const InputDecoration(
                    labelText: 'Family name (optional)',
                    prefixIcon: Icon(Icons.group_add_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runAction(() async {
                          await state.createFamily(
                            _createFamilyController.text.trim(),
                          );
                          _createFamilyController.clear();
                        }),
                  icon: const Icon(Icons.add_circle_outline),
                  label: const Text('Create Family'),
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
                  'Join by Invite Code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _joinFamilyController,
                  decoration: const InputDecoration(
                    labelText: 'Invite code / Family ID',
                    prefixIcon: Icon(Icons.login_outlined),
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => _runAction(() async {
                              await state.joinFamilyByInviteCode(
                                _joinFamilyController.text.trim(),
                              );
                              _joinFamilyController.clear();
                            }),
                      icon: const Icon(Icons.people_alt_outlined),
                      label: const Text('Join'),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () async {
                              final scanned = await Navigator.of(context).push<String>(
                                MaterialPageRoute<String>(
                                  builder: (_) => const ScanInviteCodeScreen(),
                                ),
                              );
                              if (!mounted || scanned == null) {
                                return;
                              }
                              _joinFamilyController.text = scanned;
                              await _runAction(() async {
                                await state.joinFamilyByInviteCode(scanned);
                                _joinFamilyController.clear();
                              });
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
      ],
    );
  }

  Widget _buildPatientFamilyManagement(AppState state, FamilyModel family) {
    final invite = state.familyInvite;
    final inviteCode = (invite?['invite_code'] ?? family.familyId).toString();
    final invitePayload =
        (invite?['invite_payload'] ?? 'MEDFAM-${family.familyId}').toString();

    final members = family.members
        .where((item) => item.email != state.user?.email)
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Text('Care Circle', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Invite Family Member (QR + Code)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Center(
                  child: QrImageView(
                    data: invitePayload,
                    size: 180,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  inviteCode,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(letterSpacing: 1.2),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: inviteCode));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Invite code copied.')),
                        );
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Copy Code'),
                    ),
                    OutlinedButton.icon(
                      onPressed: state.refreshFamilyInviteCode,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Regenerate'),
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
                  'Family Title',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (family.isAdmin) ...<Widget>[
                  TextField(
                    controller: _familyTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      hintText: 'Care Circle Alpha',
                      prefixIcon: Icon(Icons.title_outlined),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _saveFamilyTitle(state),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Save Title'),
                  ),
                ] else ...<Widget>[
                  Text(
                    family.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  const Text('Only family admin can edit the title.'),
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
                  'Family Info',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Text('Family ID: ${family.familyId}'),
                Text('Title: ${family.title}'),
                Text('Admin: ${family.admin}'),
                Text('Members: ${family.memberCount}'),
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
                  'Family Members',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (members.isEmpty)
                  const Text('No family members yet.')
                else
                  ...members.map(
                    (member) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        child: Text(
                          member.email.isNotEmpty
                              ? member.email[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(member.email),
                      subtitle: Text(
                        'Age: ${member.age}  |  Role: ${member.role}',
                      ),
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'permissions') {
                            await _showPermissionEditor(state, member);
                          } else if (value == 'remove') {
                            await _confirmRemoveMember(state, member.email);
                          }
                        },
                        itemBuilder: (context) => <PopupMenuEntry<String>>[
                          const PopupMenuItem<String>(
                            value: 'permissions',
                            child: Text('Edit Permissions'),
                          ),
                          const PopupMenuItem<String>(
                            value: 'remove',
                            child: Text('Remove Member'),
                          ),
                        ],
                      ),
                    ),
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
                  'Add Family Member',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _addMemberController,
                  decoration: const InputDecoration(
                    labelText: 'Member email',
                    hintText: 'member@gmail.com',
                    prefixIcon: Icon(Icons.person_add_alt_1),
                  ),
                ),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _runAction(() async {
                          await state.addFamilyMember(
                            _addMemberController.text.trim(),
                          );
                          _addMemberController.clear();
                        }),
                  icon: const Icon(Icons.person_add_alt),
                  label: const Text('Add Member'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                        title: const Text('Leave family?'),
                        content: const Text(
                          'You will be removed from this family and can join/create another one.',
                        ),
                        actions: <Widget>[
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(false),
                            child: const Text('Cancel'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(context).pop(true),
                            child: const Text('Leave'),
                          ),
                        ],
                      );
                    },
                  );

                  if (confirmed == true) {
                    await _runAction(state.leaveFamily);
                  }
                },
          icon: const Icon(Icons.exit_to_app),
          label: const Text('Leave Family'),
        ),
      ],
    );
  }
}
