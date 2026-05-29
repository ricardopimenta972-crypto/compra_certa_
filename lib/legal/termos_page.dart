import 'package:flutter/material.dart';

import 'termo_uso_cliente_page.dart';
import 'termo_responsabilidade_pdv_page.dart';

class TermosPage extends StatelessWidget {
  const TermosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos e políticas'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text(
              'Aqui você pode consultar os termos de uso do Compra Certa a qualquer momento.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Termos do cliente'),
                subtitle: const Text(
                  'Regras para quem visualiza ofertas no app.',
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermoUsoClientePage(),
                    ),
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.storefront_outlined),
                title: const Text('Termos do PDV'),
                subtitle: const Text('Regras para mercados e pontos de venda.'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const TermoResponsabilidadePdvPage(),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
