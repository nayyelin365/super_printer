import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Best-effort check before a Firestore call — returns false only when the
/// device genuinely has no network interface up. Never throws: if the
/// check itself fails (e.g. platform channel not ready right after adding
/// the plugin), it fails open (assumes connected) so a broken check never
/// blocks an otherwise-working save.
Future<bool> hasNetworkConnection() async {
  try {
    final result = await Connectivity().checkConnectivity();
    return result.any((r) => r != ConnectivityResult.none);
  } catch (_) {
    return true;
  }
}

/// One line, safe to show directly in a SnackBar — recognizes the
/// `FirebaseException(unavailable)` that Firestore throws when it can't
/// reach the server (dropped connection, TLS handshake failure, no
/// internet), and falls back to a generic message otherwise.
String networkAwareErrorMessage(Object error) {
  if (error is FirebaseException && error.code == 'unavailable') {
    return 'Network error. Please check your internet connection and try again.';
  }
  return 'Something went wrong: $error';
}
