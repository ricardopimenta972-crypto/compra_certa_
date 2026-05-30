import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_navigation.dart';
import '../pdv/cadastro_mercado_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController senhaController = TextEditingController();

  bool carregando = false;
  bool modoCriarConta = false;

  @override
  void initState() {
    super.initState();
    _carregarUltimoEmail();
  }

  Future<void> _carregarUltimoEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final ultimoEmail = prefs.getString('ultimo_email_login') ?? '';

    if (!mounted) return;

    setState(() {
      emailController.text = ultimoEmail;
    });
  }

  Future<void> _salvarUltimoEmail() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ultimo_email_login', emailController.text.trim());
  }

  bool _camposValidos() {
    final email = emailController.text.trim();
    final senha = senhaController.text.trim();

    if (email.isEmpty || senha.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preencha e-mail e senha.')));
      return false;
    }

    if (!email.contains('@')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Digite um e-mail válido.')));
      return false;
    }

    if (senha.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A senha deve ter pelo menos 6 caracteres.'),
        ),
      );
      return false;
    }

    return true;
  }

  Future<void> fazerLogin() async {
    if (!_camposValidos()) return;

    try {
      setState(() {
        carregando = true;
      });

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      await _salvarUltimoEmail();

      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) return;

      final mercadoDoc = await FirebaseFirestore.instance
          .collection('mercados')
          .doc(usuario.uid)
          .get();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login realizado com sucesso!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => mercadoDoc.exists
              ? const AppNavigation()
              : const CadastroMercadoPage(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao fazer login';

      if (e.code == 'user-not-found') {
        mensagem = 'Usuário não encontrado';
      } else if (e.code == 'wrong-password') {
        mensagem = 'Senha incorreta';
      } else if (e.code == 'invalid-email') {
        mensagem = 'E-mail inválido';
      } else if (e.code == 'invalid-credential') {
        mensagem = 'E-mail ou senha incorretos';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  Future<void> criarConta() async {
    if (!_camposValidos()) return;

    try {
      setState(() {
        carregando = true;
      });

      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: senhaController.text.trim(),
      );

      await _salvarUltimoEmail();

      final usuario = FirebaseAuth.instance.currentUser;

      if (usuario == null) {
        throw FirebaseAuthException(
          code: 'usuario-null',
          message: 'Usuário não foi criado corretamente.',
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conta criada com sucesso!')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const CadastroMercadoPage()),
      );
    } on FirebaseAuthException catch (e) {
      String mensagem = 'Erro ao criar conta';

      if (e.code == 'weak-password') {
        mensagem = 'Senha muito fraca';
      } else if (e.code == 'email-already-in-use') {
        mensagem = 'Este e-mail já está cadastrado. Use Entrar.';
      } else if (e.code == 'invalid-email') {
        mensagem = 'E-mail inválido';
      } else if (e.code == 'usuario-null') {
        mensagem = 'Usuário não foi criado corretamente';
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(mensagem)));
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    senhaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final titulo = modoCriarConta
        ? 'Criar conta de mercado'
        : 'Entrar como mercado';

    final subtitulo = modoCriarConta
        ? 'Crie seu acesso para cadastrar seu mercado no Compra Certa.'
        : 'Acesse o painel para publicar e gerenciar ofertas.';

    return Scaffold(
      appBar: AppBar(title: Text(titulo)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),

            Icon(
              modoCriarConta ? Icons.storefront : Icons.store,
              size: 56,
              color: Colors.green,
            ),

            const SizedBox(height: 16),

            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),

            const SizedBox(height: 8),

            Text(
              subtitulo,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
            ),

            const SizedBox(height: 28),

            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'E-mail',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: senhaController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Senha',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 22),

            ElevatedButton(
              onPressed: carregando
                  ? null
                  : modoCriarConta
                  ? criarConta
                  : fazerLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: carregando
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(modoCriarConta ? 'Criar conta' : 'Entrar'),
            ),

            const SizedBox(height: 18),

            TextButton(
              onPressed: carregando
                  ? null
                  : () {
                      setState(() {
                        modoCriarConta = !modoCriarConta;
                      });
                    },
              child: Text(
                modoCriarConta
                    ? 'Já tenho conta. Entrar'
                    : 'Ainda não tenho conta. Criar conta de mercado',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
