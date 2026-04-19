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
      theme: ThemeData(
        primarySwatch: Colors.green,
      ),
      home: const HomePage(),
    );
  }
}

class Produto {
  String nome;
  String preco;
  bool comprado;

  Produto({
    required this.nome,
    required this.preco,
    this.comprado = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'preco': preco,
      'comprado': comprado,
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      nome: map['nome'],
      preco: map['preco'],
      comprado: map['comprado'] ?? false,
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
  final TextEditingController _precoController = TextEditingController();

  List<Produto> _produtos = [];

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
  }

  void _salvarProdutos() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> listaJson =
    _produtos.map((item) => jsonEncode(item.toMap())).toList();

    await prefs.setStringList('produtos', listaJson);
  }

  void _carregarProdutos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? listaSalva = prefs.getStringList('produtos');

    if (listaSalva != null) {
      setState(() {
        _produtos = listaSalva
            .map((item) => Produto.fromMap(jsonDecode(item)))
            .toList();
      });
    }
  }

  void _adicionarProduto() {
    if (_controller.text.isNotEmpty && _precoController.text.isNotEmpty) {
      setState(() {
        _produtos.add(
          Produto(
            nome: _controller.text,
            preco: _precoController.text,
          ),
        );
        _controller.clear();
        _precoController.clear();
      });
      _salvarProdutos();
    }
  }

  void _removerProduto(int index) {
    setState(() {
      _produtos.removeAt(index);
    });
    _salvarProdutos();
  }

  void _toggleProduto(int index) {
    setState(() {
      _produtos[index].comprado = !_produtos[index].comprado;
    });
    _salvarProdutos();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],

      appBar: AppBar(
        title: const Text(
          'Compra Certa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Colors.green,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: InputDecoration(
                          hintText: 'Digite um produto...',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _precoController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          hintText: 'R\$',
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: _adicionarProduto,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Adicionar Produto',
                    style: TextStyle(color: Colors.green),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: _produtos.isEmpty
                ? const Center(
              child: Text(
                'Nenhum produto ainda',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _produtos.length,
              itemBuilder: (context, index) {
                final produto = _produtos[index];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _toggleProduto(index),
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: produto.comprado
                                ? Colors.green
                                : Colors.transparent,
                            border: Border.all(color: Colors.green),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: produto.comprado
                              ? const Icon(
                            Icons.check,
                            size: 18,
                            color: Colors.white,
                          )
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              produto.nome,
                              style: TextStyle(
                                fontSize: 16,
                                decoration: produto.comprado
                                    ? TextDecoration.lineThrough
                                    : TextDecoration.none,
                                color: produto.comprado
                                    ? Colors.grey
                                    : Colors.black,
                              ),
                            ),
                            Text(
                              'R\$ ${produto.preco}',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      GestureDetector(
                        onTap: () => _removerProduto(index),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}