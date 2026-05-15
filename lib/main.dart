import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'produt.dart';
import 'ofertas_page.dart';
import 'app_navigation.dart';
import 'mercado.dart';
import 'selecionar_localizacao_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth/login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(const CompraCertaApp());
}

class CompraCertaApp extends StatelessWidget {
  const CompraCertaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {'/auth-pdv': (context) => const LoginPage()},
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
      title: 'Compra Certa',
      theme: ThemeData(
        primarySwatch: Colors.green,
        scaffoldBackgroundColor: Colors.grey[100],
      ),
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
  final TextEditingController _mercadoController = TextEditingController();
  final TextEditingController _imagemController = TextEditingController();
  final TextEditingController _buscaController = TextEditingController();
  final TextEditingController _nomeMercadoController = TextEditingController();
  final TextEditingController _enderecoMercadoController =
      TextEditingController();
  final TextEditingController _logoMercadoController = TextEditingController();
  final TextEditingController _telefoneMercadoController =
      TextEditingController();
  final TextEditingController _latitudeMercadoController =
      TextEditingController();
  final TextEditingController _longitudeMercadoController =
      TextEditingController();

  final List<String> _categorias = [
    'Geral',
    'Alimentação',
    'Bebidas',
    'Carnes',
    'Hortifruti',
    'Padaria',
    'Higiene',
    'Limpeza',
    'Congelados',
    'Laticínios',
    'Churrasco',
    'Final de Semana',
    'Festa',
  ];

  final List<String> _unidadesMedida = [
    'un',
    'kg',
    'g',
    '100g',
    '500g',
    'litro',
    'ml',
    'pacote',
    'caixa',
    'bandeja',
    'dúzia',
  ];

  List<Produto> _produtos = [];
  String _busca = '';
  String _categoriaSelecionada = 'Geral';
  String _unidadeSelecionada = 'un';
  String _categoriaFiltro = 'Todos';
  bool _mostrarBusca = false;
  bool _ehOferta = true;
  bool _enquantoDurar = false;
  int _duracaoSelecionada = 3;
  bool _mostrarFormularioCadastro = false;
  int _etapaCadastro = 1;
  bool _ehRelampago = false;
  TimeOfDay? _horaInicioRelampago;
  TimeOfDay? _horaFimRelampago;
  Mercado? _mercadoAtual;
  List<Mercado> _mercados = [];

  Future<String?> escolherImagemDoDispositivo() async {
    final ImagePicker picker = ImagePicker();

    final XFile? imagem = await showModalBottomSheet<XFile?>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Selecionar da galeria'),
                  onTap: () async {
                    final XFile? foto = await picker.pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 75,
                    );

                    Navigator.pop(context, foto);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Tirar foto'),
                  onTap: () async {
                    final XFile? foto = await picker.pickImage(
                      source: ImageSource.camera,
                      imageQuality: 75,
                    );

                    Navigator.pop(context, foto);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    return imagem?.path;
  }

  @override
  void initState() {
    super.initState();
    _carregarProdutos();
    _carregarMercado();
  }

  @override
  void dispose() {
    _controller.dispose();
    _precoController.dispose();
    _mercadoController.dispose();
    _imagemController.dispose();
    _buscaController.dispose();
    _nomeMercadoController.dispose();
    _enderecoMercadoController.dispose();
    _logoMercadoController.dispose();
    _telefoneMercadoController.dispose();
    _latitudeMercadoController.dispose();
    _longitudeMercadoController.dispose();
    super.dispose();
  }

  List<String> get _categoriasFiltro {
    return ['Todos', ..._categorias];
  }

  InputDecoration _input(String? hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  String _formatarPreco(double preco) {
    return preco.toStringAsFixed(2).replaceAll('.', ',');
  }

  Color _corStatusOferta(String status) {
    if (status == 'pausada') return Colors.orange;
    if (status == 'encerrada') return Colors.red;
    return Colors.green;
  }

  String _textoStatusOferta(String status) {
    if (status == 'pausada') return 'Pausada';
    if (status == 'encerrada') return 'Encerrada';
    return 'Ativa';
  }

  String _normalizarNome(String nome) {
    return nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  double _menorPrecoDoGrupo(String nomeProduto) {
    final nomeNormalizado = _normalizarNome(nomeProduto);

    final grupo = _produtos.where((p) {
      return _normalizarNome(p.nome) == nomeNormalizado;
    }).toList();

    if (grupo.isEmpty) return 0;

    return grupo.map((p) => p.preco).reduce((a, b) => a < b ? a : b);
  }

  bool _ehMaisBaratoDoGrupo(Produto produto) {
    return produto.preco == _menorPrecoDoGrupo(produto.nome);
  }

  void _ordenarProdutos() {
    _produtos.sort((a, b) {
      final aMaisBarato = _ehMaisBaratoDoGrupo(a);
      final bMaisBarato = _ehMaisBaratoDoGrupo(b);

      if (aMaisBarato && !bMaisBarato) return -1;
      if (!aMaisBarato && bMaisBarato) return 1;

      final menorA = _menorPrecoDoGrupo(a.nome);
      final menorB = _menorPrecoDoGrupo(b.nome);

      final compararGrupo = menorA.compareTo(menorB);
      if (compararGrupo != 0) return compararGrupo;

      final compararNome = _normalizarNome(
        a.nome,
      ).compareTo(_normalizarNome(b.nome));
      if (compararNome != 0) return compararNome;

      return a.preco.compareTo(b.preco);
    });
  }

  void _mostrarMensagem(String texto, {Color? corFundo}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto),
        backgroundColor: corFundo ?? Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(12),
      ),
    );
  }

