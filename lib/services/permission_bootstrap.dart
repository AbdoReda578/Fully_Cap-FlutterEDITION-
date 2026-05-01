import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionBootstrap {
  const PermissionBootstrap._();

  static bool _requestedOnce = false;

  static Future<void> requestInitialPermissions() async {
    if (_requestedOnce) {
      return;
    }
    _requestedOnce = true;

    // In widget tests / some platforms, the plugin may not be available.
    try {
      // Ask notifications first (so scheduled reminders can alert).
      // Android 13+ needs runtime notification permission.
      await Permission.notification.request();

      // Ask camera next (barcode scanning).
      await Permission.camera.request();
    } on MissingPluginException catch (e) {
      debugPrint('Permissions plugin not available: $e');
    } catch (e) {
      debugPrint('Permission request failed: $e');
    }
  }
}

