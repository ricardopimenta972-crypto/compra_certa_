import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class NotificacaoService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  static Future<void> inicializar() async {
    await _pedirPermissao();
    await _salvarTokenFcm();
    _ouvirAtualizacaoToken();
  }

  static Future<void> _pedirPermissao() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
  }

  static Future<void> _salvarTokenFcm() async {
    final token = await _messaging.getToken();
    final user = FirebaseAuth.instance.currentUser;

    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('tokens_notificacao')
        .doc(token)
        .set({
      'token': token,
      'uidUsuario': user?.uid,
      'emailUsuario': user?.email,
      'notificacoesAtivas': true,
      'tipo': user == null ? 'consumidor' : 'pdv_ou_consumidor',
      'plataforma': Platform.operatingSystem,
      'cidade': null,
      'latitude': null,
      'longitude': null,
      'raioKm': 5,
      'criadoEm': FieldValue.serverTimestamp(),
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static void _ouvirAtualizacaoToken() {
    _messaging.onTokenRefresh.listen((novoToken) async {
      final user = FirebaseAuth.instance.currentUser;

      await FirebaseFirestore.instance
          .collection('tokens_notificacao')
          .doc(novoToken)
          .set({
        'token': novoToken,
        'uidUsuario': user?.uid,
        'emailUsuario': user?.email,
        'notificacoesAtivas': true,
        'tipo': user == null ? 'consumidor' : 'pdv_ou_consumidor',
        'plataforma': Platform.operatingSystem,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  static Future<void> atualizarLocalizacaoConsumidor({
    required String cidade,
    required double latitude,
    required double longitude,
    double raioKm = 5,
  }) async {
    final token = await _messaging.getToken();

    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('tokens_notificacao')
        .doc(token)
        .set({
      'cidade': cidade,
      'latitude': latitude,
      'longitude': longitude,
      'raioKm': raioKm,
      'notificacoesAtivas': true,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static Future<void> alterarNotificacoes(bool ativo) async {
    final token = await _messaging.getToken();

    if (token == null) return;

    await FirebaseFirestore.instance
        .collection('tokens_notificacao')
        .doc(token)
        .set({
      'notificacoesAtivas': ativo,
      'atualizadoEm': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}