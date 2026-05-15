import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_navigation.dart';

class CadastroMercadoPage extends StatefulWidget {
  const CadastroMercadoPage({super.key});

  @override
  State<CadastroMercadoPage> createState() =>
      _CadastroMercadoPageState();
}

class _CadastroMercadoPageState
    extends State<CadastroMercadoPage> {

  final nomeController = TextEditingController();
  final enderecoController = TextEditingController();
  final cidadeController = TextEditingController();

  bool carregando = false;

  Future<void> salvarMercado() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuário não logado'),
        ),
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('mercados')
          .doc(usuario.uid)
          .set({
        'nome': nomeController.text.trim(),
        'endereco': enderecoController.text.trim(),
        'cidade': cidadeController.text.trim(),
        'uidDono': usuario.uid,
        'emailDono': usuario.email,
        'dataCriacao': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mercado salvo com sucesso'),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const AppNavigation(),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro: $e'),
        ),
      );
    }

    setState(() {
      carregando = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Mercado'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            TextField(
              controller: nomeController,
              decoration: const InputDecoration(
                labelText: 'Nome do mercado',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: enderecoController,
              decoration: const InputDecoration(
                labelText: 'Endereço',
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: cidadeController,
              decoration: const InputDecoration(
                labelText: 'Cidade',
              ),
            ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: carregando
                    ? null
                    : salvarMercado,
                child: carregando
                    ? const CircularProgressIndicator()
                    : const Text(
                  'Salvar Mercado',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}