  void _salvarProdutos() async {
    final prefs = await SharedPreferences.getInstance();
    final listaJson = _produtos
        .map((item) => jsonEncode(item.toMap()))
        .toList();
    await prefs.setStringList('produtos', listaJson);
  }

  void _carregarMercado() async {
    final prefs = await SharedPreferences.getInstance();

    final mercadoJson = prefs.getString('mercado_atual');
    final listaMercadosJson = prefs.getStringList('mercados');

    final mercadosCarregados =
        listaMercadosJson
            ?.map((item) => Mercado.fromMap(jsonDecode(item)))
            .toList() ??
        [];

    setState(() {
      _mercados = mercadosCarregados;

      if (mercadoJson != null) {
        _mercadoAtual = Mercado.fromMap(jsonDecode(mercadoJson));
      } else if (_mercados.isNotEmpty) {
        _mercadoAtual = _mercados.first;
      }
    });
  }

  void _salvarMercado(Mercado mercado) async {
    final prefs = await SharedPreferences.getInstance();

    final indiceExistente = _mercados.indexWhere(
      (item) =>
          item.nome.trim().toLowerCase() == mercado.nome.trim().toLowerCase(),
    );

    if (indiceExistente >= 0) {
      _mercados[indiceExistente] = mercado;
    } else {
      _mercados.add(mercado);
    }

    await prefs.setStringList(
      'mercados',
      _mercados.map((item) => jsonEncode(item.toMap())).toList(),
    );

    await prefs.setString('mercado_atual', jsonEncode(mercado.toMap()));

    setState(() {
      _mercadoAtual = mercado;
    });

    _mostrarMensagem('Mercado salvo e selecionado com sucesso.');
  }

  void _carregarProdutos() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? listaSalva = prefs.getStringList('produtos');

