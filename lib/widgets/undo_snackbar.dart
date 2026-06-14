import 'dart:async';

import 'package:flutter/material.dart';

import '../providers/email_provider.dart';

/// Default time a non-undo confirmation toast stays on screen.
const Duration kToastDuration = Duration(seconds: 4);

/// Shows a plain confirmation toast that reliably auto-dismisses after
/// [timeout]. The explicit close guards against the platform pausing the
/// SnackBar's built-in timer (e.g. pointer hover on desktop), which otherwise
/// leaves the toast on screen until manually dismissed.
void showAutoDismissSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  Duration timeout = kToastDuration,
}) {
  var settled = false;
  final controller = messenger.showSnackBar(
    SnackBar(content: Text(message), duration: timeout),
  );
  unawaited(controller.closed.then((_) => settled = true));
  Timer(timeout, () {
    if (!settled) {
      controller.close();
    }
  });
}

/// The app's standard "undo" toast.
///
/// Shows a SnackBar with an optional **Undo** action. [onUndo] runs if the user
/// taps Undo (pass null for a plain, action-less bar). [onExpire] runs once the
/// [window] elapses without an undo — e.g. to commit a deferred operation — and
/// is skipped when the bar is dismissed via Undo. Operations that are already
/// scheduled elsewhere (such as a queued send) simply omit [onExpire].
///
/// The toast is force-closed after [window] so it never lingers, even if the
/// platform pauses the SnackBar's built-in timer.
void showUndoSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required Duration window,
  VoidCallback? onUndo,
  Future<void> Function()? onExpire,
}) {
  var undone = false;
  var settled = false;
  final controller = messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: window,
      action: onUndo == null
          ? null
          : SnackBarAction(
              label: 'Undo',
              onPressed: () {
                undone = true;
                onUndo();
              },
            ),
    ),
  );
  Timer(window, () {
    if (!settled) {
      controller.close();
    }
  });
  unawaited(
    controller.closed.then((reason) async {
      settled = true;
      if (undone || reason == SnackBarClosedReason.action) {
        return;
      }
      if (onExpire == null) {
        return;
      }
      try {
        await onExpire();
      } catch (_) {
        // Best-effort: the originating context may have been torn down (e.g. an
        // account switch) during the window.
      }
    }),
  );
}

/// Shows an undo toast for a deferred archive/move [mutation]: the mutation is
/// held for [window], then committed for real (restoring + surfacing the error
/// if the commit fails) unless the user taps Undo first.
void showUndoableMutationSnackBar(
  ScaffoldMessengerState messenger, {
  required String message,
  required PendingThreadMutation mutation,
  required Duration window,
}) {
  showUndoSnackBar(
    messenger,
    message: message,
    window: window,
    onUndo: mutation.undo,
    onExpire: () async {
      final error = await mutation.commit();
      if (error != null && messenger.mounted) {
        showAutoDismissSnackBar(messenger, message: error);
      }
    },
  );
}
