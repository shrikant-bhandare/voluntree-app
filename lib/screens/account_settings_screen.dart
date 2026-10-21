import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../services/auth_service.dart';
import '../utils/file_save.dart';
import '../utils/policy_links.dart';
import '../utils/session.dart';
import '../widgets/confirm_dialog.dart';
import '../widgets/responsive.dart';
import 'edit_profile_screen.dart';

/// Account & privacy: edit profile, export data, delete account, policies.
///
/// Store policy (Play, App Store 5.1.1(v)) and DPDP require in-app account
/// deletion and access to one's data; the API has had both since launch.
class AccountSettingsScreen extends StatefulWidget {
  const AccountSettingsScreen({super.key});

  @override
  State<AccountSettingsScreen> createState() => _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends State<AccountSettingsScreen> {
  static const _primary = Color(0xFF012D1D);
  static const _error = Color(0xFFBA1A1A);
  static const _muted = Color(0xFF414844);

  bool _exporting = false;
  bool _deleting = false;

  Future<void> _export() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _exporting = true);
    final result = await auth.exportMyData();
    if (!mounted) return;
    if (result['success'] != true) {
      setState(() => _exporting = false);
      messenger.showSnackBar(SnackBar(content: Text(result['message'])));
      return;
    }
    final outcome = await saveBytesForUser(
      bytes: Uint8List.fromList(result['bytes'] as List<int>),
      fileName: 'voluntree-my-data.json',
      mimeType: 'application/json',
      dialogTitle: 'Save your Voluntree data',
    );
    if (!mounted) return;
    setState(() => _exporting = false);
    switch (outcome) {
      case SaveOutcome.saved:
        messenger.showSnackBar(
          const SnackBar(content: Text('Your data file has been saved.')),
        );
      case SaveOutcome.cancelled:
        break;
      case SaveOutcome.failed:
        messenger.showSnackBar(
          const SnackBar(
            content: Text('Could not save the file. Please try again.'),
          ),
        );
    }
  }

  Future<void> _delete() async {
    final auth = Provider.of<AuthService>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    final first = await confirmAction(
      context,
      title: 'Delete your account?',
      message:
          'Your profile, applications, attendance history, messages and '
          'certificates will be permanently deleted. You may want to download '
          'your data first.',
      confirmLabel: 'Continue',
      destructive: true,
    );
    if (!first || !mounted) return;

    final typed = await showDialog<bool>(
      context: context,
      builder: (_) => const _TypeToConfirmDialog(),
    );
    if (typed != true || !mounted) return;

    setState(() => _deleting = true);
    final error = await auth.deleteAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() => _deleting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(error), duration: const Duration(seconds: 6)),
      );
      return;
    }
    messenger.showSnackBar(
      const SnackBar(content: Text('Your account has been deleted.')),
    );
    final navigator = Navigator.of(context);
    await endSession(context);
    navigator.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AuthService>(context).currentUser;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: _primary,
        elevation: 0,
        title: const Text(
          'Account & privacy',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ResponsiveCenter(
        maxWidth: 720,
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            if (user != null)
              ListTile(
                title: Text(
                  user.fullName.isEmpty ? 'Your account' : user.fullName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: _primary,
                  ),
                ),
                subtitle: Text(
                  user.email.isNotEmpty ? user.email : (user.phoneNumber ?? ''),
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: _primary),
              title: const Text('Edit profile'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditProfileScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.download_outlined, color: _primary),
              title: const Text('Download my data'),
              subtitle: const Text(
                'A JSON file with everything Voluntree holds about you.',
              ),
              trailing: _exporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _exporting ? null : _export,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.description_outlined, color: _muted),
              title: const Text('Terms of Service'),
              onTap: () => openPolicyLink(context, AppConfig.termsUrl),
            ),
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined, color: _muted),
              title: const Text('Privacy Policy'),
              onTap: () => openPolicyLink(context, AppConfig.privacyUrl),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined, color: _error),
              title: const Text(
                'Delete my account',
                style: TextStyle(color: _error, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Permanently removes your account.'),
              trailing: _deleting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: _deleting ? null : _delete,
            ),
          ],
        ),
      ),
    );
  }
}

/// Second step of account deletion: the user types DELETE.
class _TypeToConfirmDialog extends StatefulWidget {
  const _TypeToConfirmDialog();

  @override
  State<_TypeToConfirmDialog> createState() => _TypeToConfirmDialogState();
}

class _TypeToConfirmDialogState extends State<_TypeToConfirmDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _matches => _controller.text.trim() == 'DELETE';

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Type DELETE to confirm'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This cannot be undone.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Type DELETE',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFBA1A1A),
            foregroundColor: Colors.white,
          ),
          onPressed: _matches ? () => Navigator.pop(context, true) : null,
          child: const Text('Delete account'),
        ),
      ],
    );
  }
}
