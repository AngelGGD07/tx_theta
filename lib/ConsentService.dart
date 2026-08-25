import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

/// Servicio mínimo para el consentimiento informado del piloto.
/// No utiliza Analytics. No realiza navegación.
class ConsentService {
  static const String collectionName = 'pilot_consents';
  static const String currentConsentVersion = 'pilot_2026_01';
  static const String currentAppVersion = '1.0.0+1';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _consents =>
      _db.collection(collectionName);

  /// Emite el documento de consentimiento asociado al userId.
  /// Si no existe, emite un snapshot sin datos (exists == false).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConsent(String userId) {
    return _consents.doc(userId).snapshots();
  }

  /// Graba o sobrescribe el consentimiento con la versión actual.
  Future<void> acceptConsent({required String userId}) async {
    final locale =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    await _consents.doc(userId).set({
      'userId': userId,
      'consentVersion': currentConsentVersion,
      'appVersion': currentAppVersion,
      'accepted': true,
      'acceptedAt': FieldValue.serverTimestamp(),
      'withdrawnAt': null,
      'locale': locale,
    }, SetOptions(merge: false));
  }

  /// Determina si el snapshot contiene un consentimiento vigente.
  bool hasValidConsent(DocumentSnapshot<Map<String, dynamic>>? snapshot) {
    if (snapshot == null || !snapshot.exists) return false;
    final data = snapshot.data();
    if (data == null) return false;
    return data['accepted'] == true &&
        data['consentVersion'] == currentConsentVersion;
  }
}