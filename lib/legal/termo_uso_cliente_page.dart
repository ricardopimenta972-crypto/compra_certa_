import 'package:flutter/material.dart';

import 'termo_uso_cliente.dart';

class TermoUsoClientePage extends StatelessWidget {
  const TermoUsoClientePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Termos de Uso do Cliente'),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Text(
          termoUsoCliente,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}