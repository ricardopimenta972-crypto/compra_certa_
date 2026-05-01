import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'produt.dart';

class OfertasPage extends StatefulWidget {
  const OfertasPage({super.key});

  @override
  State<OfertasPage> createState() => _OfertasPageState();
}

class _OfertasPageState extends State<OfertasPage> {
  final TextEditingController _buscaController = TextEditingController();

  List<Produto> _ofertas = [];
  String _busca = '';

  @override
  void initState() {
    super.initState();
    _carregarOfertas();
  }

  @override
  void dispose() {
    _buscaController.dispose();
    super.dispose();
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
    final prefs = await SharedPreferences.getInstance();
    final List<String>? listaSalva = prefs.getStringList('produtos');

    if (listaSalva == null) return;

    setState(() {
      _ofertas = listaSalva
          .map((item) => Produto.fromMap(jsonDecode(item)))
          .where((produto) {
            final agora = DateTime.now();

            if (!produto.ehOferta) return false;

            if (produto.ehRelampago) {
              if (produto.inicioProgramado == null ||
                  produto.fimProgramado == null) {
                return false;
              }

              return agora.isAfter(produto.inicioProgramado!) &&
                  agora.isBefore(produto.fimProgramado!);
            }

            final ofertaValida =
                produto.enquantoDurar ||
                (produto.validade != null && produto.validade!.isAfter(agora));

            if (!ofertaValida) return false;

            return true;
          })
          .toList();
      _ofertas.sort((a, b) {
        final aMenor = _ehMenorPreco(a);
        final bMenor = _ehMenorPreco(b);

        if (aMenor && !bMenor) return -1;
        if (!aMenor && bMenor) return 1;

        return a.preco.compareTo(b.preco);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final ofertasFiltradas = _ofertas.where((produto) {
      final texto = _busca.toLowerCase();

      return produto.nome.toLowerCase().contains(texto) ||
          produto.mercado.toLowerCase().contains(texto) ||
          produto.categoria.toLowerCase().contains(texto);
    }).toList();

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
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.location_on, color: Colors.white, size: 20),
                SizedBox(width: 6),
                Text(
                  'Ofertas em Goianésia',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: Colors.white),
              ],
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
                        Image.network(
                          destaque.imagemUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.shopping_basket,
                              color: Colors.white,
                              size: 46,
                            );
                          },
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

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: menorPreco ? Colors.green.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: menorPreco
            ? Border.all(color: Colors.green.shade300, width: 1.4)
            : null,
        boxShadow: [
          BoxShadow(
            color: menorPreco
                ? Colors.green.withOpacity(0.22)
                : Colors.grey.shade300,
            blurRadius: menorPreco ? 12 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.green.shade100,
                  child: const Icon(Icons.store, color: Colors.green, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    produto.mercado,
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                if (menorPreco)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Menor preço',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                else
                  const Icon(Icons.more_horiz, color: Colors.grey),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 126,
                height: 126,
                margin: const EdgeInsets.fromLTRB(12, 0, 8, 12),
                decoration: BoxDecoration(
                  color: menorPreco
                      ? Colors.green.shade100
                      : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: produto.imagemUrl.isNotEmpty
                    ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.network(
                              produto.imagemUrl,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  },
                              errorBuilder: (context, error, stackTrace) {
                                return const Center(
                                  child: Icon(
                                    Icons.image_not_supported,
                                    size: 46,
                                    color: Colors.green,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      )
                    : const Icon(
                        Icons.workspace_premium,
                        size: 46,
                        color: Colors.green,
                      ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 12, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (produto.ehOferta)
                        Container(
                          margin: const EdgeInsets.only(bottom: 6),
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
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          produto.categoria,
                          style: const TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'R\$ ${_formatarPreco(produto.preco)}',
                        style: TextStyle(
                          fontSize: menorPreco ? 27 : 25,
                          fontWeight: FontWeight.bold,
                          color: produto.ehRelampago
                              ? Colors.red
                              : Colors.green,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            menorPreco ? Icons.check_circle : Icons.access_time,
                            size: 14,
                            color: menorPreco ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              menorPreco
                                  ? 'Melhor preço encontrado\n${_formatarValidade(produto)}'
                                  : _formatarValidade(produto),
                              style: TextStyle(
                                fontSize: 11,
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
              ),
            ],
          ),
        ],
      ),
    );
  }
}
