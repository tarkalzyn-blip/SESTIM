import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cow_pregnancy/utils/app_settings.dart';
import 'package:cow_pregnancy/services/firestore_service.dart';

class EditAccessNotifier extends StateNotifier<bool> {
  final FirestoreService _firestore = FirestoreService();
  StreamSubscription? _subscription;

  EditAccessNotifier() : super(AppSettings.isEditor) {
    _startListeningToCloud();
  }

  void _startListeningToCloud() {
    _subscription?.cancel();
    _subscription = _firestore.securitySettingsStream.listen((settings) {
      if (settings != null) {
        if (settings.containsKey('adminCode')) {
          AppSettings.setAdminCode(settings['adminCode']);
        }
        if (settings.containsKey('protectionEnabled')) {
          AppSettings.setProtectionEnabled(settings['protectionEnabled']);
        }
        // Force UI refresh if protection is disabled globally
        if (!AppSettings.isProtectionEnabled) {
          state = true; // Everyone becomes an editor if protection is off
        } else {
          state = AppSettings.isEditor;
        }
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<bool> verifyAndEnable(String code) async {
    if (code == AppSettings.adminCode) {
      await AppSettings.setEditor(true);
      state = true;
      return true;
    }
    return false;
  }

  void disableEditMode() {
    AppSettings.setEditor(false);
    state = false;
  }

  Future<void> toggleProtection(bool enabled) async {
    await AppSettings.setProtectionEnabled(enabled);
    await _firestore.updateSecuritySettings({
      'protectionEnabled': enabled,
    });
    if (!enabled) {
      state = true;
    } else {
      state = AppSettings.isEditor;
    }
  }

  Future<void> updateCode(String oldCode, String newCode) async {
    if (oldCode != AppSettings.adminCode) {
      throw Exception('الكود الحالي غير صحيح');
    }
    if (newCode.length < 4) {
      throw Exception('يجب أن يتكون الكود من 4 أرقام على الأقل');
    }
    await AppSettings.setAdminCode(newCode);
    await _firestore.updateSecuritySettings({
      'adminCode': newCode,
    });
  }

  /// Helper to run an action if authorized, or show dialog if not
  void runWithAccess(BuildContext context, VoidCallback action) {
    if (!AppSettings.isProtectionEnabled || state) {
      action();
      return;
    }
    _showAccessDialog(context, action);
  }

  void _showAccessDialog(BuildContext context, VoidCallback onSuccess) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_outline, color: Colors.orange),
            SizedBox(width: 8),
            Text('وضع المشاهد'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أنت حالياً في وضع المشاهد فقط. يرجى إدخال كود المسؤول لتتمكن من التعديل أو الحذف.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'كود المسؤول',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.password),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () async {
              final success = await verifyAndEnable(controller.text);
              if (success) {
                if (context.mounted) {
                  Navigator.pop(ctx);
                  onSuccess();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تفعيل وضع التعديل بنجاح'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } else {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('كود المسؤول غير صحيح!'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }
}

final editAccessProvider = StateNotifierProvider<EditAccessNotifier, bool>((ref) {
  return EditAccessNotifier();
});
