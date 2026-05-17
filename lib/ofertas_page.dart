import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'produt.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfertasPage extends StatefulWidget {
  const OfertasPage({super.key});

  @override
  State<OfertasPage> createState() => _OfertasPageState();
}

class _OfertasPageState extends State<OfertasPage> {
  Future<void> _abrirMapa(Produto produto) async {
    Uri url;

    if (produto.latitude != null && produto.longitude != null) {
      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${produto.latitude},${produto.longitude}',
      );
    } else {
      final enderecoCompleto = produto.endereco.trim();

      if (enderecoCompleto.isEmpty) {
        debugPrint('Endereço vazio.');
        return;
      }

      url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(enderecoCompleto)}',
      );
    }

    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  final TextEditingController _buscaController = TextEditingController();

  List<Produto> _ofertas = [];
  String _busca = '';

  String _cidadeSelecionada = 'Goianésia';
  double _raioSelecionado = 5;

  final List<String> _cidadesDisponiveis = [
    'Goianésia',
    'Goiânia',
    'Anápolis',
    'Brasília',
  ];

  final List<double> _raiosDisponiveis = [1, 3, 5, 10, 25];

  @override
  void initState() {
    super.initState();
    _carregarOfertas();
    _carregarPreferenciasLocalizacao();
  }

  Future<void> _carregarPreferenciasLocalizacao() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _cidadeSelecionada = prefs.getString('cidadeSelecionada') ?? 'Goianésia';
      _raioSelecionado = prefs.getDouble('raioSelecionado') ?? 5;
    });
  }

  Future<void> _salvarPreferenciasLocalizacao() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('cidadeSelecionada', _cidadeSelecionada);
    await prefs.setDouble('raioSelecionado', _raioSelecionado);
  }

  void _abrirSeletorLocalizacao() {
    String cidadeTemporaria = _cidadeSelecionada;
    double raioTemporario = _raioSelecionado;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Selecionar local das ofertas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 16),

                    DropdownButtonFormField<String>(
                      value: cidadeTemporaria,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        border: OutlineInputBorder(),
                      ),
                      items: _cidadesDisponiveis.map((cidade) {
                        return DropdownMenuItem(
                          value: cidade,
                          child: Text(cidade),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        if (valor == null) return;

                        setModalState(() {
                          cidadeTemporaria = valor;
                        });
                      },
                    ),

                    const SizedBox(height: 14),

                    DropdownButtonFormField<double>(
                      value: raioTemporario,
                      decoration: const InputDecoration(
                        labelText: 'Raio de busca',
                        border: OutlineInputBorder(),
                      ),
                      items: _raiosDisponiveis.map((raio) {
                        return DropdownMenuItem(
                          value: raio,
                          child: Text('${raio.toInt()} km'),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        if (valor == null) return;

                        setModalState(() {
                          raioTemporario = valor;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            _cidadeSelecionada = cidadeTemporaria;
                            _raioSelecionado = raioTemporario;
                          });

                          await _salvarPreferenciasLocalizacao();

                          if (context.mounted) {
                            Navigator.pop(context);
                          }
                        },
                        child: const Text('Aplicar filtros'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
  }

  Map<String, double>? _coordenadasCidade(String cidade) {
    switch (cidade) {
      case 'Goianésia':
        return {'lat': -15.3175, 'lng': -49.1175};
      case 'Goiânia':
        return {'lat': -16.6869, 'lng': -49.2648};
      case 'Anápolis':
        return {'lat': -16.3281, 'lng': -48.9530};
      case 'Brasília':
        return {'lat': -15.7939, 'lng': -47.8828};
      default:
        return null;
    }
  }

  double _grausParaRadianos(double graus) {
    return graus * pi / 180;
  }

  double _calcularDistanciaKm({
    required double latOrigem,
    required double lngOrigem,
    required double latDestino,
    required double lngDestino,
  }) {
    const raioTerraKm = 6371;

    final dLat = _grausParaRadianos(latDestino - latOrigem);
    final dLng = _grausParaRadianos(lngDestino - lngOrigem);

    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_grausParaRadianos(latOrigem)) *
            cos(_grausParaRadianos(latDestino)) *
            sin(dLng / 2) *
            sin(dLng / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return raioTerraKm * c;
  }

  double? _distanciaDoProdutoKm(Produto produto) {
    if (produto.latitude == null || produto.longitude == null) {
      return null;
    }

    final coordenadas = _coordenadasCidade(_cidadeSelecionada);

    if (coordenadas == null) {
      return null;
    }

    return _calcularDistanciaKm(
      latOrigem: coordenadas['lat']!,
      lngOrigem: coordenadas['lng']!,
      latDestino: produto.latitude!,
      lngDestino: produto.longitude!,
    );
  }

  String _formatarDistancia(double distanciaKm) {
    if (distanciaKm < 1) {
      return '${(distanciaKm * 1000).round()} m';
    }

    return '${distanciaKm.toStringAsFixed(1).replaceAll('.', ',')} km';
  }

  String _formatarPreco(double preco) {
    return preco.toStringAsFixed(2).replaceAll('.', ',');
  }

  String _formatarValidade(Produto produto) {
    if (produto.ehRelampago) {
      if (produto.fimProgramado == null) {
        return '⚡ Relâmpago ativo';
      }

      final dia = produto.fimProgramado!.day.toString().padLeft(2, '0');
      final mes = produto.fimProgramado!.month.toString().padLeft(2, '0');
      final hora = produto.fimProgramado!.hour.toString().padLeft(2, '0');
      final minuto = produto.fimProgramado!.minute.toString().padLeft(2, '0');

      return '⚡ Relâmpago até $dia/$mes às $hora:$minuto';
    }

    if (produto.enquantoDurar) {
      return 'Enquanto durar o estoque';
    }

    if (produto.validade == null) {
      return 'Oferta sem validade';
    }

    final agora = DateTime.now();

    if (produto.validade!.isBefore(agora)) {
      return '❌ Oferta encerrada';
    }

    final dia = produto.validade!.day.toString().padLeft(2, '0');
    final mes = produto.validade!.month.toString().padLeft(2, '0');
    final hora = produto.validade!.hour.toString().padLeft(2, '0');
    final minuto = produto.validade!.minute.toString().padLeft(2, '0');

    return '⏰ Válido até $dia/$mes às $hora:$minuto';
  }

  String _normalizarNome(String nome) {
    return nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  double _menorPrecoDoProduto(String nomeProduto) {
    final nomeNormalizado = _normalizarNome(nomeProduto);

    final grupo = _ofertas.where((produto) {
      return _normalizarNome(produto.nome) == nomeNormalizado;
    }).toList();

    if (grupo.isEmpty) return 0;

    return grupo
        .map((produto) => produto.preco)
        .reduce((a, b) => a < b ? a : b);
  }

  bool _ehMenorPreco(Produto produto) {
    return produto.preco == _menorPrecoDoProduto(produto.nome);
  }

  Future<void> _carregarOfertas() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('produtos')
          .orderBy('atualizadoEm', descending: true)
          .get();

      final agora = DateTime.now();

      final ofertasCarregadas = snapshot.docs
          .map((doc) {
            final data = doc.data();

            return Produto.fromMap({
              ...data,
              'produtoId': data['produtoId'] ?? doc.id,
            });
          })
          .where((produto) {
            if (!produto.ehOferta) return false;

            if (produto.statusOferta != 'ativa') return false;

            if (produto.ehRelampago) {
              if (produto.inicioProgramado == null ||
                  produto.fimProgramado == null) {
                return false;
              }

              return agora.isAfter(produto.inicioProgramado!) &&
                  agora.isBefore(produto.fimProgramado!);
            }

            if (produto.enquantoDurar) return true;

            if (produto.validade != null) {
              return produto.validade!.isAfter(agora);
            }

            return true;
          })
          .toList();

      setState(() {
        _ofertas = ofertasCarregadas;
      });
    } catch (e) {
      debugPrint('Erro ao carregar ofertas do Firestore: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ofertasFiltradas = _ofertas.where((produto) {
      final texto = _busca.toLowerCase();

      return produto.nome.toLowerCase().contains(texto) ||
          produto.mercado.toLowerCase().contains(texto) ||
          produto.categoria.toLowerCase().contains(texto);
    }).toList();

    ofertasFiltradas.sort((a, b) {
      final distanciaA = _distanciaDoProdutoKm(a) ?? 999999;
      final distanciaB = _distanciaDoProdutoKm(b) ?? 999999;

      final comparacaoDistancia = distanciaA.compareTo(distanciaB);

      if (comparacaoDistancia != 0) {
        return comparacaoDistancia;
      }

      return a.preco.compareTo(b.preco);
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _carregarOfertas,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _buildTopo(),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildBusca(),
                  const SizedBox(height: 16),
                  _buildBannerPrincipal(),
                  const SizedBox(height: 18),
                  _buildTituloSecao(),
                  const SizedBox(height: 12),
                  if (_ofertas.isEmpty)
                    _buildMensagemVazia('Nenhuma oferta cadastrada ainda.')
                  else if (ofertasFiltradas.isEmpty)
                    _buildMensagemVazia('Nenhuma oferta encontrada.')
                  else
                    ...ofertasFiltradas.map((produto) {
                      return _buildOfertaCard(produto);
                    }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopo() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 46, 16, 20),
      decoration: const BoxDecoration(
        color: Colors.green,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(26),
          bottomRight: Radius.circular(26),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.menu, color: Colors.white),
              ),
              const Expanded(
                child: Text(
                  'COMPRA CERTA',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.notifications_none,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          GestureDetector(
            onTap: _abrirSeletorLocalizacao,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.location_on, color: Colors.white, size: 20),

                  const SizedBox(width: 6),

                  Text(
                    '$_cidadeSelecionada • ${_raioSelecionado.toInt()} km',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(width: 4),

                  const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBusca() {
    return TextField(
      controller: _buscaController,
      onChanged: (valor) {
        setState(() {
          _busca = valor;
        });
      },
      decoration: InputDecoration(
        hintText: 'Buscar produto, mercado ou categoria...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _busca.isNotEmpty
            ? IconButton(
                onPressed: () {
                  _buscaController.clear();
                  setState(() {
                    _busca = '';
                  });
                },
                icon: const Icon(Icons.clear),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildBannerPrincipal() {
    final Produto? destaque = _ofertas.isEmpty
        ? null
        : _ofertas.reduce((a, b) => a.preco <= b.preco ? a : b);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.green.shade600, Colors.green.shade400],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: destaque == null
                ? const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'OFERTA DO DIA 🔥',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Cadastre ofertas para aparecerem aqui.',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MENOR PREÇO DO DIA 🔥',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        destaque.nome,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        destaque.mercado,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          'R\$ ${_formatarPreco(destaque.preco)}',
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 86,
            height: 86,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(24),
            ),
            child: destaque != null && destaque.imagemUrl.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _imagemDaOferta(
                          destaque.imagemUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        ),

                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [
                                Colors.black.withOpacity(0.45),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),

                        Positioned(
                          left: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'TOP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : const Icon(
                    Icons.shopping_basket,
                    color: Colors.white,
                    size: 46,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _imagemDaOferta(
    String caminho, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.cover,
  }) {
    if (caminho.trim().isEmpty) {
      return const Icon(
        Icons.image_not_supported,
        color: Colors.green,
        size: 46,
      );
    }

    final ehImagemDaInternet =
        caminho.startsWith('http://') || caminho.startsWith('https://');

    if (ehImagemDaInternet) {
      return Image.network(
        caminho,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.image_not_supported,
            color: Colors.green,
            size: 46,
          );
        },
      );
    }

    return Image.file(
      File(caminho),
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stackTrace) {
        return const Icon(
          Icons.image_not_supported,
          color: Colors.green,
          size: 46,
        );
      },
    );
  }

  Widget _buildTituloSecao() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Promoções das lojas',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 3),
              Text(
                'Compare e encontre o menor preço',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            '${_ofertas.length} ofertas',
            style: const TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMensagemVazia(String texto) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Center(
        child: Text(texto, style: const TextStyle(color: Colors.grey)),
      ),
    );
  }

  Widget _buildOfertaCard(Produto produto) {
    final menorPreco = _ehMenorPreco(produto);
    final distancia = _distanciaDoProdutoKm(produto);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: menorPreco ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: menorPreco ? Colors.green.shade300 : Colors.grey.shade200,
          width: menorPreco ? 1.4 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: menorPreco
                ? Colors.green.withOpacity(0.18)
                : Colors.black.withOpacity(0.06),
            blurRadius: menorPreco ? 14 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.green.shade100,
                  child: produto.logoMercadoUrl.isNotEmpty
                      ? ClipOval(
                          child: _imagemDaOferta(
                            produto.logoMercadoUrl,
                            width: 40,
                            height: 40,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.store, color: Colors.green, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        produto.mercado,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          if (produto.endereco.isNotEmpty)
                            GestureDetector(
                              onTap: () => _abrirMapa(produto),
                              child: const Text(
                                'Como chegar',
                                style: TextStyle(
                                  color: Colors.blue,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          if (distancia != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.location_on,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  _formatarDistancia(distancia),
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (menorPreco)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'Menor preço',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 122,
                  height: 122,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.green.shade100),
                  ),
                  child: produto.imagemUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: _imagemDaOferta(
                            produto.imagemUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: double.infinity,
                          ),
                        )
                      : const Icon(
                          Icons.image_outlined,
                          size: 44,
                          color: Colors.green,
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (produto.ehOferta)
                        Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: produto.ehRelampago
                                ? Colors.orange
                                : Colors.green,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            produto.ehRelampago ? '⚡ RELÂMPAGO' : '🔥 OFERTA',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                      Text(
                        produto.nome,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        produto.categoria,
                        style: const TextStyle(
                          color: Colors.green,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'R\$ ${_formatarPreco(produto.preco)} / ${produto.unidadeMedida}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: menorPreco ? 27 : 25,
                          fontWeight: FontWeight.bold,
                          color: produto.ehRelampago
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),

                      const SizedBox(height: 7),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            menorPreco ? Icons.check_circle : Icons.access_time,
                            size: 15,
                            color: menorPreco ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              menorPreco
                                  ? 'Melhor preço encontrado\n${_formatarValidade(produto)}'
                                  : _formatarValidade(produto),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: menorPreco ? Colors.green : Colors.grey,
                                fontWeight: menorPreco
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
