import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../core/due_reminder_queue.dart';
import '../core/reminder_escalation_tracker.dart';
import '../models/alert_event_model.dart';
import '../models/barcode_medication_model.dart';
import '../models/care_patient_model.dart';
import '../models/due_reminder_occurrence.dart';
import '../models/email_status_model.dart';
import '../models/family_model.dart';
import '../models/local_reminder.dart';
import '../models/queued_sync_item.dart';
import '../models/reminder_model.dart';
import '../models/user_profile.dart';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/auth_storage.dart';
import '../services/in_app_due_engine.dart';
import '../services/local_db.dart';
import '../services/local_reminder_store.dart';
import '../services/notification_id_allocator.dart';
import '../services/notification_service.dart';
import '../services/reminder_notification_scheduler.dart';
import '../services/reminder_sync_service.dart';
import '../services/sync_queue_store.dart';
import '../services/timezone_service.dart';
import '../services/user_profile_store.dart';

class ProfileTitleCatalogEntry {
  const ProfileTitleCatalogEntry({
    required this.id,
    required this.label,
    required this.description,
    this.isSecret = true,
  });

  final String id;
  final String label;
  final String description;
  final bool isSecret;
}

class ProfileAvatarFrameCatalogEntry {
  const ProfileAvatarFrameCatalogEntry({
    required this.id,
    required this.label,
    required this.description,
    this.isSecret = true,
  });

  final String id;
  final String label;
  final String description;
  final bool isSecret;
}

class ProfileUnlockEvent {
  const ProfileUnlockEvent({
    required this.kind,
    required this.id,
    required this.label,
    required this.description,
    required this.isSecret,
  });

  final String kind; // title | frame
  final String id;
  final String label;
  final String description;
  final bool isSecret;
}

class AppState extends ChangeNotifier with WidgetsBindingObserver {
  AppState({
    ApiService? apiService,
    AuthStorage? authStorage,
    Connectivity? connectivity,
    Uuid? uuid,
    bool enableNotifications = true,
    LocalReminderStore? localReminderStore,
    SyncQueueStore? syncQueueStore,
    NotificationIdAllocator? notificationIdAllocator,
    NotificationService? notificationService,
    ReminderNotificationScheduler? notificationScheduler,
    TimezoneService? timezoneService,
    InAppDueEngine? inAppDueEngine,
    ReminderSyncService? reminderSyncService,
  })  : _apiService = apiService ?? ApiService(),
        _authStorage = authStorage ?? AuthStorage(),
        _connectivity = connectivity ?? Connectivity(),
        _uuid = uuid ?? const Uuid(),
        _enableNotifications = enableNotifications,
        _localReminderStore = localReminderStore,
        _syncQueueStore = syncQueueStore,
        _notificationIdAllocator = notificationIdAllocator,
        _notificationService = notificationService,
        _notificationScheduler = notificationScheduler,
        _timezoneService = timezoneService,
        _inAppDueEngine = inAppDueEngine,
        _reminderSyncService = reminderSyncService;

  final ApiService _apiService;
  final AuthStorage _authStorage;
  final Connectivity _connectivity;
  final Uuid _uuid;
  final bool _enableNotifications;

  // Local services (created during initialize if not injected).
  LocalReminderStore? _localReminderStore;
  SyncQueueStore? _syncQueueStore;
  NotificationIdAllocator? _notificationIdAllocator;
  NotificationService? _notificationService;
  ReminderNotificationScheduler? _notificationScheduler;
  TimezoneService? _timezoneService;
  InAppDueEngine? _inAppDueEngine;
  ReminderSyncService? _reminderSyncService;
  UserProfileStore? _profileStore;

  static const String _soundEnabledKey = 'settings_sound_enabled';
  static const String _vibrationEnabledKey = 'settings_vibration_enabled';
  static const String _soundIdKey = 'settings_sound_id';
  static const String _customSoundNameKey = 'settings_custom_sound_name';
  static const String _customSoundBase64Key = 'settings_custom_sound_base64';
  static const String _snoozeThresholdKey = 'settings_snooze_threshold';
  static const String _criticalDelayMinutesKey =
      'settings_critical_delay_minutes';
  static const String _darkModeEnabledKey = 'settings_dark_mode_enabled';
  static const String _developerAuraEnabledKey = 'settings_developer_aura_v1';

  static const String _cachedUserKey = 'cached_user_v1';
  static const String _cachedFamilyKey = 'cached_family_v1';
  static const String _cachedFamilyMembersKey = 'cached_family_members_v1';

  static const String _defaultTitleId = 'med_rookie';
  static const String _defaultAvatarFrameId = 'classic';
  static const List<ProfileTitleCatalogEntry> _titleCatalog =
      <ProfileTitleCatalogEntry>[
    ProfileTitleCatalogEntry(
      id: _defaultTitleId,
      label: 'Med Rookie',
      description: 'Starter title for every profile.',
      isSecret: false,
    ),
    ProfileTitleCatalogEntry(
      id: 'the_banger',
      label: 'The Banger',
      description: 'Create 5 reminders on the same exact time.',
    ),
    ProfileTitleCatalogEntry(
      id: 'aura_developer',
      label: 'aura devolper',
      description: 'Discover backend configuration secret.',
    ),
    ProfileTitleCatalogEntry(
      id: 'streak_samurai',
      label: 'Streak Samurai',
      description: 'Reach a 7-day taken streak.',
    ),
    ProfileTitleCatalogEntry(
      id: 'night_watch',
      label: 'Night Watch',
      description: 'Have at least 3 night reminders (22:00-05:59).',
    ),
    ProfileTitleCatalogEntry(
      id: 'family_guardian',
      label: 'Family Guardian',
      description: 'Add 3 family members.',
    ),
    ProfileTitleCatalogEntry(
      id: 'dose_legend',
      label: 'Dose Legend',
      description: 'Mark 50 reminders as taken.',
    ),
    ProfileTitleCatalogEntry(
      id: 'comeback_hero',
      label: 'Comeback Hero',
      description: 'Recover after no-response: 10 taken + 1 no-response.',
    ),
    ProfileTitleCatalogEntry(
      id: 'schedule_architect',
      label: 'Schedule Architect',
      description: 'Keep 10 active reminders.',
    ),
  ];
  static const List<ProfileAvatarFrameCatalogEntry> _avatarFrameCatalog =
      <ProfileAvatarFrameCatalogEntry>[
    ProfileAvatarFrameCatalogEntry(
      id: _defaultAvatarFrameId,
      label: 'Classic Frame',
      description: 'Starter frame for all users.',
      isSecret: false,
    ),
    ProfileAvatarFrameCatalogEntry(
      id: 'fire',
      label: 'Fire Frame',
      description: 'Reach a 5-day streak.',
    ),
    ProfileAvatarFrameCatalogEntry(
      id: 'ice',
      label: 'Ice Frame',
      description: 'Mark 25 reminders as taken.',
    ),
    ProfileAvatarFrameCatalogEntry(
      id: 'aura',
      label: 'Aura Frame',
      description: 'Unlock the backend configuration secret.',
    ),
    ProfileAvatarFrameCatalogEntry(
      id: 'guardian',
      label: 'Guardian Frame',
      description: 'Add 3 family members.',
    ),
  ];

  bool _isInitializing = true;
  bool _isBusy = false;

  String? _token;
  String? _errorMessage;

  bool _isOffline = false;
  String? _offlineMessage;

  String? _configErrorMessage;

  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _soundId = 'beep';
  String? _customSoundName;
  String? _customSoundBase64;
  int _snoozeThreshold = 3;
  int _criticalDelayMinutes = 30;
  bool _darkModeEnabled = false;
  bool _developerAuraEnabled = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  UserModel? _user;
  FamilyModel? _family;
  EmailStatusModel? _emailStatus;
  UserProfile? _profile;

  List<ReminderModel> _reminders = <ReminderModel>[];
  List<String> _familyMembers = <String>[];
  Map<String, dynamic>? _familyInvite;
  List<CarePatientSummary> _carePatients = <CarePatientSummary>[];
  CarePatientDashboard? _careDashboard;
  List<CareEventItem> _careHistory = <CareEventItem>[];
  String? _selectedCarePatientEmail;
  final List<ProfileUnlockEvent> _pendingUnlockQueue = <ProfileUnlockEvent>[];

  final DueReminderQueue _dueQueue = DueReminderQueue();
  final ReminderEscalationTracker _escalationTracker =
      ReminderEscalationTracker();

  StreamSubscription<List<DueReminderOccurrence>>? _inAppDueSub;
  StreamSubscription<NotificationTapEvent>? _notificationTapSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _syncTimer;

  bool get isInitializing => _isInitializing;
  bool get isBusy => _isBusy;

  bool get hasToken => _token != null && _token!.isNotEmpty;

