import 'package:flutter/material.dart';
import 'package:in_app_update/in_app_update.dart';

class AtualizacaoService {
  static Future<void> verificarAtualizacao(BuildContext context) async {
    try {
      final info = await InAppUpdate.checkForUpdate();

      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
        } else if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
      }
    } catch (e) {
      debugPrint('Erro ao verificar atualização: $e');
    }
  }
}