import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Servicio mínimo para el consentimiento informado del piloto.
/// No utiliza Analytics. No realiza navegación.
class ConsentService {
  static const String collectionName = 'pilot_consents';
  static const String currentConsentVersion = 'pilot_2026_01';
  static const String currentAppVersion = '1.0.0+2';

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _consents =>
      _db.collection(collectionName);

  /// Emite el documento de consentimiento asociado al userId.
  /// Si no existe, emite un snapshot sin datos (exists == false).
  Stream<DocumentSnapshot<Map<String, dynamic>>> watchConsent(String userId) {
    return _consents.doc(userId).snapshots();
  }

  /// Comprueba si Firestore es accesible desde el servidor.
  /// No escribe datos.
  Future<bool> checkServerAccess(String userId) async {
    try {
      await _consents
          .doc(userId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 4));
      return true;
    } catch (e) {
      debugPrint('Consent server check error: ${e.runtimeType}');
      return false;
    }
  }

  /// Graba o sobrescribe el consentimiento con la versión actual.
  /// Utiliza una transacción para garantizar que falle sin conexión
  /// y no deje una escritura offline pendiente.
  Future<void> acceptConsent({required String userId}) async {
    final locale =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;

    final consentRef = _consents.doc(userId);

    await _db.runTransaction((transaction) async {
      await transaction.get(consentRef);

      transaction.set(
        consentRef,
        {
          'userId': userId,
          'consentVersion': currentConsentVersion,
          'appVersion': currentAppVersion,
          'accepted': true,
          'acceptedAt': FieldValue.serverTimestamp(),
          'withdrawnAt': null,
          'locale': locale,
        },
        SetOptions(merge: false),
      );
    });
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