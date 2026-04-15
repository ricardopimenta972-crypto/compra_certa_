import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const CompraCertaApp());
}

class CompraCertaApp extends StatelessWidget {
  const CompraCertaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Compra Certa',
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
   List<Map<String, dynamic>> _produtos = [];
  void _salvarProdutos() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> listaJson =
    _produtos.map((item) => jsonEncode(item)).toList();

    prefs.setStringList('produtos', listaJson);
  }

  void _carregarProdutos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? listaSalva = prefs.getStringList('produtos');

    if (listaSalva != null) {
      setState(() {
        _produtos = listaSalva
            .map((item) => jsonDecode(item) as Map<String, dynamic>)
            .toList();
      });
    }
  }

  void _adicionarProduto() {
    if (_controller.text.isNotEmpty) {
      setState(() {
        _produtos.add({
          'nome': _controller.text,
          'comprado': false,
        });
        _controller.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Compra Certa'),
        centerTitle: true,
        backgroundColor: Colors.green,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // CAMPO DE TEXTO
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 8,
                  ),
                ],
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      _produtos.add({
                        'nome': value,
                        'comprado': false,
                      });
                    });
                    _controller.clear();
                  }
                },
                decoration: const InputDecoration(
                  hintText: 'Digite um produto...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(16),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // LISTA
            Expanded(
              child: ListView.builder(
                itemCount: _produtos.length,
                itemBuilder: (context, index) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    child: ListTile(
                      leading: Checkbox(
                        value: _produtos[index]['comprado'],
                        onChanged: (value) {
                          setState(() {
                            _produtos[index]['comprado'] = value!;
                          });
                        },
                      ),
                      title: Text(
                        _produtos[index]['nome'],
                        style: TextStyle(
                          fontSize: 16,
                          decoration: _produtos[index]['comprado']
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          setState(() {
                            _produtos.removeAt(index);
                          });
                        },
                      ),
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
