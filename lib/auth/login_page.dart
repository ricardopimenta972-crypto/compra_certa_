import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_navigation.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool carregando = false;

  Future<void> fazerLogin() async {
    try {
      setState(() {
        carregando = true;
      });

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login realizado com sucesso!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppNavigation()),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao fazer login';

      if (e.code == 'user-not-found') {
        mensagem = 'Usuário não encontrado';
      }

      if (e.code == 'wrong-password') {
        mensagem = 'Senha incorreta';
      }

      if (e.code == 'invalid-email') {
        mensagem = 'E-mail inválido';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      setState(() {
        carregando = false;
      });
    }
  }

  Future<void> criarConta() async {
    try {
      setState(() {
        carregando = true;
      });

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso!')),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao criar conta';

      if (e.code == 'weak-password') {
        mensagem = 'Senha muito fraca';
      }

      if (e.code == 'email-already-in-use') {
        mensagem = 'Este e-mail já está cadastrado';
      }

      if (e.code == 'invalid-email') {
        mensagem = 'E-mail inválido';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      setState(() {
        carregando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login Compra Certa')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'E-mail'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: senhaController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Senha'),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: carregando ? null : fazerLogin,
              child: const Text('Entrar'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: carregando ? null : criarConta,
              child: const Text('Criar conta'),
            ),
          ],
        ),
      ),
    );
  }
}