    if (listaSalva != null) {
      setState(() {
        final agora = DateTime.now();

        _produtos = listaSalva
            .map((item) => Produto.fromMap(jsonDecode(item)))
            .where((produto) {
              // mantém se NÃO for oferta
              if (!produto.ehOferta) return true;

              if (produto.ehRelampago) {
                return produto.fimProgramado != null &&
                    produto.fimProgramado!.isAfter(agora);
              }

              // mantém se for "enquanto durar"
              if (produto.enquantoDurar) return true;

              // mantém se ainda não venceu
              if (produto.validade != null &&
                  produto.validade!.isAfter(agora)) {
                return true;
              }

              // se chegou aqui, remove
              return false;
            })
            .toList();

        _ordenarProdutos();
      });
    }
  }

  void _adicionarProduto() {
    final nome = _controller.text.trim();
    final precoTexto = _precoController.text.trim();
    final mercadoTexto = _mercadoController.text.trim();
    final imagemTexto = _imagemController.text.trim();
    const quantidadeMedidaTexto = '1';

    DateTime? validade;
    DateTime? inicioRelampago;
    DateTime? fimRelampago;
    final agora = DateTime.now();

    if (_ehRelampago) {
      if (_horaInicioRelampago == null || _horaFimRelampago == null) {
        _mostrarMensagem(
          'Escolha o horário de início e fim da oferta relâmpago.',
          corFundo: Colors.red,
        );
        return;
      }

      final agora = DateTime.now();

      inicioRelampago = DateTime(
        agora.year,
        agora.month,
        agora.day,
        _horaInicioRelampago!.hour,
        _horaInicioRelampago!.minute,
      );

      fimRelampago = DateTime(
        agora.year,
        agora.month,
        agora.day,
        _horaFimRelampago!.hour,
        _horaFimRelampago!.minute,
      );

      fimRelampago = DateTime(
        agora.year,
        agora.month,
        agora.day,
        _horaFimRelampago!.hour,
        _horaFimRelampago!.minute,
      );

      if (!fimRelampago.isAfter(inicioRelampago)) {
        _mostrarMensagem(
          'O horário final precisa ser depois do horário inicial.',
          corFundo: Colors.red,
        );
        return;
      }
    }

    if (!_enquantoDurar && !_ehRelampago) {
      validade = agora.add(Duration(days: _duracaoSelecionada));
    }

    if (nome.isEmpty || precoTexto.isEmpty) {
      _mostrarMensagem('Preencha nome e preço!', corFundo: Colors.red);
      return;
    }

    final preco = double.tryParse(precoTexto.replaceAll(',', '.'));

    if (preco == null) {
      _mostrarMensagem('Preço inválido!', corFundo: Colors.red);
      return;
    }

    setState(() {
      _produtos.add(
        Produto(
          nome: nome,
          preco: preco,
          comprado: false,
          categoria: _categoriaSelecionada,
          mercado: _mercadoAtual?.nome ?? 'Sem mercado',
          endereco: _mercadoAtual?.endereco ?? 'Endereço não informado',
          latitude: _mercadoAtual?.latitude,
          longitude: _mercadoAtual?.longitude,
          ehOferta: _ehOferta,
          enquantoDurar: _enquantoDurar,
          validade: validade,
          imagemUrl: imagemTexto,
          logoMercadoUrl: _mercadoAtual?.logoUrl ?? '',

          unidadeMedida: _unidadeSelecionada,
          ehRelampago: _ehRelampago,
          inicioProgramado: inicioRelampago,
          fimProgramado: fimRelampago,
        ),
      );

      _ordenarProdutos();
    });

    _controller.clear();
    _precoController.clear();
    _mercadoController.clear();
    _imagemController.clear();
    _unidadeSelecionada = 'un';
    setState(() {
      _ehOferta = true;
      _enquantoDurar = false;
      _duracaoSelecionada = 3;
      _ehRelampago = false;
      _horaInicioRelampago = null;
      _horaFimRelampago = null;
      _mostrarFormularioCadastro = false;
    });

    _salvarProdutos();
    FocusScope.of(context).unfocus();

    _mostrarMensagem('Produto adicionado com sucesso.');
  }

  void _toggleProduto(int index) {
    if (_mercadoAtual == null) {
      _mostrarMensagem(
        'Cadastre o mercado antes de publicar ofertas.',
        corFundo: Colors.red,
      );
      return;
    }
    setState(() {
      _produtos[index].comprado = !_produtos[index].comprado;
    });
    _salvarProdutos();
  }

  void _removerProduto(int index) {
    final nomeRemovido = _produtos[index].nome;

    setState(() {
      _produtos.removeAt(index);
      _ordenarProdutos();
    });

    _salvarProdutos();
    _mostrarMensagem(
      '"$nomeRemovido" removido da lista.',
      corFundo: Colors.red,
    );
  }

  void _limparBusca() {
    _buscaController.clear();
    setState(() {
      _busca = '';
    });
  }

  void _alternarBusca() {
    setState(() {
      _mostrarBusca = !_mostrarBusca;
      if (!_mostrarBusca) {
        _limparBusca();
      }
    });
  }

  Future<void> _confirmarLimparLista() async {
    if (_produtos.isEmpty) {
      _mostrarMensagem('A lista já está vazia.', corFundo: Colors.orange);
      return;
    }

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Limpar lista'),
          content: const Text(
            'Tem certeza que deseja apagar todos os produtos da lista?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),

            const SizedBox(height: 10),

            if (_ehOferta) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Validade da oferta',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('24h'),
                        selected: _duracaoSelecionada == 1 && !_enquantoDurar,
                        onSelected: (_) {
                          setState(() {
                            _duracaoSelecionada = 1;
                            _enquantoDurar = false;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('3 dias'),
                        selected: _duracaoSelecionada == 3 && !_enquantoDurar,
                        onSelected: (_) {
                          setState(() {
                            _duracaoSelecionada = 3;
                            _enquantoDurar = false;
                          });
                        },
                      ),
                      ChoiceChip(
                        label: const Text('7 dias'),
                        selected: _duracaoSelecionada == 7 && !_enquantoDurar,
                        onSelected: (_) {
                          setState(() {
                            _duracaoSelecionada = 7;
                            _enquantoDurar = false;
                          });
                        },
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: _enquantoDurar,

                        activeColor: Colors.white,
                        checkColor: Colors.green,
                        onChanged: (valor) {
                          setState(() {
                            _enquantoDurar = valor ?? false;
                          });
                        },
                      ),

                      if (_ehOferta) ...[
                        const SizedBox(height: 10),

                        Row(
                          children: [
                            Checkbox(
                              value: _ehRelampago,
                              activeColor: Colors.white,
                              checkColor: Colors.green,
                              onChanged: (valor) {
                                setState(() {
                                  _ehRelampago = valor ?? false;
                                });
                              },
                            ),
                            const Text(
                              'Oferta relâmpago',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),

                        if (_ehRelampago) ...[
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Checkbox(
                                value: _ehRelampago,
                                activeColor: Colors.white,
                                checkColor: Colors.green,
                                onChanged: (valor) {
                                  setState(() {
                                    _ehRelampago = valor ?? false;
                                  });
                                },
                              ),
                              const Text(
                                '⚡ Oferta relâmpago',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          if (_ehRelampago) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final horario = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );

                                      if (horario == null) return;

                                      setState(() {
                                        _horaInicioRelampago = horario;
                                      });
                                    },
                                    child: Text(
                                      _horaInicioRelampago == null
                                          ? 'Início'
                                          : 'Início: ${_horaInicioRelampago!.format(context)}',
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () async {
                                      final horario = await showTimePicker(
                                        context: context,
                                        initialTime: TimeOfDay.now(),
                                      );

                                      if (horario == null) return;

                                      setState(() {
                                        _horaFimRelampago = horario;
                                      });
                                    },
                                    child: Text(
                                      _horaFimRelampago == null
                                          ? 'Fim'
                                          : 'Fim: ${_horaFimRelampago!.format(context)}',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                          ],

                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final horario = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );

                                    if (horario == null) return;

                                    setState(() {
                                      _horaInicioRelampago = horario;
                                    });
                                  },
                                  child: Text(
                                    _horaInicioRelampago == null
                                        ? 'Início'
                                        : 'Início: ${_horaInicioRelampago!.format(context)}',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () async {
                                    final horario = await showTimePicker(
                                      context: context,
                                      initialTime: TimeOfDay.now(),
                                    );

                                    if (horario == null) return;

                                    setState(() {
                                      _horaFimRelampago = horario;
                                    });
                                  },
                                  child: Text(
                                    _horaFimRelampago == null
                                        ? 'Fim'
                                        : 'Fim: ${_horaFimRelampago!.format(context)}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                        ],

                        Row(
                          children: [
                            Checkbox(
                              value: _enquantoDurar,
                              onChanged: (value) {
                                setState(() {
                                  _enquantoDurar = value!;
                                });
                              },
                            ),
                            const Text('Enquanto durar o estoque'),
                          ],
                        ),

                        if (!_enquantoDurar)
                          DropdownButton<int>(
                            value: _duracaoSelecionada,
                            onChanged: (value) {
                              setState(() {
                                _duracaoSelecionada = value!;
                              });
                            },
                            items: [1, 2, 3, 5, 7]
                                .map(
                                  (dias) => DropdownMenuItem(
                                    value: dias,
                                    child: Text('$dias dias'),
                                  ),
                                )
                                .toList(),
                          ),
                      ],

                      const Text(
                        'Enquanto durar o estoque',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],

            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apagar'),
            ),
          ],
        );
      },
    );

    if (confirmar == true) {
      setState(() {
        _produtos.clear();
        _categoriaFiltro = 'Todos';
      });

      _salvarProdutos();
      _mostrarMensagem('Lista apagada com sucesso.', corFundo: Colors.red);
    }
  }

  void _editarProduto(int index) {
    final nomeController = TextEditingController(text: _produtos[index].nome);
    final precoController = TextEditingController(
      text: _formatarPreco(_produtos[index].preco),
    );
    final mercadoController = TextEditingController(
      text: _produtos[index].mercado == 'Sem mercado'
          ? ''
          : _produtos[index].mercado,
    );

    String categoriaEditada = _produtos[index].categoria;

    if (!_categorias.contains(categoriaEditada)) {
      categoriaEditada = 'Geral';
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar produto'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nomeController,
                      decoration: const InputDecoration(
                        labelText: 'Nome do produto',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: precoController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(labelText: 'Preço'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: mercadoController,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Mercado',
                        hintText: 'Ex: Supermercado Brasil',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: categoriaEditada,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: _categorias.map((categoria) {
                        return DropdownMenuItem<String>(
                          value: categoria,
                          child: Text(categoria),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        if (valor == null) return;
                        setStateDialog(() {
                          categoriaEditada = valor;
                        });
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final novoNome = nomeController.text.trim();
                final novoPrecoTexto = precoController.text.trim();
                final novoMercadoTexto = mercadoController.text.trim();

                if (novoNome.isEmpty || novoPrecoTexto.isEmpty) {
                  _mostrarMensagem(
                    'Preencha nome e preço!',
                    corFundo: Colors.red,
                  );
                  return;
                }

                final novoPreco = double.tryParse(
                  novoPrecoTexto.replaceAll(',', '.'),
                );

                if (novoPreco == null) {
                  _mostrarMensagem('Preço inválido!', corFundo: Colors.red);
                  return;
                }

                setState(() {
                  _produtos[index].nome = novoNome;
                  _produtos[index].preco = novoPreco;
                  _produtos[index].categoria = categoriaEditada;
                  _produtos[index].mercado = novoMercadoTexto.isEmpty
                      ? 'Sem mercado'
                      : novoMercadoTexto;
                  _ordenarProdutos();
                });

                _salvarProdutos();
                Navigator.of(context).pop();
                _mostrarMensagem('Produto atualizado com sucesso.');
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  void _abrirGerenciadorMercados() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Mercados cadastrados'),
              content: SizedBox(
                width: double.maxFinite,
                child: _mercados.isEmpty
                    ? const Text('Nenhum mercado cadastrado ainda.')
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: _mercados.length,
                        separatorBuilder: (_, __) => const Divider(),
                        itemBuilder: (context, index) {
                          final mercado = _mercados[index];
                          final selecionado =
                              _mercadoAtual?.nome == mercado.nome;

                          return ListTile(
                            leading: Icon(
                              selecionado ? Icons.check_circle : Icons.store,
                              color: selecionado ? Colors.green : Colors.grey,
                            ),
                            title: Text(
                              mercado.nome,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              mercado.endereco.isEmpty
                                  ? 'Sem endereço informado'
                                  : mercado.endereco,
                            ),
                            onTap: () async {
                              final prefs =
                                  await SharedPreferences.getInstance();

                              await prefs.setString(
                                'mercado_atual',
                                jsonEncode(mercado.toMap()),
                              );

                              setState(() {
                                _mercadoAtual = mercado;
                              });

                              Navigator.of(context).pop();

                              _mostrarMensagem(
                                'Mercado ativo: ${mercado.nome}',
                              );
                            },
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.blue,
                                  ),
                                  tooltip: 'Editar mercado',
                                  onPressed: () {
                                    Navigator.of(context).pop();

                                    setState(() {
                                      _mercadoAtual = mercado;
                                    });

                                    _abrirCadastroMercado();
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Excluir mercado',
                                  onPressed: () async {
                                    final confirmar = await showDialog<bool>(
                                      context: context,
                                      builder: (context) {
                                        return AlertDialog(
                                          title: const Text('Excluir mercado'),
                                          content: Text(
                                            'Deseja excluir "${mercado.nome}"?',
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(false),
                                              child: const Text('Cancelar'),
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red,
                                              ),
                                              onPressed: () => Navigator.of(
                                                context,
                                              ).pop(true),
                                              child: const Text('Excluir'),
                                            ),
                                          ],
                                        );
                                      },
                                    );

                                    if (confirmar != true) return;

                                    setState(() {
                                      _mercados.removeAt(index);

                                      if (_mercadoAtual?.nome == mercado.nome) {
                                        _mercadoAtual = _mercados.isNotEmpty
                                            ? _mercados.first
                                            : null;
                                      }
                                    });

                                    final prefs =
                                        await SharedPreferences.getInstance();

                                    await prefs.setStringList(
                                      'mercados',
                                      _mercados
                                          .map(
                                            (item) => jsonEncode(item.toMap()),
                                          )
                                          .toList(),
                                    );

                                    if (_mercadoAtual != null) {
                                      await prefs.setString(
                                        'mercado_atual',
                                        jsonEncode(_mercadoAtual!.toMap()),
                                      );
                                    } else {
                                      await prefs.remove('mercado_atual');
                                    }

                                    setStateDialog(() {});

                                    _mostrarMensagem(
                                      'Mercado excluído.',
                                      corFundo: Colors.red,
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Fechar'),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _abrirCadastroMercado();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Novo mercado'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _abrirCadastroMercado() {
    _nomeMercadoController.text = _mercadoAtual?.nome ?? '';
    _enderecoMercadoController.text = _mercadoAtual?.endereco ?? '';
    _logoMercadoController.text = _mercadoAtual?.logoUrl ?? '';
    _telefoneMercadoController.text = _mercadoAtual?.telefone ?? '';
    _latitudeMercadoController.text = _mercadoAtual?.latitude?.toString() ?? '';
    _longitudeMercadoController.text =
        _mercadoAtual?.longitude?.toString() ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cadastro do mercado'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nomeMercadoController,
                  decoration: const InputDecoration(
                    labelText: 'Nome do mercado',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _enderecoMercadoController,
                  decoration: const InputDecoration(
                    labelText: 'Endereço do mercado',
                  ),
                ),
                const SizedBox(height: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final imagem = await escolherImagemDoDispositivo();

                        if (imagem != null) {
                          setState(() {
                            _logoMercadoController.text = imagem;
                          });
                        }
                      },

                      icon: const Icon(Icons.photo_camera),

                      label: const Text('Selecionar logo/fachada'),
                    ),

                    if (_logoMercadoController.text.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 8),
                        child: Text(
                          'Imagem selecionada com sucesso.',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _telefoneMercadoController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefone / WhatsApp',
                  ),
                ),
                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: () async {
                    final resultado = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SelecionarLocalizacaoPage(),
                      ),
                    );

                    if (resultado != null) {
                      _latitudeMercadoController.text = resultado.latitude
                          .toString();

                      _longitudeMercadoController.text = resultado.longitude
                          .toString();

                      _mostrarMensagem('Localização selecionada com sucesso.');
                    }
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Selecionar no mapa'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () {
                final nome = _nomeMercadoController.text.trim();
                final endereco = _enderecoMercadoController.text.trim();
                final logo = _logoMercadoController.text.trim();
                final telefone = _telefoneMercadoController.text.trim();
                final latitude = double.tryParse(
                  _latitudeMercadoController.text.trim().replaceAll(',', '.'),
                );

                final longitude = double.tryParse(
                  _longitudeMercadoController.text.trim().replaceAll(',', '.'),
                );

                if (nome.isEmpty || endereco.isEmpty) {
                  _mostrarMensagem(
                    'Preencha nome e endereço do mercado.',
                    corFundo: Colors.red,
                  );
                  return;
                }

                _salvarMercado(
                  Mercado(
                    nome: nome,
                    endereco: endereco,
                    logoUrl: logo,
                    telefone: telefone,
                    latitude: latitude,
                    longitude: longitude,
                  ),
                );

                Navigator.of(context).pop();
              },
              child: const Text('Salvar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMercadoAtivoCard() {
    if (_mercados.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: ElevatedButton.icon(
          onPressed: _abrirGerenciadorMercados,
          icon: const Icon(Icons.store),
          label: const Text('Cadastrar mercado'),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            const Icon(Icons.store, color: Colors.green),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _mercadoAtual?.nome,
                  isExpanded: true,
                  items: _mercados.map((mercado) {
                    return DropdownMenuItem<String>(
                      value: mercado.nome,
                      child: Text(
                        mercado.nome,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (nomeSelecionado) async {
                    if (nomeSelecionado == null) return;

                    final mercadoSelecionado = _mercados.firstWhere(
                      (mercado) => mercado.nome == nomeSelecionado,
                    );

                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString(
                      'mercado_atual',
                      jsonEncode(mercadoSelecionado.toMap()),
                    );

                    setState(() {
                      _mercadoAtual = mercadoSelecionado;
                    });

                    _mostrarMensagem(
                      'Mercado ativo: ${mercadoSelecionado.nome}',
                    );
                  },
                ),
              ),
            ),
            IconButton(
              onPressed: _abrirCadastroMercado,
              icon: const Icon(Icons.edit, color: Colors.green),
              tooltip: 'Editar/Cadastrar mercado',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCabecalhoSecao(String titulo) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Text(
        titulo,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.green,
        ),
      ),
    );
  }

  Widget _buildResumoPorCategoria() {
    final categoriasComProdutos = _categorias.where((categoria) {
      return _produtos.any((produto) => produto.categoria == categoria);
    }).toList();

    if (categoriasComProdutos.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade300,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resumo por categoria',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...categoriasComProdutos.map((categoria) {
              final totalCategoria = _produtos
                  .where((produto) => produto.categoria == categoria)
                  .fold<double>(0, (total, produto) => total + produto.preco);

              final quantidadeCategoria = _produtos
                  .where((produto) => produto.categoria == categoria)
                  .length;

              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('$categoria ($quantidadeCategoria)'),
                    Text(
                      'R\$ ${_formatarPreco(totalCategoria)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltroCategorias() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: SizedBox(
        height: 42,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _categoriasFiltro.length,
          separatorBuilder: (context, index) => const SizedBox(width: 8),
          itemBuilder: (context, index) {
            final categoria = _categoriasFiltro[index];
            final selecionada = categoria == _categoriaFiltro;

            return ChoiceChip(
              label: Text(categoria),
              selected: selecionada,
              selectedColor: Colors.green,
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: selecionada ? Colors.white : Colors.green,
                fontWeight: FontWeight.bold,
              ),
              side: BorderSide(
                color: selecionada ? Colors.green : Colors.green.shade200,
              ),
              onSelected: (_) {
                setState(() {
                  _categoriaFiltro = categoria;
                });
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildCardProduto(Produto produto, int indiceReal, int ordemAnimacao) {
    final maisBarato = _ehMaisBaratoDoGrupo(produto);

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${produto.nome}-${produto.preco}-${produto.mercado}-$indiceReal',
      ),
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 220 + (ordemAnimacao * 40)),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key('${produto.nome}-${produto.mercado}-$indiceReal'),
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          decoration: BoxDecoration(
            color: Colors.blue,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.edit, color: Colors.white),
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.startToEnd) {
            _editarProduto(indiceReal);
            return false;
          }

          final confirmar = await showDialog<bool>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('Excluir produto'),
                content: const Text('Deseja realmente excluir este produto?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Excluir'),
                  ),
                ],
              );
            },
          );

          return confirmar ?? false;
        },
        onDismissed: (direction) {
          if (direction == DismissDirection.endToStart) {
            _removerProduto(indiceReal);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: maisBarato ? Colors.green[50] : Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.shade300,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
            border: maisBarato
                ? Border.all(color: Colors.green.shade200, width: 1.2)
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
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
                        const SizedBox(height: 2),
                        Text(
                          produto.mercado,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blueGrey[700],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          produto.categoria,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'R\$ ${_formatarPreco(produto.preco)}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (produto.ehOferta) ...[
                          Text(
                            produto.enquantoDurar
                                ? 'Enquanto durar o estoque'
                                : produto.validade != null
                                ? 'Válido até ${produto.validade!.day.toString().padLeft(2, '0')}/${produto.validade!.month.toString().padLeft(2, '0')}'
                                : '',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final produtosFiltrados = _produtos.where((produto) {
      final textoBusca = _busca.toLowerCase();

      final bateBusca =
          produto.nome.toLowerCase().contains(textoBusca) ||
          produto.mercado.toLowerCase().contains(textoBusca);

      final bateCategoria =
          _categoriaFiltro == 'Todos' || produto.categoria == _categoriaFiltro;

      final agora = DateTime.now();

      if (produto.ehRelampago) {
        if (produto.inicioProgramado == null || produto.fimProgramado == null) {
          return false;
        }

        if (agora.isBefore(produto.inicioProgramado!) ||
            agora.isAfter(produto.fimProgramado!)) {
          return false;
        }
      }

      return bateBusca && bateCategoria;
    }).toList();

    final maisBaratos = produtosFiltrados.where(_ehMaisBaratoDoGrupo).toList();

    final outrosProdutos = produtosFiltrados
        .where((p) => !_ehMaisBaratoDoGrupo(p))
        .toList();

    final totalItens = _produtos.length;
    final itensPendentes = _produtos.where((p) => !p.comprado).length;
    final valorTotal = _produtos.fold<double>(
      0,
      (total, produto) => total + produto.preco,
    );

    int contadorAnimacao = 0;

    return Scaffold(
      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        title: const Text(
          'Compra Certa',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _abrirCadastroMercado,
            icon: const Icon(Icons.store),
            tooltip: 'Mercados cadastrados',
          ),
          IconButton(
            onPressed: _alternarBusca,
            icon: Icon(_mostrarBusca ? Icons.close : Icons.search),
            tooltip: _mostrarBusca ? 'Fechar busca' : 'Abrir busca',
          ),
          IconButton(
            onPressed: _confirmarLimparLista,
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Limpar lista',
          ),
        ],
      ),

      body: Column(
        children: [
          Column(
            children: [
              /// ===== ETAPA 1 =====
              if (_mostrarFormularioCadastro && _etapaCadastro == 1) ...[
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: _input('Digite um produto...'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    SizedBox(
                      width: 100,
                      child: TextField(
                        controller: _precoController,
                        keyboardType: TextInputType.number,
                        decoration: _input('R\$'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: _unidadeSelecionada,
                  decoration: _input('Unidade'),
                  items: _unidadesMedida.map((unidade) {
                    return DropdownMenuItem(
                      value: unidade,
                      child: Text(unidade),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _unidadeSelecionada = value!;
                    });
                  },
                ),

                const SizedBox(height: 10),

                DropdownButtonFormField<String>(
                  value: _categoriaSelecionada,
                  decoration: _input(null),
                  items: _categorias.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) => setState(() => _categoriaSelecionada = v!),
                ),

                const SizedBox(height: 10),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () async {
                        final caminhoImagem =
                            await escolherImagemDoDispositivo();

                        if (caminhoImagem != null) {
                          setState(() {
                            _imagemController.text = caminhoImagem;
                          });
                        }
                      },

                      icon: const Icon(Icons.add_photo_alternate),

                      label: const Text('Selecionar imagem da oferta'),
                    ),

                    if (_imagemController.text.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),

                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),

                          child: Image.file(
                            File(_imagemController.text),

                            height: 126,
                            width: 126,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 15),

                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _etapaCadastro = 2;
                    });
                  },
                  child: const Text('Próximo'),
                ),
              ],

              /// ===== ETAPA 2 =====
              if (_etapaCadastro == 2) ...[
                const SizedBox(height: 4),

                ...[
                  Row(
                    children: [
                      Checkbox(
                        value: _ehRelampago,
                        onChanged: (v) =>
                            setState(() => _ehRelampago = v ?? false),
                      ),
                      const Text(
                        '⚡ Oferta relâmpago',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  if (_ehRelampago)
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final h = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (h != null) {
                                setState(() => _horaInicioRelampago = h);
                              }
                            },
                            child: Text(
                              _horaInicioRelampago == null
                                  ? 'Início'
                                  : _horaInicioRelampago!.format(context),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final h = await showTimePicker(
                                context: context,
                                initialTime: TimeOfDay.now(),
                              );
                              if (h != null) {
                                setState(() => _horaFimRelampago = h);
                              }
                            },
                            child: Text(
                              _horaFimRelampago == null
                                  ? 'Fim'
                                  : _horaFimRelampago!.format(context),
                            ),
                          ),
                        ),
                      ],
                    ),

                  Row(
                    children: [
                      Checkbox(
                        value: _enquantoDurar,
                        onChanged: (v) =>
                            setState(() => _enquantoDurar = v ?? false),
                      ),
                      const Text(
                        'Enquanto durar o estoque',
                        style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),

                  if (!_enquantoDurar)
                    DropdownButtonFormField<int>(
                      value: _duracaoSelecionada,
                      decoration: _input(null),
                      items: const [
                        DropdownMenuItem(value: 1, child: Text('24 horas')),
                        DropdownMenuItem(value: 3, child: Text('3 dias')),
                        DropdownMenuItem(value: 7, child: Text('7 dias')),
                      ],
                      onChanged: (v) =>
                          setState(() => _duracaoSelecionada = v!),
                    ),
                ],

                const SizedBox(height: 15),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _etapaCadastro = 1;
                          });
                        },
                        child: const Text('Voltar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _adicionarProduto,
                        child: const Text('Finalizar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),

          _buildMercadoAtivoCard(),
          _buildFiltroCategorias(),
          if (_mostrarBusca)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
              child: TextField(
                controller: _buscaController,
                onChanged: (valor) {
                  setState(() {
                    _busca = valor;
                  });
                },
                decoration: InputDecoration(
                  hintText: 'Buscar produto ou mercado...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _busca.isNotEmpty
                      ? IconButton(
                          onPressed: _limparBusca,
                          icon: const Icon(Icons.clear),
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          Expanded(
            child: produtosFiltrados.isEmpty
                ? Center(
                    child: Text(
                      _produtos.isEmpty
                          ? 'Nenhum produto ainda'
                          : 'Nenhum produto encontrado',
                      style: const TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (maisBaratos.isNotEmpty) ...[
                        _buildCabecalhoSecao('Ofertas publicadas'),
                        ...maisBaratos.map((produto) {
                          final indiceReal = _produtos.indexOf(produto);
                          final widget = _buildCardProduto(
                            produto,
                            indiceReal,
                            contadorAnimacao,
                          );
                          contadorAnimacao++;
                          return widget;
                        }),
                      ],
                      if (outrosProdutos.isNotEmpty) ...[
                        _buildCabecalhoSecao('Oferta ativa'),
                        ...outrosProdutos.map((produto) {
                          final indiceReal = _produtos.indexOf(produto);
                          final widget = _buildCardProduto(
                            produto,
                            indiceReal,
                            contadorAnimacao,
                          );
                          contadorAnimacao++;
                          return widget;
                        }),
                      ],
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        onPressed: () {
          setState(() {
            _mostrarFormularioCadastro = !_mostrarFormularioCadastro;
            if (_mostrarFormularioCadastro) {
              _etapaCadastro = 1;
            }
          });
        },
        child: Icon(_mostrarFormularioCadastro ? Icons.close : Icons.add),
      ),
    );
  }
}
