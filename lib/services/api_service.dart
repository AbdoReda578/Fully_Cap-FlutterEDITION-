import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/api_config.dart';
import '../core/api_exception.dart';
import '../models/barcode_medication_model.dart';
import '../models/alert_event_model.dart';
import '../models/care_patient_model.dart';
import '../models/email_status_model.dart';
import '../models/family_model.dart';
import '../models/reminder_model.dart';
import '../models/user_model.dart';

class AuthPayload {
  AuthPayload({required this.token, required this.user});

  final String token;
  final UserModel user;
}

class DueReminderCheckResult {
  DueReminderCheckResult({required this.currentTime, required this.reminders});

  final String currentTime;
  final List<DueReminderModel> reminders;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };

    final baseUrls = ApiConfig.candidateBaseUrls();
    ApiException? lastNetworkError;

    for (final baseUrl in baseUrls) {
      final uri = Uri.parse('$baseUrl$path');
      http.Response response;

      try {
        if (method == 'GET') {
          response = await _client.get(uri, headers: headers);
        } else if (method == 'POST') {
          response = await _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? <String, dynamic>{}),
          );
        } else if (method == 'PATCH') {
          response = await _client.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? <String, dynamic>{}),
          );
        } else if (method == 'DELETE') {
          response = await _client.delete(
            uri,
            headers: headers,
            body: body == null ? null : jsonEncode(body),
          );
        } else {
          throw ApiException('Unsupported HTTP method: $method');
        }
      } on SocketException {
        lastNetworkError = ApiException(
          'Cannot connect to backend at $baseUrl.',
        );
        continue;
      } on HttpException catch (error) {
        lastNetworkError = ApiException(error.message);
        continue;
      }

      Map<String, dynamic> payload = <String, dynamic>{};
      if (response.bodyBytes.isNotEmpty) {
        final bodyText = utf8.decode(response.bodyBytes);
        if (bodyText.trim().isNotEmpty) {
          try {
            final decoded = jsonDecode(bodyText);
            if (decoded is Map<String, dynamic>) {
              payload = decoded;
            }
          } on FormatException {
            // Non-JSON response, try next candidate host.
            continue;
          }
        }
      }

      // Ignore hosts that do not return the MedReminder API shape.
      if (!payload.containsKey('success')) {
        continue;
      }

      if (response.statusCode >= 400 || payload['success'] == false) {
        final message = (payload['message'] ?? 'Request failed').toString();
        throw ApiException(message, statusCode: response.statusCode);
      }

      ApiConfig.rememberWorkingBaseUrl(baseUrl);
      return payload;
    }

    if (lastNetworkError != null) {
      throw ApiException(
        '${lastNetworkError.message} Tried: ${baseUrls.join(', ')}. '
        'Run backend with "python app.py" and/or set API_BASE_URL.',
      );
    }

    throw ApiException(
      'Could not find a valid MedReminder backend. '
      'Tried: ${baseUrls.join(', ')}. '
      'Set API_BASE_URL to your backend host.',
    );
  }

  Future<AuthPayload> login(String email, String password) async {
    final payload = await _request(
      'POST',
      '/api/v1/auth/login',
      body: <String, dynamic>{'email': email, 'password': password},
    );

    final token = (payload['token'] ?? '').toString();
    final userJson = payload['user'];
    if (token.isEmpty || userJson is! Map<String, dynamic>) {
      throw ApiException('Login failed, try again later');
    }

    return AuthPayload(token: token, user: UserModel.fromJson(userJson));
  }

  Future<AuthPayload> signup(
    String email,
    String password,
    String age, {
    required String role,
  }) async {
    final payload = await _request(
      'POST',
      '/api/v1/auth/signup',
      body: <String, dynamic>{
        'email': email,
        'password': password,
        'age': age,
        'role': role,
      },
    );

    final token = (payload['token'] ?? '').toString();
    final userJson = payload['user'];
    if (token.isEmpty || userJson is! Map<String, dynamic>) {
      throw ApiException('Signup failed, try again later');
    }

    return AuthPayload(token: token, user: UserModel.fromJson(userJson));
  }

  Future<(UserModel, FamilyModel?)> me(String token) async {
    final payload = await _request('GET', '/api/v1/auth/me', token: token);
    final userJson = payload['user'] as Map<String, dynamic>;
    final familyJson = payload['family'];

    return (
      UserModel.fromJson(userJson),
      familyJson is Map<String, dynamic>
          ? FamilyModel.fromJson(familyJson)
          : null,
    );
  }

  Future<FamilyModel?> getFamily(String token) async {
    final payload = await _request('GET', '/api/v1/family', token: token);
    final familyJson = payload['family'];
    if (familyJson is Map<String, dynamic>) {
      return FamilyModel.fromJson(familyJson);
    }
    return null;
  }

  Future<List<String>> getFamilyMembers(String token) async {
    final payload = await _request(
      'GET',
      '/api/v1/family/members',
      token: token,
    );
    final members = payload['family_members'];
    if (members is List) {
      return members
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return <String>[];
  }

  Future<FamilyModel> createFamily(String token, String familyName) async {
    final payload = await _request(
      'POST',
      '/api/v1/family/create',
      token: token,
      body: <String, dynamic>{'family_name': familyName},
    );
    return FamilyModel.fromJson(payload['family'] as Map<String, dynamic>);
  }

  Future<FamilyModel> joinFamily(String token, String familyId) async {
    final payload = await _request(
      'POST',
      '/api/v1/family/join',
      token: token,
      body: <String, dynamic>{'family_id': familyId},
    );
    return FamilyModel.fromJson(payload['family'] as Map<String, dynamic>);
  }

  Future<FamilyModel> addFamilyMember(String token, String email) async {
    final payload = await _request(
      'POST',
      '/api/v1/family/add-member',
      token: token,
      body: <String, dynamic>{'member_email': email},
    );
    return FamilyModel.fromJson(payload['family'] as Map<String, dynamic>);
  }

  Future<void> removeFamilyMember(String token, String memberEmail) async {
    await _request(
      'DELETE',
      '/api/v1/family/members/${Uri.encodeComponent(memberEmail)}',
      token: token,
    );
  }

  Future<FamilyModel> updateFamilyMemberPermissions(
    String token, {
    required String memberEmail,
    required Map<String, bool> permissions,
  }) async {
    final payload = await _request(
      'PATCH',
      '/api/v1/family/members/${Uri.encodeComponent(memberEmail)}/permissions',
      token: token,
      body: <String, dynamic>{'permissions': permissions},
    );
    return FamilyModel.fromJson(payload['family'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> getFamilyInviteCode(String token) async {
    final payload = await _request('GET', '/api/v1/family/invite-code', token: token);
    return <String, dynamic>{
      'invite_code': (payload['invite_code'] ?? '').toString(),
      'invite_payload': (payload['invite_payload'] ?? '').toString(),
      'family_id': (payload['family_id'] ?? '').toString(),
      'patient_email': (payload['patient_email'] ?? '').toString(),
    };
  }

  Future<FamilyModel> updateFamilyTitle(
    String token, {
    required String title,
  }) async {
    final payload = await _request(
      'PATCH',
      '/api/v1/family/title',
      token: token,
      body: <String, dynamic>{'title': title},
    );
    return FamilyModel.fromJson(payload['family'] as Map<String, dynamic>);
  }

  Future<void> leaveFamily(String token) async {
    await _request('POST', '/api/v1/family/leave', token: token);
  }

  Future<List<ReminderModel>> getReminders(String token) async {
    final payload = await _request('GET', '/api/v1/reminders', token: token);
    final reminders = payload['reminders'];
    if (reminders is List) {
      return reminders
          .whereType<Map<String, dynamic>>()
          .map(ReminderModel.fromJson)
          .toList();
    }
    return <ReminderModel>[];
  }

  Future<ReminderModel> createReminder(
    String token, {
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
    final payload = await _request(
      'POST',
      '/api/v1/reminders',
      token: token,
      body: <String, dynamic>{
        'med_name': medName,
        'dose': dose,
        'time': time,
        'times': times,
        'notification_type': notificationType,
        'selected_family_members': selectedFamilyMembers,
        'single_family_member': singleFamilyMember,
        'email_notifications': emailNotifications,
        'calendar_sync': calendarSync,
      },
    );

    return ReminderModel.fromJson(payload['reminder'] as Map<String, dynamic>);
  }

  Future<void> deleteReminder(String token, String reminderId) async {
    await _request('DELETE', '/api/v1/reminders/$reminderId', token: token);
  }

  Future<ReminderModel> updateReminder(
    String token, {
    required String reminderId,
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
    final payload = await _request(
      'PATCH',
      '/api/v1/reminders/$reminderId',
      token: token,
      body: <String, dynamic>{
        'med_name': medName,
        'dose': dose,
        'time': time,
        'times': times,
        'notification_type': notificationType,
        'selected_family_members': selectedFamilyMembers,
        'single_family_member': singleFamilyMember,
        'email_notifications': emailNotifications,
        'calendar_sync': calendarSync,
      },
    );

    return ReminderModel.fromJson(payload['reminder'] as Map<String, dynamic>);
  }

  Future<void> recordReminderAction(
    String token, {
    required String reminderId,
    required String action,
    String? occurredAt,
    Map<String, dynamic>? metadata,
  }) async {
    await _request(
      'POST',
      '/api/v1/reminders/$reminderId/actions',
      token: token,
      body: <String, dynamic>{
        'action': action,
        if (occurredAt != null && occurredAt.trim().isNotEmpty)
          'occurred_at': occurredAt,
        'metadata': metadata ?? <String, dynamic>{},
      },
    );
  }

  Future<String> escalateReminder(
    String token, {
    required String reminderId,
    required String reason,
    int snoozeCount = 0,
    int delayMinutes = 30,
  }) async {
    final payload = await _request(
      'POST',
      '/api/v1/reminders/$reminderId/escalate',
      token: token,
      body: <String, dynamic>{
        'reason': reason,
        'snooze_count': snoozeCount,
        'delay_minutes': delayMinutes,
      },
    );

    return (payload['message'] ?? 'Escalation alert sent.').toString();
  }

  Future<List<AlertEventModel>> getAlerts(String token) async {
    final payload = await _request('GET', '/api/v1/alerts', token: token);
    final alerts = payload['alerts'];
    if (alerts is List) {
      return alerts
          .whereType<Map<String, dynamic>>()
          .map(AlertEventModel.fromJson)
          .toList();
    }
    return <AlertEventModel>[];
  }

  Future<void> markAlertRead(String token, String alertId) async {
    await _request('POST', '/api/v1/alerts/$alertId/read', token: token);
  }

  Future<DueReminderCheckResult> checkNow(String token) async {
    final payload = await _request(
      'GET',
      '/api/v1/reminders/check-now',
      token: token,
    );
    final remindersJson = payload['reminders'];
    final reminders = remindersJson is List
        ? remindersJson
              .whereType<Map<String, dynamic>>()
              .map(DueReminderModel.fromJson)
              .toList()
        : <DueReminderModel>[];

    return DueReminderCheckResult(
      currentTime: (payload['current_time'] ?? '').toString(),
      reminders: reminders,
    );
  }

  Future<BarcodeMedicationModel> barcodeLookup(
    String token,
    String barcode,
  ) async {
    final payload = await _request(
      'GET',
      '/api/v1/barcode/$barcode',
      token: token,
    );
    return BarcodeMedicationModel.fromJson(
      payload['medication'] as Map<String, dynamic>,
    );
  }

  Future<EmailStatusModel> emailStatus(String token) async {
    final payload = await _request('GET', '/api/v1/email/status', token: token);
    return EmailStatusModel.fromJson(payload);
  }

  Future<List<CarePatientSummary>> listCarePatients(String token) async {
    final payload = await _request('GET', '/api/v1/care/patients', token: token);
    final patients = payload['patients'];
    if (patients is List) {
      return patients
          .whereType<Map<String, dynamic>>()
          .map(CarePatientSummary.fromJson)
          .toList();
    }
    return <CarePatientSummary>[];
  }

  Future<CarePatientDashboard> getCarePatientDashboard(
    String token, {
    required String patientEmail,
  }) async {
    final payload = await _request(
      'GET',
      '/api/v1/care/patients/${Uri.encodeComponent(patientEmail)}/dashboard',
      token: token,
    );
    return CarePatientDashboard.fromJson(
      payload['patient'] as Map<String, dynamic>,
    );
  }

  Future<List<CareEventItem>> getCarePatientHistory(
    String token, {
    required String patientEmail,
    int limit = 120,
  }) async {
    final payload = await _request(
      'GET',
      '/api/v1/care/patients/${Uri.encodeComponent(patientEmail)}/history?limit=$limit',
      token: token,
    );
    final events = payload['events'];
    if (events is List) {
      return events
          .whereType<Map<String, dynamic>>()
          .map(CareEventItem.fromJson)
          .toList();
    }
    return <CareEventItem>[];
  }

  Future<void> postCareLocation(
    String token, {
    required double lat,
    required double lng,
    String? timestamp,
  }) async {
    await _request(
      'POST',
      '/api/v1/care/location',
      token: token,
      body: <String, dynamic>{
        'lat': lat,
        'lng': lng,
        if (timestamp != null && timestamp.trim().isNotEmpty)
          'timestamp': timestamp,
      },
    );
  }

  Future<String> testGmail(String token) async {
    final payload = await _request(
      'POST',
      '/api/v1/email/test-gmail-oauth',
      token: token,
    );
    return (payload['message'] ?? 'Success').toString();
  }

  Future<String> testEmail(
    String token, {
    required List<String> recipients,
    required String templateType,
  }) async {
    final payload = await _request(
      'POST',
      '/api/v1/email/test',
      token: token,
      body: <String, dynamic>{
        'recipients': recipients,
        'test_type': 'manual_test',
        'template_type': templateType,
      },
    );

    return (payload['message'] ?? 'Emails queued').toString();
  }
}