  /// "Authenticated" for offline-first UX:
  /// If a token exists we let the user in and sync later.
  bool get isAuthenticated => hasToken;

  bool get soundEnabled => _soundEnabled;
  bool get vibrationEnabled => _vibrationEnabled;
  String get soundId => _soundId;
  String? get customSoundName => _customSoundName;
  int get snoozeThreshold => _snoozeThreshold;
  int get criticalDelayMinutes => _criticalDelayMinutes;
  bool get darkModeEnabled => _darkModeEnabled;
  bool get developerAuraEnabled => _developerAuraEnabled;

  String? get token => _token;
  String? get errorMessage => _errorMessage;

  bool get isOffline => _isOffline;
  String? get offlineMessage => _offlineMessage;

  String? get configErrorMessage => _configErrorMessage;

  UserModel? get user => _user;
  String get userRole => _user?.role ?? 'patient';
  bool get isPatientRole => userRole == 'patient';
  bool get isFamilyRole => userRole == 'family';
  FamilyModel? get family => _family;
  EmailStatusModel? get emailStatus => _emailStatus;
  UserProfile? get profile => _profile;
  Map<String, dynamic>? get familyInvite => _familyInvite;
  String? get selectedCarePatientEmail => _selectedCarePatientEmail;
  List<CarePatientSummary> get carePatients =>
      List<CarePatientSummary>.unmodifiable(_carePatients);
  CarePatientDashboard? get careDashboard => _careDashboard;
  List<CareEventItem> get careHistory =>
      List<CareEventItem>.unmodifiable(_careHistory);

  int get profileLevel {
    final taken = _profile?.totalTaken ?? 0;
    return (taken ~/ 10) + 1;
  }

  double get adherenceRate {
    final p = _profile;
    if (p == null) {
      return 0;
    }
    final total = p.totalActions;
    if (total == 0) {
      return 0;
    }
    return (p.totalTaken / total) * 100;
  }

  int get profileXp {
    final p = _profile;
    if (p == null) {
      return 0;
    }
    return (p.totalTaken * 10) + (p.bestStreakDays * 2) + p.totalSnoozed;
  }

  String get profileLeague {
    final level = profileLevel;
    if (level >= 25) {
      return 'Diamond';
    }
    if (level >= 18) {
      return 'Obsidian';
    }
    if (level >= 12) {
      return 'Gold';
    }
    if (level >= 7) {
      return 'Silver';
    }
    return 'Bronze';
  }

  int get weeklyTakenCount {
    final p = _profile;
    if (p == null) {
      return 0;
    }

    final now = DateTime.now();
    final from = now.subtract(const Duration(days: 7));
    return p.activities.where((a) {
      if (a.type != 'taken') {
        return false;
      }
      final dt = DateTime.tryParse(a.timestampIso);
      return dt != null && dt.isAfter(from);
    }).length;
  }

  int get todayTakenCount {
    final p = _profile;
    if (p == null) {
      return 0;
    }

    final now = DateTime.now();
    return p.activities.where((a) {
      if (a.type != 'taken') {
        return false;
      }
      final dt = DateTime.tryParse(a.timestampIso);
      return dt != null &&
          dt.year == now.year &&
          dt.month == now.month &&
          dt.day == now.day;
    }).length;
  }

  List<ProfileTitleCatalogEntry> get profileTitleCatalog =>
      List<ProfileTitleCatalogEntry>.unmodifiable(_titleCatalog);
  List<ProfileAvatarFrameCatalogEntry> get avatarFrameCatalog =>
      List<ProfileAvatarFrameCatalogEntry>.unmodifiable(_avatarFrameCatalog);

  Set<String> get unlockedProfileTitleIds {
    final p = _profile;
    if (p == null) {
      return <String>{_defaultTitleId};
    }
    final ids = p.unlockedTitleIds.toSet();
    ids.add(_defaultTitleId);
    return ids;
  }

  Set<String> get unlockedAvatarFrameIds {
    final p = _profile;
    if (p == null) {
      return <String>{_defaultAvatarFrameId};
    }
    final ids = p.unlockedFrameIds.toSet();
    ids.add(_defaultAvatarFrameId);
    return ids;
  }

  String get activeAvatarFrameId {
    final p = _profile;
    if (p == null || p.activeFrameId.trim().isEmpty) {
      return _defaultAvatarFrameId;
    }
    return p.activeFrameId;
  }

  bool isProfileTitleUnlocked(String id) {
    return unlockedProfileTitleIds.contains(id);
  }

  bool isAvatarFrameUnlocked(String id) {
    return unlockedAvatarFrameIds.contains(id);
  }

  ProfileTitleCatalogEntry? profileTitleById(String id) {
    for (final item in _titleCatalog) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  ProfileAvatarFrameCatalogEntry? avatarFrameById(String id) {
    for (final item in _avatarFrameCatalog) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  ProfileUnlockEvent? consumePendingProfileUnlock() {
    if (_pendingUnlockQueue.isEmpty) {
      return null;
    }
    return _pendingUnlockQueue.removeAt(0);
  }

  List<ReminderModel> get reminders =>
      List<ReminderModel>.unmodifiable(_reminders);
  List<String> get familyMembers => List<String>.unmodifiable(_familyMembers);

  DueReminderOccurrence? get activeDueReminder => _dueQueue.active;
  List<DueReminderOccurrence> get pendingDueReminders => _dueQueue.pending;

  int snoozeCountFor(String reminderLocalId) =>
      _escalationTracker.snoozeCountFor(reminderLocalId);

  Future<void> initialize() async {
    _isInitializing = true;
    notifyListeners();

    WidgetsBinding.instance.addObserver(this);

    _configErrorMessage = ApiConfig.releaseConfigurationError();

    await _loadPreferences();

    // Allow a user-set backend URL override (useful for phone <-> PC LAN testing).
    // Still respects release HTTPS enforcement (ApiService filters candidates).
    try {
      final override = await ApiConfig.loadSavedOverride();
      if (override != null) {
        ApiConfig.rememberWorkingBaseUrl(override);
      }
    } catch (_) {
      // Ignore override loading errors.
    }

    await _ensureLocalServices();

    _token = await _authStorage.readToken();

    await _loadCachedSession();
    await _loadProfile();
    await _reloadLocalReminders();
    await _ensureNotificationIdsAssigned();
    await _rebuildLocalNotifications();
    _startInAppDueEngine();

    if (_enableNotifications) {
      await _wireNotificationTaps();
    }

    _startConnectivityAndSync();

    if (hasToken && _configErrorMessage == null) {
      unawaited(trySync(forceRefreshFromServer: true));
    }

    _isInitializing = false;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleResume());
    }
  }

  Future<void> _handleResume() async {
    if (_timezoneService != null) {
      final changed =
          await _timezoneService!.ensureInitializedAndCheckChanged();
      if (changed) {
        await _rebuildLocalNotifications();
        _inAppDueEngine?.rebuild();
      }
    }

    unawaited(trySync());
  }

  Future<void> restoreSession() async {
    if (!hasToken) {
      return;
    }
    await trySync(forceRefreshFromServer: true);
  }

  Future<void> login(String email, String password) async {
    if (_configErrorMessage != null) {
      throw ApiException(_configErrorMessage!);
    }

    await _runBusy(() async {
      _clearError();
      final auth = await _apiService.login(email, password);
      _token = auth.token;
      _user = auth.user;
      await _authStorage.saveToken(_token!);
      await _cacheSession();
      await _loadProfile();
      await trySync(forceRefreshFromServer: true);
    });
  }

  Future<void> signup(
    String email,
    String password,
    String age, {
    String role = 'patient',
  }) async {
    if (_configErrorMessage != null) {
      throw ApiException(_configErrorMessage!);
    }

    await _runBusy(() async {
      _clearError();
      final auth = await _apiService.signup(
        email,
        password,
        age,
        role: role,
      );
      _token = auth.token;
      _user = auth.user;
      await _authStorage.saveToken(_token!);
      await _cacheSession();
      await _loadProfile();
      await trySync(forceRefreshFromServer: true);
    });
  }

  Future<void> logout({bool clearLocalData = true}) async {
    _token = null;
    _user = null;
    _family = null;
    _emailStatus = null;
    _profile = null;
    _familyMembers = <String>[];
    _familyInvite = null;
    _carePatients = <CarePatientSummary>[];
    _careDashboard = null;
    _careHistory = <CareEventItem>[];
    _selectedCarePatientEmail = null;
    _errorMessage = null;
    _setOffline(false, message: null);
    _dueQueue.clear();
    _escalationTracker.clear();

    await _authStorage.clearToken();

    if (clearLocalData) {
      await _localReminderStore?.clearAll();
      await _syncQueueStore?.clear();
    }

    await _rebuildLocalNotifications();
    await _reloadLocalReminders();
    _inAppDueEngine?.rebuild();

    notifyListeners();
  }

