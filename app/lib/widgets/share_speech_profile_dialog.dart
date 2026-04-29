import 'package:flutter/material.dart';

import 'package:omi/backend/http/api/speech_profile.dart';
import 'package:omi/backend/preferences.dart';
import 'package:omi/pages/speech_profile/page.dart';
import 'package:omi/utils/alerts/app_snackbar.dart';
import 'package:omi/utils/l10n_extensions.dart';
import 'package:omi/utils/other/temp.dart';
import 'package:omi/widgets/dialog.dart';

Future<bool> showShareSpeechProfileDialog(
  BuildContext context, {
  bool? cachedHasProfile,
}) async {
  final hasProfile = (cachedHasProfile == true) ? true : await userHasSpeakerProfile();
  if (!context.mounted) return false;

  if (!hasProfile) {
    final goRecord = await showDialog<bool>(
      context: context,
      builder: (c) => getDialog(
        context,
        () => Navigator.pop(context, false),
        () => Navigator.pop(context, true),
        context.l10n.shareSpeechProfile,
        context.l10n.noSpeechProfileRecorded,
        okButtonText: context.l10n.recordNow,
      ),
    );
    if (goRecord == true && context.mounted) {
      routeToPage(context, const SpeechProfilePage());
    }
    return false;
  }

  final shared = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const _ShareSpeechProfileDialog(),
  );
  return shared == true;
}

class _ShareSpeechProfileDialog extends StatefulWidget {
  const _ShareSpeechProfileDialog();

  @override
  State<_ShareSpeechProfileDialog> createState() => _ShareSpeechProfileDialogState();
}

class _ShareSpeechProfileDialogState extends State<_ShareSpeechProfileDialog> {
  final _controller = TextEditingController();
  bool _isSharing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    final targetUid = _controller.text.trim();
    if (targetUid.isEmpty) return;
    if (targetUid == SharedPreferencesUtil().uid) {
      final message = context.l10n.cannotShareWithSelf;
      Navigator.pop(context);
      AppSnackbar.showSnackbarError(message);
      return;
    }

    setState(() => _isSharing = true);
    final result = await shareSpeechProfile(targetUid);
    if (!mounted) return;

    if (result['status'] == 'ok') {
      final message = context.l10n.profileSharedSuccess;
      Navigator.pop(context, true);
      AppSnackbar.showSnackbarSuccess(message);
      return;
    }

    final error = result['error'] ?? '';
    String message;
    if (error.contains('not found')) {
      message = context.l10n.userNotFound;
    } else if (error.contains('yourself')) {
      message = context.l10n.cannotShareWithSelf;
    } else if (error.contains('No speech profile')) {
      message = context.l10n.noSpeechProfileRecorded;
    } else if (error.contains('Already shared')) {
      message = context.l10n.alreadySharedWithUser;
    } else {
      message = context.l10n.profileSharedFail;
    }
    Navigator.pop(context);
    AppSnackbar.showSnackbarError(message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1C1C1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(context.l10n.shareSpeechProfile, style: const TextStyle(color: Colors.white)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(context.l10n.enterUserIdToShare, style: const TextStyle(color: Color(0xFF8E8E93), fontSize: 14)),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            enabled: !_isSharing,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: context.l10n.userId,
              hintStyle: const TextStyle(color: Color(0xFF636366)),
              enabledBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF3C3C43))),
              focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: Colors.white)),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSharing ? null : () => Navigator.pop(context),
          child: Text(context.l10n.cancel, style: TextStyle(color: _isSharing ? Colors.grey : Colors.white)),
        ),
        TextButton(
          onPressed: _isSharing ? null : _share,
          child: _isSharing
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(context.l10n.share, style: const TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
