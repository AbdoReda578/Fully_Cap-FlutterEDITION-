import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user_profile.dart';
import '../../core/brand_palette.dart';
import '../../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (BuildContext context, AppState state, _) {
        final profile = state.profile;
        if (profile == null) {
          return const Center(child: Text('Profile is not ready yet.'));
        }

        final email = state.user?.email ?? profile.email;
        final displayName = profile.displayName.trim().isEmpty
            ? email.split('@').first
            : profile.displayName.trim();
        final todayGoal = profile.dailyGoalTaken <= 0
            ? 1
            : profile.dailyGoalTaken;
        final todayProgress = (state.todayTakenCount / todayGoal)
            .clamp(0, 1)
            .toDouble();
        final nextXpMilestone = ((state.profileXp ~/ 100) + 1) * 100;
        final toNextMilestone = nextXpMilestone - state.profileXp;

        return DefaultTabController(
          length: 6,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
              _ProfileHeader(
                displayName: displayName,
                email: email,
                profile: profile,
                level: state.profileLevel,
                league: state.profileLeague,
                developerAuraEnabled: state.developerAuraEnabled,
                activeFrameId: state.activeAvatarFrameId,
                activeFrameLabel:
                    state.avatarFrameById(state.activeAvatarFrameId)?.label ??
                    'Classic Frame',
                onEdit: () => _showEditProfileDialog(context, state, profile),
                onPickPhoto: () async {
                  try {
                    await state.pickProfilePicture();
                  } catch (error) {
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                onClearPhoto:
                    profile.avatarImageBase64 == null ||
                        profile.avatarImageBase64!.trim().isEmpty
                    ? null
                    : () async {
                        await state.clearProfilePicture();
                      },
              ),
              const SizedBox(height: 12),
              _SocialProof(
                streakDays: profile.currentStreakDays,
                xp: state.profileXp,
                league: state.profileLeague,
                adherenceRate: state.adherenceRate,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Weekly Pulse',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: todayProgress,
                        minHeight: 8,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Today: ${state.todayTakenCount}/$todayGoal taken - Next reward in $toNextMilestone XP',
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: Theme.of(context).cardColor,
                ),
                child: const TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: <Widget>[
                    Tab(text: 'Overview'),
                    Tab(text: 'Achievements'),
                    Tab(text: 'Stats'),
                    Tab(text: 'Titles'),
                    Tab(text: 'Frames'),
                    Tab(text: 'Activity'),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: MediaQuery.of(context).size.height * 0.92,
                child: TabBarView(
                  children: <Widget>[
                    _OverviewTab(state: state, profile: profile),
                    _AchievementsTab(profile: profile),
                    _StatsTab(state: state, profile: profile),
                    _TitlesTab(state: state),
                    _FramesTab(state: state),
                    _ActivityTab(profile: profile),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showEditProfileDialog(
    BuildContext context,
    AppState state,
    UserProfile profile,
  ) async {
    final nameController = TextEditingController(text: profile.displayName);
    final titleController = TextEditingController(text: profile.title);
    int dailyGoal = profile.dailyGoalTaken;

    final save = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setLocal) {
            return AlertDialog(
              title: const Text('Edit Profile'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(
                        labelText: 'Display Name',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Title'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<int>(
                      initialValue: dailyGoal,
                      decoration: const InputDecoration(
                        labelText: 'Daily Goal',
                      ),
                      items: const <DropdownMenuItem<int>>[
                        DropdownMenuItem(value: 1, child: Text('1 / day')),
                        DropdownMenuItem(value: 2, child: Text('2 / day')),
                        DropdownMenuItem(value: 3, child: Text('3 / day')),
                        DropdownMenuItem(value: 4, child: Text('4 / day')),
                        DropdownMenuItem(value: 5, child: Text('5 / day')),
                      ],
                      onChanged: (int? value) {
                        if (value != null) {
                          setLocal(() => dailyGoal = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
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

    await state.updateProfile(
      displayName: nameController.text,
      title: titleController.text,
    );
    await state.setProfileDailyGoal(dailyGoal);
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.displayName,
    required this.email,
    required this.profile,
    required this.level,
    required this.league,
    required this.developerAuraEnabled,
    required this.activeFrameId,
    required this.activeFrameLabel,
    required this.onEdit,
    required this.onPickPhoto,
    required this.onClearPhoto,
  });

  final String displayName;
  final String email;
  final UserProfile profile;
  final int level;
  final String league;
  final bool developerAuraEnabled;
  final String activeFrameId;
  final String activeFrameLabel;
  final VoidCallback onEdit;
  final Future<void> Function() onPickPhoto;
  final Future<void> Function()? onClearPhoto;

  List<Color> _frameColors(String frameId) {
    switch (frameId) {
      case 'fire':
        return const <Color>[BrandPalette.accentCyan, BrandPalette.accentTeal];
      case 'ice':
        return const <Color>[BrandPalette.accentTeal, BrandPalette.primaryBlue];
      case 'aura':
        return const <Color>[
          BrandPalette.primaryViolet,
          BrandPalette.primaryDeep,
        ];
      case 'guardian':
        return const <Color>[
          BrandPalette.primaryBlue,
          BrandPalette.primaryDeep,
        ];
      default:
        return const <Color>[
          BrandPalette.primaryBlue,
          BrandPalette.primaryViolet,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final initial = displayName.isEmpty ? 'M' : displayName[0].toUpperCase();
    final frameColors = _frameColors(activeFrameId);
    final chipBackground = BrandPalette.surfaceSoftByMode(context);
    Uint8List? avatarBytes;
    final rawImage = profile.avatarImageBase64;
    if (rawImage != null && rawImage.trim().isNotEmpty) {
      try {
        avatarBytes = base64Decode(rawImage);
      } catch (_) {
        avatarBytes = null;
      }
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: BrandPalette.pageGradient(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: <Widget>[
            Column(
              children: <Widget>[
                GestureDetector(
                  onTap: onPickPhoto,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: frameColors,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: BrandPalette.primaryBlue,
                      backgroundImage: avatarBytes == null
                          ? null
                          : MemoryImage(avatarBytes),
                      child: avatarBytes == null
                          ? Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 24,
                              ),
                            )
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  activeFrameLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                TextButton(
                  onPressed: onPickPhoto,
                  child: const Text('Add Photo'),
                ),
                if (onClearPhoto != null)
                  TextButton(
                    onPressed: onClearPhoto,
                    child: const Text('Remove'),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    displayName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text('@$email', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: <Widget>[
                      Chip(label: Text('Level $level')),
                      Chip(label: Text('$league League')),
                      if (profile.title.trim().isNotEmpty)
                        Chip(
                          label: Text(profile.title.trim()),
                          backgroundColor: chipBackground,
                        ),
                      if (developerAuraEnabled)
                        Chip(
                          avatar: Icon(Icons.auto_awesome, size: 16),
                          label: Text('Developer Aura'),
                          backgroundColor: chipBackground,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Edit profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialProof extends StatelessWidget {
  const _SocialProof({
    required this.streakDays,
    required this.xp,
    required this.league,
    required this.adherenceRate,
  });

  final int streakDays;
  final int xp;
  final String league;
  final double adherenceRate;

  @override
  Widget build(BuildContext context) {
    Widget box(IconData icon, String label, String value) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: Theme.of(context).cardColor,
          ),
          child: Column(
            children: <Widget>[
              Icon(icon, size: 18),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
              Text(label, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      );
    }

    return Row(
      children: <Widget>[
        box(Icons.local_fire_department_outlined, 'Streak', '$streakDays d'),
        const SizedBox(width: 8),
        box(Icons.bolt_outlined, 'XP', '$xp'),
        const SizedBox(width: 8),
        box(Icons.emoji_events_outlined, 'League', league),
        const SizedBox(width: 8),
        box(
          Icons.favorite_outline,
          'Adherence',
          '${adherenceRate.toStringAsFixed(0)}%',
        ),
      ],
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.state, required this.profile});

  final AppState state;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final topBadge = profile.bestStreakDays >= 7
        ? 'Steady Week'
        : profile.totalTaken >= 1
        ? 'First Dose'
        : 'Starting';

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: <Widget>[
        _SimpleCard(
          title: 'This Week Progress',
          body: 'Taken in last 7 days: ${state.weeklyTakenCount}',
        ),
        const SizedBox(height: 10),
        _SimpleCard(title: 'Top Achievement', body: topBadge),
        const SizedBox(height: 10),
        _SimpleCard(
          title: 'Current Goal',
          body: 'Daily goal is ${profile.dailyGoalTaken} taken reminders.',
        ),
      ],
    );
  }
}

class _AchievementsTab extends StatelessWidget {
  const _AchievementsTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    final badges = <({String name, int current, int target})>[
      (name: 'First Dose', current: profile.totalTaken, target: 1),
      (name: 'Steady Week', current: profile.bestStreakDays, target: 7),
      (name: 'Calm Captain', current: profile.totalTaken, target: 20),
      (name: 'Medication Master', current: profile.totalTaken, target: 50),
    ];

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      itemCount: badges.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (BuildContext context, int index) {
        final badge = badges[index];
        final unlocked = badge.current >= badge.target;
        final progress = (badge.current / badge.target).clamp(0, 1).toDouble();
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(
                      unlocked
                          ? Icons.emoji_events
                          : Icons.emoji_events_outlined,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        badge.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(unlocked ? 'Unlocked' : 'Locked'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress, minHeight: 8),
                const SizedBox(height: 6),
                Text('${badge.current}/${badge.target}'),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatsTab extends StatelessWidget {
  const _StatsTab({required this.state, required this.profile});

  final AppState state;
  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    Widget tile(String label, String value, IconData icon) {
      return Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(label),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: <Widget>[
        tile(
          'Adherence',
          '${state.adherenceRate.toStringAsFixed(1)}%',
          Icons.favorite_outline,
        ),
        tile('Taken', '${profile.totalTaken}', Icons.check_circle_outline),
        tile('Snoozed', '${profile.totalSnoozed}', Icons.schedule_outlined),
        tile('Dismissed', '${profile.totalDismissed}', Icons.close_outlined),
        tile(
          'No response',
          '${profile.totalNoResponse}',
          Icons.warning_amber_outlined,
        ),
        tile(
          'Best streak',
          '${profile.bestStreakDays} days',
          Icons.local_fire_department_outlined,
        ),
      ],
    );
  }
}

class _TitlesTab extends StatelessWidget {
  const _TitlesTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final catalog = state.profileTitleCatalog;
    final unlocked = state.unlockedProfileTitleIds;
    final equipped = state.profile?.title.trim().toLowerCase() ?? '';

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Title Collection',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Unlocked ${unlocked.length} / ${catalog.length}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...catalog.map((title) {
          final isUnlocked = unlocked.contains(title.id);
          final isEquipped = equipped == title.label.toLowerCase();

          return Card(
            child: ListTile(
              leading: Icon(
                _titleIcon(title.id),
                color: isUnlocked
                    ? BrandPalette.primaryBlue
                    : Theme.of(context).disabledColor,
              ),
              title: Text(title.label),
              subtitle: Text(
                '${title.description}${title.isSecret ? ' - Secret' : ''}',
              ),
              trailing: isUnlocked
                  ? FilledButton(
                      onPressed: isEquipped
                          ? null
                          : () => state.equipProfileTitle(title.id),
                      child: Text(isEquipped ? 'Equipped' : 'Equip'),
                    )
                  : const Icon(Icons.lock_outline),
            ),
          );
        }),
      ],
    );
  }
}

class _FramesTab extends StatelessWidget {
  const _FramesTab({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final frames = state.avatarFrameCatalog;
    final unlocked = state.unlockedAvatarFrameIds;
    final active = state.activeAvatarFrameId;

    return ListView(
      padding: const EdgeInsets.only(top: 4),
      children: <Widget>[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Avatar Frames',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('Unlocked ${unlocked.length} / ${frames.length}'),
                const SizedBox(height: 6),
                Text(
                  'Frames are unlocked by streaks and milestones. Custom avatar styles were removed as requested.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        ...frames.map((frame) {
          final isUnlocked = unlocked.contains(frame.id);
          final isActive = active == frame.id;
          return Card(
            child: ListTile(
              leading: _FramePreview(frameId: frame.id),
              title: Text(frame.label),
              subtitle: Text(
                '${frame.description}${frame.isSecret ? ' - Secret' : ''}',
              ),
              trailing: isUnlocked
                  ? FilledButton(
                      onPressed: isActive
                          ? null
                          : () => state.equipAvatarFrame(frame.id),
                      child: Text(isActive ? 'Equipped' : 'Equip'),
                    )
                  : const Icon(Icons.lock_outline),
            ),
          );
        }),
      ],
    );
  }
}

class _FramePreview extends StatelessWidget {
  const _FramePreview({required this.frameId});

  final String frameId;

  List<Color> _colors() {
    switch (frameId) {
      case 'fire':
        return const <Color>[BrandPalette.accentCyan, BrandPalette.accentTeal];
      case 'ice':
        return const <Color>[BrandPalette.accentTeal, BrandPalette.primaryBlue];
      case 'aura':
        return const <Color>[
          BrandPalette.primaryViolet,
          BrandPalette.primaryDeep,
        ];
      case 'guardian':
        return const <Color>[
          BrandPalette.primaryBlue,
          BrandPalette.primaryDeep,
        ];
      default:
        return const <Color>[
          BrandPalette.primaryBlue,
          BrandPalette.primaryViolet,
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _colors();
    final innerColor = BrandPalette.surfaceByMode(context);
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
      ),
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: innerColor,
        ),
      ),
    );
  }
}

class _ActivityTab extends StatelessWidget {
  const _ActivityTab({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    if (profile.activities.isEmpty) {
      return const Center(child: Text('No activity yet.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.only(top: 4),
      itemCount: profile.activities.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (BuildContext context, int index) {
        final item = profile.activities[index];
        final dt = DateTime.tryParse(item.timestampIso)?.toLocal();
        final when = dt == null
            ? item.timestampIso
            : '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

        return Card(
          child: ListTile(
            leading: Icon(_activityIcon(item.type)),
            title: Text('${_actionLabel(item.type)} - ${item.medName}'),
            subtitle: Text(when),
          ),
        );
      },
    );
  }
}

class _SimpleCard extends StatelessWidget {
  const _SimpleCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body),
          ],
        ),
      ),
    );
  }
}

String _actionLabel(String type) {
  switch (type) {
    case 'taken':
      return 'Taken';
    case 'snooze':
      return 'Snoozed';
    case 'dismiss':
      return 'Dismissed';
    case 'no_response':
      return 'No response';
    default:
      return type;
  }
}

IconData _activityIcon(String type) {
  switch (type) {
    case 'taken':
      return Icons.check_circle_outline;
    case 'snooze':
      return Icons.schedule_outlined;
    case 'dismiss':
      return Icons.close_outlined;
    case 'no_response':
      return Icons.warning_amber_outlined;
    default:
      return Icons.circle_outlined;
  }
}

IconData _titleIcon(String id) {
  switch (id) {
    case 'the_banger':
      return Icons.music_note_outlined;
    case 'aura_developer':
      return Icons.auto_awesome_outlined;
    case 'streak_samurai':
      return Icons.local_fire_department_outlined;
    case 'night_watch':
      return Icons.nightlight_outlined;
    case 'family_guardian':
      return Icons.shield_outlined;
    case 'dose_legend':
      return Icons.workspace_premium_outlined;
    case 'comeback_hero':
      return Icons.restart_alt_outlined;
    case 'schedule_architect':
      return Icons.grid_view_outlined;
    default:
      return Icons.person_outline;
  }
}