  Future<void> refreshAll() async {
    await trySync(forceRefreshFromServer: true);
  }

  Future<void> refreshEmailStatus() async {
    if (!hasToken) {
      return;
    }
    await _runBusy(() async {
      _clearError();
      _emailStatus = await _apiService.emailStatus(_token!);
      notifyListeners();
    });
  }

  Future<void> createFamily(String familyName) async {
    if (!hasToken) {
      return;
    }
    if (!isPatientRole) {
      throw ApiException('Only patient users can create a family.');
    }

    await _runBusy(() async {
      _clearError();
      _family = await _apiService.createFamily(_token!, familyName);
      await _refreshListsOnlyFromServer();
    });
  }

  Future<void> joinFamily(String familyId) async {
    if (!hasToken) {
      return;
    }

    await _runBusy(() async {
      _clearError();
      _family = await _apiService.joinFamily(_token!, familyId);
      await _refreshListsOnlyFromServer();
    });
  }

  Future<void> addFamilyMember(String email) async {
    if (!hasToken) {
      return;
    }
    if (!isPatientRole) {
      throw ApiException('Only patient users can add family members.');
    }

    await _runBusy(() async {
      _clearError();
      _family = await _apiService.addFamilyMember(_token!, email);
      await _refreshListsOnlyFromServer();
    });
  }

  Future<void> removeFamilyMember(String email) async {
    if (!hasToken) {
      return;
    }
    if (!isPatientRole) {
      throw ApiException('Only patient users can remove family members.');
    }

    await _runBusy(() async {
      _clearError();
      await _apiService.removeFamilyMember(_token!, email);
      await _refreshListsOnlyFromServer();
    });
  }

  Future<void> updateFamilyMemberPermissions({
    required String memberEmail,
    required Map<String, bool> permissions,
  }) async {
    if (!hasToken) {
      return;
    }
    if (!isPatientRole) {
      throw ApiException('Only patient users can update permissions.');
    }

    await _runBusy(() async {
      _clearError();
      _family = await _apiService.updateFamilyMemberPermissions(
        _token!,
        memberEmail: memberEmail,
        permissions: permissions,
      );
      await _refreshListsOnlyFromServer();
    });
  }

  Future<void> joinFamilyByInviteCode(String inviteCode) async {
    final raw = inviteCode.trim();
    if (raw.isEmpty) {
      throw ApiException('Invite code is required.');
    }
    var code = raw.toUpperCase();
    if (code.startsWith('MEDFAM-')) {
      code = code.substring('MEDFAM-'.length);
    }
    if (code.contains('|')) {
      code = code.split('|').first.trim();
    }
    if (code.isEmpty) {
      throw ApiException('Invalid invite code.');
    }
    await joinFamily(code);
  }

  Future<void> refreshFamilyInviteCode() async {
    if (!hasToken || !isPatientRole || _family == null) {
      _familyInvite = null;
      notifyListeners();
      return;
    }

    try {
      _familyInvite = await _apiService.getFamilyInviteCode(_token!);
    } catch (_) {
      _familyInvite = null;
    }
    notifyListeners();
  }

  Future<void> updateFamilyTitle(String title) async {
    if (!hasToken) {
      return;
    }
    if (!isPatientRole) {
      throw ApiException('Only patient users can update family title.');
    }
    final nextTitle = title.trim();
    if (nextTitle.isEmpty) {
      throw ApiException('Family title is required.');
    }

    await _runBusy(() async {
      _clearError();
      _family = await _apiService.updateFamilyTitle(_token!, title: nextTitle);
      await _refreshListsOnlyFromServer();
    });
  }

  Future<void> leaveFamily() async {
    if (!hasToken) {
      return;
    }

    await _runBusy(() async {
      _clearError();
      await _apiService.leaveFamily(_token!);
      _family = null;
      _familyMembers = <String>[];
      await _cacheSession();
      notifyListeners();
    });
  }

