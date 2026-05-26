import 'package:flutter/material.dart';
import 'termo_responsabilidade_pdv.dart';

class TermoResponsabilidadePdvPage extends StatelessWidget {
  const TermoResponsabilidadePdvPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Termo de Responsabilidade')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(18),
        child: Text(
          termoResponsabilidadePdv,
          style: TextStyle(fontSize: 15, height: 1.45),
        ),
      ),
    );
  }
}