  Future<void> createReminder({
    required String medName,
    required String dose,
    required String time,
    required List<String> times,
    required String notificationType,
    required List<String> selectedFamilyMembers,
    required String singleFamilyMember,
    required bool emailNotifications,
    required bool calendarSync,
  }) async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }
    if (!isPatientRole) {
      throw ApiException('Family users cannot create reminders.');
    }

    await _ensureLocalServices();

    final store = _localReminderStore!;
    final queue = _syncQueueStore!;
    final allocator = _notificationIdAllocator!;

    final normalizedTimes = _sanitizeTimes(times, fallback: time);

    final localId = _uuid.v4();
    final repeatingIds = <int>[];
    for (var i = 0; i < normalizedTimes.length; i += 1) {
      repeatingIds.add(await allocator.allocate());
    }

    final ownerEmail = _user?.email ?? _cachedUserEmailFallback();

    final local = LocalReminder(
      localId: localId,
      serverId: null,
      userEmail: ownerEmail,
      medName: medName.trim(),
      dose: dose.trim(),
      time: normalizedTimes.first,
      times: normalizedTimes,
      notificationType: notificationType.trim(),
      selectedFamilyMembers: List<String>.from(selectedFamilyMembers),
      singleFamilyMember: singleFamilyMember.trim(),
      emailNotifications: emailNotifications,
      calendarSync: calendarSync,
      createdAt: DateTime.now().toIso8601String(),
      repeatingNotificationId: repeatingIds.first,
      repeatingNotificationIds: repeatingIds,
      pendingCreate: true,
    );

    await store.upsert(local);
    await queue.enqueue(
      QueuedSyncItem(
        id: _uuid.v4(),
        type: 'reminder_create',
        enqueuedAt: DateTime.now(),
        payload: <String, dynamic>{'local_id': localId},
      ),
    );

    await _reloadLocalReminders();
    await _rebuildLocalNotifications();
    _inAppDueEngine?.rebuild();
    await _evaluateReminderSecrets();

    // Best effort sync; do not fail local UX.
    unawaited(trySync());
  }

  Future<void> deleteReminder(String localReminderId) async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }
    if (!isPatientRole) {
      throw ApiException('Family users cannot delete reminders.');
    }

    await _ensureLocalServices();

    final store = _localReminderStore!;
    final queue = _syncQueueStore!;

    final local = store.getSync(localReminderId);
    if (local == null) {
      return;
    }

    // If it never synced, drop it locally and remove any pending create.
    if ((local.serverId == null || local.serverId!.isEmpty) &&
        local.pendingCreate) {
      await _dropQueuedItems(
        predicate: (item) =>
            item.type == 'reminder_create' &&
            (item.payload['local_id'] ?? '').toString() == localReminderId,
      );
      await store.deleteHard(localReminderId);
      await _reloadLocalReminders();
      await _rebuildLocalNotifications();
      _inAppDueEngine?.rebuild();
      await _evaluateReminderSecrets();
      return;
    }

    // Mark deleted locally first (offline-first).
    await store.upsert(
      local.copyWith(isDeleted: true, pendingDelete: true, pendingCreate: false),
    );

    await queue.enqueue(
      QueuedSyncItem(
        id: _uuid.v4(),
        type: 'reminder_delete',
        enqueuedAt: DateTime.now(),
        payload: <String, dynamic>{'local_id': localReminderId},
      ),
    );

    await _reloadLocalReminders();
    await _rebuildLocalNotifications();
    _inAppDueEngine?.rebuild();
    await _evaluateReminderSecrets();

    unawaited(trySync());
  }

  Future<void> updateReminder({
    required String localReminderId,
    required String medName,
    required String dose,
    required String time,
    List<String>? times,
    String? notificationType,
    List<String>? selectedFamilyMembers,
    String? singleFamilyMember,
    bool? emailNotifications,
    bool? calendarSync,
  }) async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }
    if (!isPatientRole) {
      throw ApiException('Family users cannot edit reminders.');
    }

    await _ensureLocalServices();

    final store = _localReminderStore!;
    final queue = _syncQueueStore!;
    final allocator = _notificationIdAllocator!;

    final existing = store.getSync(localReminderId);
    if (existing == null) {
      throw ApiException('Reminder not found');
    }

    final nextTimes = _sanitizeTimes(
      times ?? <String>[time],
      fallback: existing.time,
    );
    final nextNotificationIds = existing.repeatingNotificationIds.isNotEmpty
        ? List<int>.from(existing.repeatingNotificationIds)
        : <int>[
            if (existing.repeatingNotificationId > 0)
              existing.repeatingNotificationId,
          ];
    while (nextNotificationIds.length < nextTimes.length) {
      nextNotificationIds.add(await allocator.allocate());
    }

    final updated = existing.copyWith(
      medName: medName.trim(),
      dose: dose.trim(),
      time: nextTimes.first,
      times: nextTimes,
      notificationType: (notificationType ?? existing.notificationType).trim(),
      selectedFamilyMembers:
          selectedFamilyMembers == null
              ? existing.selectedFamilyMembers
              : List<String>.from(selectedFamilyMembers),
      singleFamilyMember: (singleFamilyMember ?? existing.singleFamilyMember).trim(),
      emailNotifications: emailNotifications ?? existing.emailNotifications,
      calendarSync: calendarSync ?? existing.calendarSync,
      repeatingNotificationId: nextNotificationIds.first,
      repeatingNotificationIds: nextNotificationIds,
    );

    await store.upsert(updated);

    // If the reminder hasn't been created on the server yet, don't enqueue an update:
    // the create-sync will send the latest fields.
    final hasServerId =
        updated.serverId != null && updated.serverId!.trim().isNotEmpty;
    if (!updated.pendingCreate || hasServerId) {
      await queue.enqueue(
        QueuedSyncItem(
          id: _uuid.v4(),
          type: 'reminder_update',
          enqueuedAt: DateTime.now(),
          payload: <String, dynamic>{'local_id': localReminderId},
        ),
      );
    }

    await _reloadLocalReminders();
    await _rebuildLocalNotifications();
    _inAppDueEngine?.rebuild();
    await _evaluateReminderSecrets();

    unawaited(trySync());
  }

  Future<void> enqueueDueOccurrences(
    List<DueReminderOccurrence> occurrences,
  ) async {
    _dueQueue.enqueueAll(occurrences);
    _pumpDueQueue();
    notifyListeners();
  }

  void _pumpDueQueue() {
    _dueQueue.takeNextIfIdle();
  }

  Future<void> completeActiveDue() async {
    _dueQueue.completeActive();
    _pumpDueQueue();
    notifyListeners();
  }

  Future<void> markTaken(DueReminderOccurrence occurrence) async {
    _escalationTracker.resetReminder(occurrence.reminderLocalId);
    await completeActiveDue();
    await _recordAction(
      localReminderId: occurrence.reminderLocalId,
      reminderServerId: occurrence.reminderServerId,
      action: 'taken',
      metadata: <String, dynamic>{},
    );
    await _recordProfileAction(occurrence: occurrence, action: 'taken');
  }

  Future<void> dismiss(DueReminderOccurrence occurrence) async {
    _escalationTracker.resetReminder(occurrence.reminderLocalId);
    await completeActiveDue();

    await _recordAction(
      localReminderId: occurrence.reminderLocalId,
      reminderServerId: occurrence.reminderServerId,
      action: 'dismiss',
      metadata: <String, dynamic>{},
    );
    await _recordProfileAction(occurrence: occurrence, action: 'dismiss');

    if (isPatientRole) {
      await _queueEscalation(
        localReminderId: occurrence.reminderLocalId,
        reminderServerId: occurrence.reminderServerId,
        reason: 'dismissed',
      );
    }
  }

  Future<void> snooze5m(DueReminderOccurrence occurrence) async {
    await completeActiveDue();

    await _ensureLocalServices();

    final store = _localReminderStore!;
    final allocator = _notificationIdAllocator!;

    final local = store.getSync(occurrence.reminderLocalId);
    if (local != null) {
      final snoozeId = await allocator.allocate();
      final snoozedUntil = DateTime.now().add(const Duration(minutes: 5));
      await store.upsert(
        local.copyWith(
          snoozedUntil: snoozedUntil,
          snoozeNotificationId: snoozeId,
        ),
      );
      await _rebuildLocalNotifications();
      _inAppDueEngine?.rebuild();
    }

    final count = _escalationTracker.recordSnooze(occurrence.reminderLocalId);

    await _recordAction(
      localReminderId: occurrence.reminderLocalId,
      reminderServerId: occurrence.reminderServerId,
      action: 'snooze',
      metadata: <String, dynamic>{
        'minutes': 5,
        'snooze_count': count,
      },
    );
    await _recordProfileAction(occurrence: occurrence, action: 'snooze');

    if (_escalationTracker.shouldEscalateSnooze(
      reminderId: occurrence.reminderLocalId,
      threshold: _snoozeThreshold,
    ) &&
        isPatientRole) {
      await _queueEscalation(
        localReminderId: occurrence.reminderLocalId,
        reminderServerId: occurrence.reminderServerId,
        reason: 'snooze_threshold',
        snoozeCount: count,
      );
    }

  }

  Future<void> noResponse(DueReminderOccurrence occurrence) async {
    await completeActiveDue();

    await _recordAction(
      localReminderId: occurrence.reminderLocalId,
      reminderServerId: occurrence.reminderServerId,
      action: 'no_response',
      metadata: <String, dynamic>{'delay_minutes': _criticalDelayMinutes},
    );
    await _recordProfileAction(occurrence: occurrence, action: 'no_response');

    if (_escalationTracker.shouldEscalateNoResponse(occurrence.reminderLocalId) &&
        isPatientRole) {
      await _queueEscalation(
        localReminderId: occurrence.reminderLocalId,
        reminderServerId: occurrence.reminderServerId,
        reason: 'no_response',
        delayMinutes: _criticalDelayMinutes,
      );
    }

  }

  Future<void> _recordAction({
    required String localReminderId,
    String? reminderServerId,
    required String action,
    required Map<String, dynamic> metadata,
  }) async {
    await _ensureLocalServices();
    final queue = _syncQueueStore!;

    await queue.enqueue(
      QueuedSyncItem(
        id: _uuid.v4(),
        type: 'reminder_action',
        enqueuedAt: DateTime.now(),
        payload: <String, dynamic>{
          'local_id': localReminderId,
          if (reminderServerId != null && reminderServerId.trim().isNotEmpty)
            'server_id': reminderServerId.trim(),
          'action': action,
          'occurred_at': DateTime.now().toIso8601String(),
          'metadata': metadata,
        },
      ),
    );

    unawaited(trySync());
  }

  Future<void> _queueEscalation({
    required String localReminderId,
    String? reminderServerId,
    required String reason,
    int snoozeCount = 0,
    int delayMinutes = 30,
  }) async {
    await _ensureLocalServices();
    final queue = _syncQueueStore!;

    await queue.enqueue(
      QueuedSyncItem(
        id: _uuid.v4(),
        type: 'reminder_escalate',
        enqueuedAt: DateTime.now(),
        payload: <String, dynamic>{
          'local_id': localReminderId,
          if (reminderServerId != null && reminderServerId.trim().isNotEmpty)
            'server_id': reminderServerId.trim(),
          'reason': reason,
          'snooze_count': snoozeCount,
          'delay_minutes': delayMinutes,
        },
      ),
    );

    unawaited(trySync());
  }

  Future<BarcodeMedicationModel> lookupBarcode(String barcode) async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }

    try {
      return await _apiService.barcodeLookup(_token!, barcode);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        throw ApiException(_errorMessage!, statusCode: error.statusCode);
      }
      rethrow;
    }
  }

  Future<String> testGmailConnection() async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }

    try {
      return await _apiService.testGmail(_token!);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        throw ApiException(_errorMessage!, statusCode: error.statusCode);
      }
      rethrow;
    }
  }

  Future<String> sendTestEmail({
    required List<String> recipients,
    required String templateType,
  }) async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }

    try {
      return await _apiService.testEmail(
        _token!,
        recipients: recipients,
        templateType: templateType,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        throw ApiException(_errorMessage!, statusCode: error.statusCode);
      }
      rethrow;
    }
  }

  Future<List<AlertEventModel>> fetchUnreadAlerts() async {
    if (!hasToken || _configErrorMessage != null) {
      return <AlertEventModel>[];
    }
    try {
      return await _apiService.getAlerts(_token!);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        return <AlertEventModel>[];
      }
      rethrow;
    }
  }

  Future<void> markAlertRead(String alertId) async {
    if (!hasToken || _configErrorMessage != null) {
      return;
    }
    try {
      await _apiService.markAlertRead(_token!, alertId);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        return;
      }
      rethrow;
    }
  }

  Future<void> pollDueRemindersNow() async {
    if (!hasToken || _configErrorMessage != null) {
      return;
    }

    try {
      final result = await _apiService.checkNow(_token!);
      if (result.reminders.isEmpty) {
        return;
      }

      await _ensureLocalServices();
      final locals = _localReminderStore?.listSync(includeDeleted: false) ??
          <LocalReminder>[];
      final localByServerId = <String, String>{};
      for (final reminder in locals) {
        final serverId = reminder.serverId;
        if (serverId == null || serverId.trim().isEmpty) {
          continue;
        }
        localByServerId[serverId] = reminder.localId;
      }

      final now = DateTime.now();
      final dueOccurrences = <DueReminderOccurrence>[];

      for (final reminder in result.reminders) {
        final dueAt = _dueAtForTime(reminder.time, now) ?? now;
        final localId = localByServerId[reminder.id] ?? reminder.id;
        dueOccurrences.add(
          DueReminderOccurrence(
            occurrenceId: '$localId|${dueAt.toIso8601String()}',
            reminderLocalId: localId,
            reminderServerId: reminder.id,
            medName: reminder.medName,
            dose: reminder.dose,
            timeLabel: reminder.time,
            forUser: reminder.forUser.isEmpty
                ? _cachedUserEmailFallback()
                : reminder.forUser,
            dueAt: dueAt,
            source: 'api_check_now',
          ),
        );
      }

      if (dueOccurrences.isNotEmpty) {
        await enqueueDueOccurrences(dueOccurrences);
      }
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
      }
    } catch (_) {}
  }

  Future<void> refreshCareData() async {
    if (!hasToken) {
      return;
    }
    if (!isFamilyRole) {
      _carePatients = <CarePatientSummary>[];
      _careDashboard = null;
      _careHistory = <CareEventItem>[];
      _selectedCarePatientEmail = null;
      notifyListeners();
      return;
    }

    final patients = await _apiService.listCarePatients(_token!);
    _carePatients = patients;

    if (_carePatients.isEmpty) {
      _careDashboard = null;
      _careHistory = <CareEventItem>[];
      _selectedCarePatientEmail = null;
      notifyListeners();
      return;
    }

    final selected = _selectedCarePatientEmail;
    final exists = selected != null &&
        _carePatients.any((p) => p.patientEmail == selected);
    _selectedCarePatientEmail = exists
        ? selected
        : _carePatients.first.patientEmail;

    await _refreshSelectedCarePatientData();
  }

  Future<void> selectCarePatient(String patientEmail) async {
    if (!isFamilyRole) {
      return;
    }
    if (patientEmail.trim().isEmpty) {
      return;
    }
    _selectedCarePatientEmail = patientEmail.trim().toLowerCase();
    await _refreshSelectedCarePatientData();
  }

  Future<void> refreshCareHistory({int limit = 200}) async {
    if (!hasToken || !isFamilyRole || _selectedCarePatientEmail == null) {
      return;
    }
    _careHistory = await _apiService.getCarePatientHistory(
      _token!,
      patientEmail: _selectedCarePatientEmail!,
      limit: limit,
    );
    notifyListeners();
  }

  Future<void> _refreshSelectedCarePatientData() async {
    if (!hasToken || !isFamilyRole || _selectedCarePatientEmail == null) {
      return;
    }
    final patientEmail = _selectedCarePatientEmail!;
    _careDashboard = await _apiService.getCarePatientDashboard(
      _token!,
      patientEmail: patientEmail,
    );
    _careHistory = await _apiService.getCarePatientHistory(
      _token!,
      patientEmail: patientEmail,
      limit: 180,
    );
    notifyListeners();
  }

  Future<void> postCareLocation({
    required double lat,
    required double lng,
    String? timestamp,
  }) async {
    if (!hasToken) {
      throw ApiException('Not authenticated');
    }
    if (!isPatientRole) {
      throw ApiException('Only patient users can update location.');
    }
    await _apiService.postCareLocation(
      _token!,
      lat: lat,
      lng: lng,
      timestamp: timestamp,
    );
  }

  Future<void> setSoundEnabled(bool value) async {
    _soundEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_soundEnabledKey, value);
    await _rebuildLocalNotifications();
  }

  Future<void> setSoundId(String value) async {
    _soundId = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundIdKey, value);
  }

  Future<void> pickCustomSound() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['wav', 'mp3', 'm4a', 'aac', 'ogg'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw ApiException('Could not read selected sound file.');
    }

    // Keep it small to avoid blowing up SharedPreferences (esp. web/localStorage).
    const maxBytes = 512 * 1024;
    if (bytes.length > maxBytes) {
      throw ApiException('Sound file too large. Choose a file under 512KB.');
    }

    _customSoundName = file.name;
    _customSoundBase64 = base64Encode(bytes);
    _soundId = 'custom';
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_soundIdKey, _soundId);
    await prefs.setString(_customSoundNameKey, _customSoundName!);
    await prefs.setString(_customSoundBase64Key, _customSoundBase64!);
  }

  Future<void> clearCustomSound() async {
    _customSoundName = null;
    _customSoundBase64 = null;
    if (_soundId == 'custom') {
      _soundId = 'beep';
    }
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_customSoundNameKey);
    await prefs.remove(_customSoundBase64Key);
    await prefs.setString(_soundIdKey, _soundId);
  }

  Future<void> playAlertSound() async {
    if (!_soundEnabled) {
      return;
    }

    if (_soundId == 'system') {
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (error) {
        debugPrint('SystemSound.play failed: $error');
      }
      return;
    }

    try {
      await _audioPlayer.stop();
      await _audioPlayer.setVolume(1.0);

      if (_soundId == 'chime') {
        await _audioPlayer.play(AssetSource('sounds/chime.wav'));
      } else if (_soundId == 'custom' && _customSoundBase64 != null) {
        final bytes = base64Decode(_customSoundBase64!);
        await _audioPlayer.play(BytesSource(bytes));
      } else {
        await _audioPlayer.play(AssetSource('sounds/beep.wav'));
      }
    } catch (error) {
      debugPrint('playAlertSound failed: $error');
      // Fallback (e.g. browser blocks audio until user interacts).
      try {
        SystemSound.play(SystemSoundType.alert);
      } catch (fallbackError) {
        debugPrint('SystemSound.play fallback failed: $fallbackError');
      }
    }
  }

  Future<void> vibrateAlert() async {
    if (!_vibrationEnabled) {
      return;
    }
    try {
      HapticFeedback.mediumImpact();
      HapticFeedback.vibrate();
    } catch (error) {
      debugPrint('HapticFeedback failed: $error');
    }
  }

  Future<void> setVibrationEnabled(bool value) async {
    _vibrationEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_vibrationEnabledKey, value);
    await _rebuildLocalNotifications();
  }

  Future<void> setSnoozeThreshold(int value) async {
    _snoozeThreshold = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_snoozeThresholdKey, value);
  }

  Future<void> setCriticalDelayMinutes(int value) async {
    _criticalDelayMinutes = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_criticalDelayMinutesKey, value);
  }

  Future<void> setDarkModeEnabled(bool value) async {
    _darkModeEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeEnabledKey, value);
  }

  Future<void> setDeveloperAuraEnabled(bool value) async {
    _developerAuraEnabled = value;

    if (value) {
      await _unlockProfileTitle('aura_developer', autoEquipIfEmpty: true);
      await _unlockAvatarFrame('aura', autoEquipIfDefault: true);
    }

    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_developerAuraEnabledKey, value);
  }

  Future<void> trySync({bool forceRefreshFromServer = false}) async {
    if (!hasToken) {
      return;
    }
    if (_configErrorMessage != null) {
      // Online features disabled (release HTTPS enforcement).
      return;
    }

    await _ensureLocalServices();

    final token = _token!;
    final sync = _reminderSyncService!;

    try {
      await sync.processQueue(token);

      if (forceRefreshFromServer || !_isOffline) {
        await _loadSessionFromServer(token);
      }

      _setOffline(false, message: null);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        return;
      }

      // Treat network failures as offline, keep UX usable locally.
      _setOffline(true, message: error.message);
    } catch (error) {
      _setOffline(true, message: error.toString());
    }
  }

  Future<void> _loadSessionFromServer(String token) async {
    final me = await _apiService.me(token);
    _user = me.$1;
    _family = me.$2;
    await _loadProfile();

    await _refreshListsOnlyFromServer();

    try {
      _emailStatus = await _apiService.emailStatus(token);
    } catch (_) {
      // Keep app usable even if email status endpoint fails.
    }

    await _cacheSession();

    if (isPatientRole) {
      // Cache reminders locally for offline scheduling.
      await _reminderSyncService!.refreshFromServer(token);
      await _ensureNotificationIdsAssigned();
      await _reloadLocalReminders();
      await _rebuildLocalNotifications();
      _inAppDueEngine?.rebuild();
      await _evaluateReminderSecrets();
      await _evaluateFamilySecrets();
      await _evaluateActionSecrets();
    } else {
      // Family role should not keep local medication schedules.
      await _localReminderStore?.clearAll();
      _reminders = <ReminderModel>[];
      await _rebuildLocalNotifications();
      _inAppDueEngine?.rebuild();
      notifyListeners();
    }
  }

  Future<void> _refreshListsOnlyFromServer() async {
    if (!hasToken) {
      return;
    }

    _family = await _apiService.getFamily(_token!);
    _familyMembers = await _apiService.getFamilyMembers(_token!);

    if (isPatientRole) {
      await refreshFamilyInviteCode();
      _carePatients = <CarePatientSummary>[];
      _careDashboard = null;
      _careHistory = <CareEventItem>[];
      _selectedCarePatientEmail = null;
    } else {
      _familyInvite = null;
      try {
        await refreshCareData();
      } catch (_) {}
    }

    notifyListeners();
    await _cacheSession();
    await _evaluateFamilySecrets();
  }

  Future<void> _ensureLocalServices() async {
    if (_localReminderStore != null &&
        _syncQueueStore != null &&
        _notificationIdAllocator != null &&
        _timezoneService != null &&
        _reminderSyncService != null &&
        _notificationScheduler != null &&
        _inAppDueEngine != null &&
        _profileStore != null) {
      return;
    }

    // If stores were injected (tests), don't touch HiveFlutter.
    if (_localReminderStore == null || _syncQueueStore == null) {
      await LocalDb.ensureInitialized();
      _localReminderStore ??= LocalReminderStore(box: LocalDb.remindersBox);
      _syncQueueStore ??= SyncQueueStore(box: LocalDb.syncQueueBox);
      _notificationIdAllocator ??=
          NotificationIdAllocator(metaBox: LocalDb.metaBox);
      _timezoneService ??= TimezoneService(metaBox: LocalDb.metaBox);
    }

    _timezoneService ??= TimezoneService(metaBox: LocalDb.metaBox);
    await _timezoneService!.ensureInitializedAndCheckChanged();

    _notificationService ??= NotificationService();

    _notificationScheduler ??= ReminderNotificationScheduler(
      notificationService: _notificationService!,
      reminderStore: _localReminderStore!,
    );

    _reminderSyncService ??= ReminderSyncService(
      api: _apiService,
      reminderStore: _localReminderStore!,
      queueStore: _syncQueueStore!,
    );

    _inAppDueEngine ??= InAppDueEngine(
      store: _localReminderStore!,
      currentUserEmail: _cachedUserEmailFallback,
    );

    if (_profileStore == null) {
      try {
        await LocalDb.ensureInitialized();
        _profileStore = UserProfileStore(metaBox: LocalDb.metaBox);
      } catch (_) {
        // In tests with injected stores, profile persistence is optional.
      }
    }
  }

  Future<void> _wireNotificationTaps() async {
    if (!_enableNotifications) {
      return;
    }

    final service = _notificationService;
    if (service == null) {
      return;
    }

    try {
      await service.ensureInitialized();

      final launchPayload = await service.getLaunchPayload();
      if (launchPayload != null) {
        await _handleNotificationPayload(launchPayload);
      }

      await _notificationTapSub?.cancel();
      _notificationTapSub = service.taps.listen((event) {
        unawaited(_handleNotificationPayload(event.payload));
      });
    } catch (error) {
      // If notifications plugin isn't available (tests), keep app usable.
      debugPrint('Notification tap wiring failed: $error');
    }
  }

  Future<void> _handleNotificationPayload(String? payload) async {
    if (payload == null || payload.trim().isEmpty) {
      return;
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        json = decoded;
      }
    } catch (_) {}

    if (json == null) {
      return;
    }

    if ((json['type'] ?? '').toString() != 'reminder_due') {
      return;
    }

    await _ensureLocalServices();
    final store = _localReminderStore!;

    final localId = (json['local_id'] ?? '').toString();
    if (localId.isEmpty) {
      return;
    }

    final reminder = store.getSync(localId);
    if (reminder == null) {
      return;
    }

    DateTime dueAt = DateTime.now();
    final dueAtRaw = (json['due_at'] ?? '').toString();
    final timeRaw = (json['time'] ?? reminder.time).toString();
    final serverIdRaw = (json['server_id'] ?? reminder.serverId ?? '')
        .toString()
        .trim();
    if (dueAtRaw.isNotEmpty) {
      dueAt = DateTime.tryParse(dueAtRaw) ?? dueAt;
    } else {
      final parsed = timeRaw.split(':');
      final hour = int.tryParse(parsed.isNotEmpty ? parsed[0] : '');
      final minute =
          int.tryParse(parsed.length > 1 ? parsed[1] : '') ?? 0;
      final now = DateTime.now();
      if (hour != null) {
        dueAt = DateTime(now.year, now.month, now.day, hour, minute);
      }
    }

    await enqueueDueOccurrences(<DueReminderOccurrence>[
      DueReminderOccurrence(
        occurrenceId: '${reminder.localId}|${dueAt.toIso8601String()}',
        reminderLocalId: reminder.localId,
        reminderServerId: serverIdRaw.isEmpty ? null : serverIdRaw,
        medName: reminder.medName,
        dose: reminder.dose,
        timeLabel: timeRaw,
        forUser: _cachedUserEmailFallback(),
        dueAt: dueAt,
        source: 'notification_tap',
      ),
    ]);
  }

  void _startInAppDueEngine() {
    final engine = _inAppDueEngine;
    if (engine == null) {
      return;
    }

    engine.start();
    _inAppDueSub?.cancel();
    _inAppDueSub = engine.dueEvents.listen((events) {
      unawaited(enqueueDueOccurrences(events));
    });
  }

  void _startConnectivityAndSync() {
    _connectivitySub?.cancel();
    _syncTimer?.cancel();

    // Connectivity stream uses platform channels; keep it best-effort.
    _connectivitySub = _connectivity.onConnectivityChanged.listen((results) {
      final hasNetwork = results.isNotEmpty &&
          results.any((r) => r != ConnectivityResult.none);
      if (hasNetwork) {
        unawaited(trySync());
      }
    });

    _syncTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      unawaited(trySync());
    });
  }

  Future<void> _ensureNotificationIdsAssigned() async {
    await _ensureLocalServices();
    final store = _localReminderStore!;
    final allocator = _notificationIdAllocator!;

    final locals = store.listSync(includeDeleted: true);
    for (final reminder in locals) {
      final targetSlots =
          reminder.times.isNotEmpty ? reminder.times.length : 1;
      final ids = reminder.repeatingNotificationIds.isNotEmpty
          ? List<int>.from(reminder.repeatingNotificationIds)
          : <int>[
              if (reminder.repeatingNotificationId > 0)
                reminder.repeatingNotificationId,
            ];
      var changed = false;

      while (ids.length < targetSlots) {
        ids.add(await allocator.allocate());
        changed = true;
      }

      if (ids.isEmpty) {
        ids.add(await allocator.allocate());
        changed = true;
      }

      final primaryId = ids.first;
      if (reminder.repeatingNotificationId != primaryId ||
          reminder.repeatingNotificationIds.length != ids.length) {
        changed = true;
      }

      if (!changed) {
        continue;
      }

      await store.upsert(
        reminder.copyWith(
          repeatingNotificationId: primaryId,
          repeatingNotificationIds: ids,
        ),
      );
    }
  }

  Future<void> _rebuildLocalNotifications() async {
    if (!_enableNotifications) {
      return;
    }
    final scheduler = _notificationScheduler;
    if (scheduler == null) {
      return;
    }
    try {
      await scheduler.rebuildSchedules(
        soundEnabled: _soundEnabled,
        vibrationEnabled: _vibrationEnabled,
      );
    } catch (error) {
      debugPrint('Notification reschedule failed: $error');
    }
  }

  Future<void> _reloadLocalReminders() async {
    await _ensureLocalServices();
    final locals = _localReminderStore!.listSync(includeDeleted: false);
    _reminders = locals.map((e) => e.toReminderModel()).toList();
    notifyListeners();
    await _evaluateReminderSecrets();
  }

  Future<void> _dropQueuedItems({
    required bool Function(QueuedSyncItem item) predicate,
  }) async {
    final queue = _syncQueueStore;
    if (queue == null) {
      return;
    }

    final items = queue.listSync();
    for (final (key, item) in items) {
      if (predicate(item)) {
        await queue.remove(key);
      }
    }
  }

  Future<void> _cacheSession() async {
    if (!LocalDb.metaBox.isOpen) {
      return;
    }

    if (_user != null) {
      await LocalDb.metaBox.put(_cachedUserKey, <String, dynamic>{
        'email': _user!.email,
        'age': _user!.age,
        'family_id': _user!.familyId,
        'role': _user!.role,
        'last_seen_at': _user!.lastSeenAt,
        'safe_zone': _user!.safeZone,
      });
    }

    if (_family != null) {
      await LocalDb.metaBox.put(_cachedFamilyKey, <String, dynamic>{
        'family_id': _family!.familyId,
        'name': _family!.name,
        'title': _family!.title,
        'admin': _family!.admin,
        'member_count': _family!.memberCount,
        'is_admin': _family!.isAdmin,
        'members': _family!.members
            .map(
              (m) => <String, dynamic>{
                'email': m.email,
                'age': m.age,
                'role': m.role,
                'joined_at': m.joinedAt,
                'permissions': m.permissions,
              },
            )
            .toList(),
      });
    } else {
      await LocalDb.metaBox.delete(_cachedFamilyKey);
    }

    await LocalDb.metaBox.put(_cachedFamilyMembersKey, _familyMembers);
  }

  Future<void> _loadCachedSession() async {
    try {
      await LocalDb.ensureInitialized();
    } catch (_) {
      // In tests, LocalDb may not be available; ignore.
      return;
    }

    final cachedUser = LocalDb.metaBox.get(_cachedUserKey);
    if (cachedUser is Map) {
      _user = UserModel.fromJson(Map<String, dynamic>.from(cachedUser));
    }

    final cachedFamily = LocalDb.metaBox.get(_cachedFamilyKey);
    if (cachedFamily is Map) {
      _family = FamilyModel.fromJson(Map<String, dynamic>.from(cachedFamily));
    }

    final cachedMembers = LocalDb.metaBox.get(_cachedFamilyMembersKey);
    if (cachedMembers is List) {
      _familyMembers = cachedMembers
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
  }

  String _cachedUserEmailFallback() {
    final email = _user?.email;
    if (email != null && email.trim().isNotEmpty) {
      return email;
    }
    return 'You';
  }

  Future<void> _loadProfile() async {
    try {
      await _ensureLocalServices();
    } catch (_) {
      return;
    }

    final email = _user?.email ?? _cachedUserEmailFallback();
    if (email.trim().isEmpty || email == 'You') {
      return;
    }

    final existing = _profileStore?.getSync(email);
    if (existing != null) {
      final unlocked = existing.unlockedTitleIds.toSet();
      unlocked.add(_defaultTitleId);
      final unlockedFrames = existing.unlockedFrameIds.toSet();
      unlockedFrames.add(_defaultAvatarFrameId);

      var hasChanges = unlocked.length != existing.unlockedTitleIds.length;
      var normalized = hasChanges
          ? existing.copyWith(
              unlockedTitleIds: unlocked.toList(),
              updatedAt: DateTime.now().toIso8601String(),
            )
          : existing;

      if (unlockedFrames.length != existing.unlockedFrameIds.length ||
          normalized.activeFrameId.trim().isEmpty) {
        normalized = normalized.copyWith(
          unlockedFrameIds: unlockedFrames.toList(),
          activeFrameId: normalized.activeFrameId.trim().isEmpty
              ? _defaultAvatarFrameId
              : normalized.activeFrameId,
          updatedAt: DateTime.now().toIso8601String(),
        );
        hasChanges = true;
      }

      if (normalized.title.trim().toLowerCase() == 'aura developer') {
        normalized = normalized.copyWith(
          title: 'aura devolper',
          updatedAt: DateTime.now().toIso8601String(),
        );
        hasChanges = true;
      }

      _profile = normalized;
      if (hasChanges) {
        await _profileStore?.upsert(normalized);
      }

      if (_developerAuraEnabled) {
        await _unlockProfileTitle('aura_developer', autoEquipIfEmpty: true);
      }

      await _evaluateActionSecrets();
      await _evaluateReminderSecrets();
      await _evaluateFamilySecrets();
      return;
    }

    _profile = UserProfile(
      email: email,
      displayName: '',
      title: 'Med Rookie',
      updatedAt: DateTime.now().toIso8601String(),
      avatarImageBase64: null,
      tags: <String>['Consistent', 'Health Focus'],
      avatarSeed: 1,
      dailyGoalTaken: 2,
      totalTaken: 0,
      totalSnoozed: 0,
      totalDismissed: 0,
      totalNoResponse: 0,
      currentStreakDays: 0,
      bestStreakDays: 0,
      lastTakenDateIso: null,
      activities: <ProfileActivityItem>[],
      unlockedTitleIds: <String>[_defaultTitleId],
      unlockedFrameIds: <String>[_defaultAvatarFrameId],
      activeFrameId: _defaultAvatarFrameId,
    );
    await _profileStore?.upsert(_profile!);

    if (_developerAuraEnabled) {
      await _unlockProfileTitle('aura_developer', autoEquipIfEmpty: true);
    }
  }

  Future<void> updateProfile({
    required String displayName,
    required String title,
  }) async {
    await _ensureLocalServices();

    final email = _user?.email ?? _cachedUserEmailFallback();
    if (email.trim().isEmpty || email == 'You') {
      return;
    }

    final current =
        _profileStore?.getSync(email) ??
        UserProfile(
          email: email,
          displayName: '',
          title: 'Med Rookie',
          updatedAt: DateTime.now().toIso8601String(),
          avatarImageBase64: null,
          tags: <String>['Consistent', 'Health Focus'],
          avatarSeed: 1,
          dailyGoalTaken: 2,
          totalTaken: 0,
          totalSnoozed: 0,
          totalDismissed: 0,
          totalNoResponse: 0,
          currentStreakDays: 0,
          bestStreakDays: 0,
          lastTakenDateIso: null,
          activities: <ProfileActivityItem>[],
          unlockedTitleIds: <String>[_defaultTitleId],
          unlockedFrameIds: <String>[_defaultAvatarFrameId],
          activeFrameId: _defaultAvatarFrameId,
        );

    final next = current.copyWith(
      displayName: displayName.trim(),
      title: title.trim(),
      unlockedTitleIds: (current.unlockedTitleIds.toSet()..add(_defaultTitleId))
          .toList(),
      unlockedFrameIds:
          (current.unlockedFrameIds.toSet()..add(_defaultAvatarFrameId))
              .toList(),
      activeFrameId: current.activeFrameId.trim().isEmpty
          ? _defaultAvatarFrameId
          : current.activeFrameId,
      updatedAt: DateTime.now().toIso8601String(),
    );

    _profile = next;
    await _profileStore!.upsert(next);
    notifyListeners();
  }

  Future<void> setProfileDailyGoal(int goal) async {
    final p = _profile;
    if (p == null || goal < 1) {
      return;
    }
    final next = p.copyWith(
      dailyGoalTaken: goal,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
    await _evaluateActionSecrets();
  }

  Future<void> pickProfilePicture() async {
    final p = _profile;
    if (p == null) {
      return;
    }

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      throw ApiException('Could not read selected image file.');
    }

    // Keep profile pictures compact in local storage.
    const maxBytes = 1024 * 1024;
    if (bytes.length > maxBytes) {
      throw ApiException('Image too large. Choose a file under 1MB.');
    }

    final next = p.copyWith(
      avatarImageBase64: base64Encode(bytes),
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> clearProfilePicture() async {
    final p = _profile;
    if (p == null) {
      return;
    }
    final next = p.copyWith(
      avatarImageBase64: '',
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> equipAvatarFrame(String frameId) async {
    final p = _profile;
    if (p == null || !isAvatarFrameUnlocked(frameId)) {
      return;
    }
    final next = p.copyWith(
      activeFrameId: frameId,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> addProfileTag(String tag) async {
    final p = _profile;
    final normalized = tag.trim();
    if (p == null || normalized.isEmpty) {
      return;
    }

    final tags = List<String>.from(p.tags);
    if (tags.any((t) => t.toLowerCase() == normalized.toLowerCase())) {
      return;
    }
    tags.add(normalized);

    final next = p.copyWith(
      tags: tags,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> removeProfileTag(String tag) async {
    final p = _profile;
    if (p == null) {
      return;
    }
    final tags = p.tags
        .where((t) => t.toLowerCase() != tag.trim().toLowerCase())
        .toList();
    final next = p.copyWith(
      tags: tags,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> equipProfileTitle(String titleId) async {
    final p = _profile;
    if (p == null || !isProfileTitleUnlocked(titleId)) {
      return;
    }
    final meta = profileTitleById(titleId);
    if (meta == null) {
      return;
    }

    final next = p.copyWith(
      title: meta.label,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> _unlockProfileTitle(
    String titleId, {
    bool autoEquipIfEmpty = false,
  }) async {
    final p = _profile;
    if (p == null) {
      return;
    }

    final meta = profileTitleById(titleId);
    if (meta == null) {
      return;
    }

    final unlocked = p.unlockedTitleIds.toSet();
    unlocked.add(_defaultTitleId);
    if (unlocked.contains(titleId)) {
      return;
    }

    unlocked.add(titleId);
    final shouldEquip = autoEquipIfEmpty && p.title.trim().isEmpty;

    final next = p.copyWith(
      unlockedTitleIds: unlocked.toList(),
      title: shouldEquip ? meta.label : p.title,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    _pendingUnlockQueue.add(
      ProfileUnlockEvent(
        kind: 'title',
        id: titleId,
        label: meta.label,
        description: meta.description,
        isSecret: meta.isSecret,
      ),
    );
    notifyListeners();
  }

  Future<void> _unlockAvatarFrame(
    String frameId, {
    bool autoEquipIfDefault = false,
  }) async {
    final p = _profile;
    if (p == null) {
      return;
    }
    final meta = avatarFrameById(frameId);
    if (meta == null) {
      return;
    }

    final unlocked = p.unlockedFrameIds.toSet();
    unlocked.add(_defaultAvatarFrameId);
    if (unlocked.contains(frameId)) {
      return;
    }

    unlocked.add(frameId);
    final currentFrame =
        p.activeFrameId.trim().isEmpty ? _defaultAvatarFrameId : p.activeFrameId;
    final shouldAutoEquip =
        autoEquipIfDefault && currentFrame == _defaultAvatarFrameId;
    final next = p.copyWith(
      unlockedFrameIds: unlocked.toList(),
      activeFrameId: shouldAutoEquip ? frameId : currentFrame,
      updatedAt: DateTime.now().toIso8601String(),
    );
    _profile = next;
    await _profileStore?.upsert(next);
    _pendingUnlockQueue.add(
      ProfileUnlockEvent(
        kind: 'frame',
        id: frameId,
        label: meta.label,
        description: meta.description,
        isSecret: meta.isSecret,
      ),
    );
    notifyListeners();
  }

  Future<void> _evaluateReminderSecrets() async {
    final p = _profile;
    if (p == null) {
      return;
    }

    final ownEmail = (_user?.email ?? p.email).trim();
    if (ownEmail.isEmpty) {
      return;
    }

    final ownReminders = _reminders.where((r) => r.userEmail == ownEmail).toList();
    if (ownReminders.length >= 10) {
      await _unlockProfileTitle('schedule_architect');
    }

    final byTime = <String, int>{};
    int nightCount = 0;
    for (final reminder in ownReminders) {
      final times = reminder.times.isNotEmpty
          ? reminder.times
          : <String>[reminder.time];
      for (final raw in times) {
        final key = raw.trim();
        if (key.isEmpty) {
          continue;
        }
        byTime[key] = (byTime[key] ?? 0) + 1;

        final hour = _hourFromTime(key);
        if (hour != null && (hour >= 22 || hour <= 5)) {
          nightCount += 1;
        }
      }
    }

    for (final count in byTime.values) {
      if (count >= 5) {
        await _unlockProfileTitle('the_banger', autoEquipIfEmpty: true);
        break;
      }
    }

    if (nightCount >= 3) {
      await _unlockProfileTitle('night_watch');
    }

  }

  Future<void> _evaluateFamilySecrets() async {
    if (_familyMembers.length >= 3) {
      await _unlockProfileTitle('family_guardian');
      await _unlockAvatarFrame('guardian');
    }
  }

  Future<void> _evaluateActionSecrets() async {
    final p = _profile;
    if (p == null) {
      return;
    }

    if (p.bestStreakDays >= 7) {
      await _unlockProfileTitle('streak_samurai');
    }
    if (p.bestStreakDays >= 5) {
      await _unlockAvatarFrame('fire');
    }
    if (p.totalTaken >= 50) {
      await _unlockProfileTitle('dose_legend');
    }
    if (p.totalTaken >= 25) {
      await _unlockAvatarFrame('ice');
    }
    if (p.totalNoResponse >= 1 && p.totalTaken >= 10) {
      await _unlockProfileTitle('comeback_hero');
    }
  }

  List<String> _sanitizeTimes(Iterable<String> raw, {required String fallback}) {
    final out = <String>[];
    final seen = <String>{};
    for (final item in raw) {
      final value = item.trim();
      if (!_isValidTime(value)) {
        continue;
      }
      if (seen.add(value)) {
        out.add(value);
      }
    }
    if (out.isNotEmpty) {
      return out;
    }
    final normalizedFallback = _isValidTime(fallback.trim())
        ? fallback.trim()
        : '08:00';
    return <String>[normalizedFallback];
  }

  bool _isValidTime(String raw) {
    final parts = raw.split(':');
    if (parts.length != 2) {
      return false;
    }
    final hour = int.tryParse(parts[0].trim());
    final minute = int.tryParse(parts[1].trim());
    return hour != null &&
        minute != null &&
        hour >= 0 &&
        hour <= 23 &&
        minute >= 0 &&
        minute <= 59;
  }

  DateTime? _dueAtForTime(String rawTime, DateTime now) {
    final parts = rawTime.trim().split(':');
    if (parts.length != 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(now.year, now.month, now.day, hour, minute);
  }

  int? _hourFromTime(String raw) {
    final parts = raw.split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0].trim());
    if (hour == null || hour < 0 || hour > 23) {
      return null;
    }
    return hour;
  }

  Future<void> _recordProfileAction({
    required DueReminderOccurrence occurrence,
    required String action,
  }) async {
    final p = _profile;
    if (p == null) {
      return;
    }

    final now = DateTime.now();
    final activities = <ProfileActivityItem>[
      ProfileActivityItem(
        type: action,
        medName: occurrence.medName,
        timestampIso: now.toIso8601String(),
      ),
      ...p.activities,
    ];
    if (activities.length > 30) {
      activities.removeRange(30, activities.length);
    }

    int totalTaken = p.totalTaken;
    int totalSnoozed = p.totalSnoozed;
    int totalDismissed = p.totalDismissed;
    int totalNoResponse = p.totalNoResponse;
    int currentStreakDays = p.currentStreakDays;
    int bestStreakDays = p.bestStreakDays;
    String? lastTakenDateIso = p.lastTakenDateIso;

    if (action == 'taken') {
      totalTaken += 1;

      final today = DateTime(now.year, now.month, now.day);
      final last = p.lastTakenDateIso == null
          ? null
          : DateTime.tryParse(p.lastTakenDateIso!);

      if (last == null) {
        currentStreakDays = 1;
      } else {
        final lastDay = DateTime(last.year, last.month, last.day);
        final diff = today.difference(lastDay).inDays;
        if (diff == 0) {
          // Same day: keep streak unchanged.
        } else if (diff == 1) {
          currentStreakDays += 1;
        } else {
          currentStreakDays = 1;
        }
      }

      if (currentStreakDays > bestStreakDays) {
        bestStreakDays = currentStreakDays;
      }
      lastTakenDateIso = today.toIso8601String();
    } else if (action == 'snooze') {
      totalSnoozed += 1;
    } else if (action == 'dismiss') {
      totalDismissed += 1;
    } else if (action == 'no_response') {
      totalNoResponse += 1;
    }

    final next = p.copyWith(
      totalTaken: totalTaken,
      totalSnoozed: totalSnoozed,
      totalDismissed: totalDismissed,
      totalNoResponse: totalNoResponse,
      currentStreakDays: currentStreakDays,
      bestStreakDays: bestStreakDays,
      lastTakenDateIso: lastTakenDateIso,
      activities: activities,
      updatedAt: now.toIso8601String(),
    );

    _profile = next;
    await _profileStore?.upsert(next);
    notifyListeners();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _soundEnabled = prefs.getBool(_soundEnabledKey) ?? true;
    _vibrationEnabled = prefs.getBool(_vibrationEnabledKey) ?? true;
    _soundId = prefs.getString(_soundIdKey) ?? 'beep';
    _customSoundName = prefs.getString(_customSoundNameKey);
    _customSoundBase64 = prefs.getString(_customSoundBase64Key);
    if (_soundId == 'custom' &&
        (_customSoundBase64 == null || _customSoundBase64!.isEmpty)) {
      _soundId = 'beep';
    }

    final storedSnooze = prefs.getInt(_snoozeThresholdKey) ?? 3;
    _snoozeThreshold = storedSnooze == 5 ? 5 : 3;

    final storedCriticalDelay = prefs.getInt(_criticalDelayMinutesKey) ?? 30;
    if (storedCriticalDelay == 15 ||
        storedCriticalDelay == 30 ||
        storedCriticalDelay == 45 ||
        storedCriticalDelay == 60) {
      _criticalDelayMinutes = storedCriticalDelay;
    } else {
      _criticalDelayMinutes = 30;
    }

    _darkModeEnabled = prefs.getBool(_darkModeEnabledKey) ?? false;
    _developerAuraEnabled = prefs.getBool(_developerAuraEnabledKey) ?? false;
  }

  Future<void> _runBusy(Future<void> Function() action) async {
    _isBusy = true;
    notifyListeners();

    try {
      await action();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        _errorMessage = 'Your session expired. Please log in again.';
        await logout(clearLocalData: false);
        throw ApiException(_errorMessage!, statusCode: error.statusCode);
      }

      _errorMessage = error.message;
      rethrow;
    } catch (error) {
      _errorMessage = error.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  void _setOffline(bool value, {String? message}) {
    _isOffline = value;
    _offlineMessage = value ? (message ?? 'Backend unavailable') : null;
    notifyListeners();
  }

  void _clearError() {
    _errorMessage = null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _inAppDueSub?.cancel();
    _notificationTapSub?.cancel();
    _connectivitySub?.cancel();
    _syncTimer?.cancel();
    unawaited(_inAppDueEngine?.dispose());
    super.dispose();
  }
}
