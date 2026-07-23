import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'produt.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth/login_page.dart';
import 'legal/termo_uso_cliente_page.dart';
import 'legal/termos_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_navigation.dart';
import 'servicos/notificacao_service.dart';
import 'package:geolocator/geolocator.dart';
import 'atualizacao_service.dart';

class OfertasPage extends StatefulWidget {
  const OfertasPage({super.key});

  @override
  State<OfertasPage> createState() => _OfertasPageState();
}

class _OfertasPageState extends State<OfertasPage> {
  bool _aceitouResponsabilidadeOferta = false;

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

  String _cidadeSelecionada = 'Próximo de você';
  double _raioSelecionado = 50;
  String _cidadePesquisada = '';

  double? _latitudeConsumidor;
  double? _longitudeConsumidor;
  bool _carregandoLocalizacao = false;

  String _normalizarTexto(String texto) {
    return texto
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[áàãâä]'), 'a')
        .replaceAll(RegExp(r'[éèêë]'), 'e')
        .replaceAll(RegExp(r'[íìîï]'), 'i')
        .replaceAll(RegExp(r'[óòõôö]'), 'o')
        .replaceAll(RegExp(r'[úùûü]'), 'u')
        .replaceAll('ç', 'c');
  }

  final List<double> _raiosDisponiveis = [1, 3, 5, 10, 25, 50, 75, 100];

  @override
  void initState() {
    super.initState();
    _carregarOfertas();
    _carregarPreferenciasLocalizacao();
    _verificarAceiteTermoCliente();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      AtualizacaoService.verificarAtualizacao(context);
    });
  }

  Future<void> _verificarAceiteTermoCliente() async {
    final prefs = await SharedPreferences.getInstance();
    final aceitou = prefs.getBool('aceitou_termo_uso_cliente') ?? false;

    if (!aceitou && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _mostrarDialogoTermoCliente();
      });
    }
  }

  void _mostrarDialogoTermoCliente() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Termos de uso e privacidade'),
          content: const Text(
            'Para usar o Compra Certa, é necessário ler e aceitar os Termos de Uso e Privacidade do cliente.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const TermoUsoClientePage(),
                  ),
                );
              },
              child: const Text('Ler termos'),
            ),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('aceitou_termo_uso_cliente', true);
                await prefs.setString('versao_termo_uso_cliente', '1.0');
                await prefs.setString(
                  'data_aceite_termo_uso_cliente',
                  DateTime.now().toIso8601String(),
                );

                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: const Text('Aceitar e continuar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _carregarPreferenciasLocalizacao() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      _cidadeSelecionada = 'Próximo de você';
      _raioSelecionado = prefs.getDouble('raioSelecionado') ?? 50;
    });

    await _obterLocalizacaoAtual();
    await _carregarOfertas();
  }

  Future<void> _salvarPreferenciasLocalizacao() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('raioSelecionado', _raioSelecionado);
  }

  Future<void> _obterLocalizacaoAtual() async {
    try {
      setState(() {
        _carregandoLocalizacao = true;
      });

      bool servicoAtivo = await Geolocator.isLocationServiceEnabled();

      if (!servicoAtivo) {
        debugPrint('Serviço de localização desativado.');
        return;
      }

      LocationPermission permissao = await Geolocator.checkPermission();

      if (permissao == LocationPermission.denied) {
        permissao = await Geolocator.requestPermission();
      }

      if (permissao == LocationPermission.denied ||
          permissao == LocationPermission.deniedForever) {
        debugPrint('Permissão de localização negada.');
        return;
      }

      final posicao = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitudeConsumidor = posicao.latitude;
        _longitudeConsumidor = posicao.longitude;
        _cidadeSelecionada = 'Próximo de você';
      });

      await NotificacaoService.atualizarLocalizacaoConsumidor(
        cidade: 'Localização atual',
        latitude: posicao.latitude,
        longitude: posicao.longitude,
        raioKm: _raioSelecionado,
      );
    } catch (e) {
      debugPrint('Erro ao obter localização atual: $e');
    } finally {
      if (mounted) {
        setState(() {
          _carregandoLocalizacao = false;
        });
      }
    }
  }

  void _abrirSeletorLocalizacao() {
    double raioTemporario = _raioSelecionado;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        double raioTemporario = _raioSelecionado;
        String cidadeTemporaria = _cidadePesquisada;
        final cidadeController = TextEditingController(text: _cidadePesquisada);

        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 18,
                  right: 18,
                  top: 18,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 18,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Filtro de ofertas',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Digite uma cidade ou use sua localização atual com raio.',
                      style: TextStyle(fontSize: 14, color: Colors.black54),
                    ),

                    const SizedBox(height: 16),

                    TextField(
                      controller: cidadeController,
                      decoration: const InputDecoration(
                        labelText: 'Pesquisar cidade',
                        hintText: 'Ex: Goiânia, Anápolis, Ceres',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (valor) {
                        cidadeTemporaria = valor;
                      },
                    ),

                    const SizedBox(height: 16),

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
                          Navigator.pop(context);

                          setState(() {
                            _cidadePesquisada = cidadeController.text.trim();
                            _raioSelecionado = raioTemporario;

                            if (_cidadePesquisada.trim().isNotEmpty) {
                              _cidadeSelecionada = _cidadePesquisada.trim();
                            } else {
                              _cidadeSelecionada = 'Próximo de você';
                            }
                          });

                          await _salvarPreferenciasLocalizacao();
                          await _obterLocalizacaoAtual();
                          await _carregarOfertas();
                        },
                        child: const Text('Aplicar filtro'),
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

    if (_latitudeConsumidor == null || _longitudeConsumidor == null) {
      return null;
    }

    return _calcularDistanciaKm(
      latOrigem: _latitudeConsumidor!,
      lngOrigem: _longitudeConsumidor!,
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

  String _textoHorarioMercado(Produto produto) {
    final agora = DateTime.now();

    final nomesDias = {
      DateTime.monday: 'segunda',
      DateTime.tuesday: 'terca',
      DateTime.wednesday: 'quarta',
      DateTime.thursday: 'quinta',
      DateTime.friday: 'sexta',
      DateTime.saturday: 'sabado',
      DateTime.sunday: 'domingo',
    };

    final diaAtual = nomesDias[agora.weekday];

    if (diaAtual != null && produto.horariosFuncionamento.isNotEmpty) {
      final dadosDia = produto.horariosFuncionamento[diaAtual];

      if (dadosDia is Map) {
        final aberto = dadosDia['aberto'] == true;

        if (!aberto) {
          return '🔴 Fechado';
        }

        final abertura = (dadosDia['abertura'] ?? '').toString().trim();
        final fechamento = (dadosDia['fechamento'] ?? '').toString().trim();

        final aberturaPartes = abertura.split(':');
        final fechamentoPartes = fechamento.split(':');

        if (aberturaPartes.length == 2 && fechamentoPartes.length == 2) {
          final horaAbertura = int.tryParse(aberturaPartes[0]);
          final minutoAbertura = int.tryParse(aberturaPartes[1]);
          final horaFechamento = int.tryParse(fechamentoPartes[0]);
          final minutoFechamento = int.tryParse(fechamentoPartes[1]);

          if (horaAbertura != null &&
              minutoAbertura != null &&
              horaFechamento != null &&
              minutoFechamento != null) {
            final aberturaHoje = DateTime(
              agora.year,
              agora.month,
              agora.day,
              horaAbertura,
              minutoAbertura,
            );

            final fechamentoHoje = DateTime(
              agora.year,
              agora.month,
              agora.day,
              horaFechamento,
              minutoFechamento,
            );

            if (!agora.isBefore(aberturaHoje) &&
                agora.isBefore(fechamentoHoje)) {
              return '🟢 Aberto até $fechamento';
            }

            return '🔴 Fechado';
          }
        }
      }
    }

    final horarioAntigo = produto.horarioFuncionamento.trim();

    if (horarioAntigo.isEmpty) {
      return '⚪ Horário não informado';
    }

    final partes = horarioAntigo.split(' às ');

    if (partes.length != 2) {
      return '⚪ Horário não informado';
    }

    final abertura = partes[0].trim();
    final fechamento = partes[1].trim();

    final aberturaPartes = abertura.split(':');
    final fechamentoPartes = fechamento.split(':');

    if (aberturaPartes.length != 2 || fechamentoPartes.length != 2) {
      return '⚪ Horário não informado';
    }

    final horaAbertura = int.tryParse(aberturaPartes[0]);
    final minutoAbertura = int.tryParse(aberturaPartes[1]);
    final horaFechamento = int.tryParse(fechamentoPartes[0]);
    final minutoFechamento = int.tryParse(fechamentoPartes[1]);

    if (horaAbertura == null ||
        minutoAbertura == null ||
        horaFechamento == null ||
        minutoFechamento == null) {
      return '⚪ Horário não informado';
    }

    final aberturaHoje = DateTime(
      agora.year,
      agora.month,
      agora.day,
      horaAbertura,
      minutoAbertura,
    );

    final fechamentoHoje = DateTime(
      agora.year,
      agora.month,
      agora.day,
      horaFechamento,
      minutoFechamento,
    );

    if (!agora.isBefore(aberturaHoje) && agora.isBefore(fechamentoHoje)) {
      return '🟢 Aberto até $fechamento';
    }

    return '🔴 Fechado';
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
          .get();

      final agora = DateTime.now();
      final cidadeBusca = _normalizarTexto(_cidadePesquisada);

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

            if (cidadeBusca.isNotEmpty) {
              final cidadeProduto = _normalizarTexto(produto.cidade);

              if (!cidadeProduto.contains(cidadeBusca)) {
                return false;
              }
            } else {
              if (_latitudeConsumidor == null || _longitudeConsumidor == null) {
                return false;
              }

              if (produto.latitude == null || produto.longitude == null) {
                return false;
              }

              final distancia = _calcularDistanciaKm(
                latOrigem: _latitudeConsumidor!,
                lngOrigem: _longitudeConsumidor!,
                latDestino: produto.latitude!,
                lngDestino: produto.longitude!,
              );

              if (distancia > _raioSelecionado) {
                return false;
              }
            }

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

      final passaNaBusca =
          produto.nome.toLowerCase().contains(texto) ||
          produto.mercado.toLowerCase().contains(texto) ||
          produto.categoria.toLowerCase().contains(texto);

      if (!passaNaBusca) return false;

      if (_cidadePesquisada.trim().isNotEmpty) {
        final cidadeBusca = _normalizarTexto(_cidadePesquisada);
        final cidadeProduto = _normalizarTexto(produto.cidade);

        return cidadeProduto.contains(cidadeBusca);
      }

      final distanciaKm = _distanciaDoProdutoKm(produto);

      if (distanciaKm == null) return false;

      return distanciaKm <= _raioSelecionado;
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
          padding: const EdgeInsets.only(bottom: 24),
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
              GestureDetector(
                onTap: _abrirMenuConsumidor,
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.menu, color: Colors.white),
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

  void _abrirMenuConsumidor() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.store),
                  title: Text(
                    FirebaseAuth.instance.currentUser == null
                        ? 'Entrar / criar conta de mercado'
                        : 'Meu PDV',
                  ),
                  onTap: () {
                    Navigator.pop(context);

                    final usuario = FirebaseAuth.instance.currentUser;

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => usuario == null
                            ? const LoginPage()
                            : const AppNavigation(),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.support_agent),
                  title: const Text('Contato / suporte'),
                  onTap: () async {
                    Navigator.pop(context);

                    final Uri email = Uri(
                      scheme: 'mailto',
                      path: 'central.compracerta@gmail.com',
                      queryParameters: {'subject': 'Suporte Compra Certa'},
                    );

                    final abriu = await launchUrl(email);

                    if (!abriu && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Não foi possível abrir o aplicativo de e-mail.',
                          ),
                        ),
                      );
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Termos'),
                  subtitle: const Text('Termos do cliente e do PDV'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TermosPage()),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Sobre o Compra Certa'),
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'Compra Certa',
                      applicationVersion: 'Versão de teste',
                      children: const [
                        Text(
                          'O Compra Certa ajuda consumidores a encontrar ofertas próximas e mercados a divulgarem promoções de forma simples.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
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

  void _denunciarOferta(Produto produto) {
    showDialog(
      context: context,
      builder: (context) {
        String motivoSelecionado = 'Preço incorreto';

        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Denunciar oferta'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Informe o motivo da denúncia. Nossa equipe poderá revisar esta oferta.',
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: motivoSelecionado,
                    items: const [
                      DropdownMenuItem(
                        value: 'Preço incorreto',
                        child: Text('Preço incorreto'),
                      ),
                      DropdownMenuItem(
                        value: 'Oferta vencida',
                        child: Text('Oferta vencida'),
                      ),
                      DropdownMenuItem(
                        value: 'Produto indisponível',
                        child: Text('Produto indisponível'),
                      ),
                      DropdownMenuItem(
                        value: 'Imagem ou descrição incorreta',
                        child: Text('Imagem ou descrição incorreta'),
                      ),
                      DropdownMenuItem(
                        value: 'Outro motivo',
                        child: Text('Outro motivo'),
                      ),
                    ],
                    onChanged: (valor) {
                      setStateDialog(() {
                        motivoSelecionado = valor ?? 'Preço incorreto';
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    await FirebaseFirestore.instance
                        .collection('denuncias_ofertas')
                        .add({
                          'produtoId': produto.produtoId,
                          'nomeProduto': produto.nome,
                          'mercado': produto.mercado,
                          'mercadoUid': produto.mercadoUid,

                          'preco': produto.preco,
                          'categoria': produto.categoria,
                          'imagemUrl': produto.imagemUrl,

                          'motivo': motivoSelecionado,

                          'status': 'pendente',

                          'criadoEm': FieldValue.serverTimestamp(),
                        });

                    if (!mounted) return;

                    Navigator.pop(context);

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Denúncia enviada para análise. Obrigado pelo aviso.',
                        ),
                        backgroundColor: Colors.green,
                      ),
                    );
                  },
                  child: const Text('Enviar denúncia'),
                ),
              ],
            );
          },
        );
      },
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

                      Text(
                        _textoHorarioMercado(produto),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),

                      const SizedBox(height: 4),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          if (produto.endereco.isNotEmpty)
                            InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _abrirMapa(produto),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: Colors.blue.shade300,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.navigation,
                                      size: 14,
                                      color: Colors.blue,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Como chegar',
                                      style: TextStyle(
                                        color: Colors.blue,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          if (distancia != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.location_on,
                              size: 14,
                              color: Colors.blue.shade700,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatarDistancia(distancia),
                              style: const TextStyle(
                                color: Colors.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Column(
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

                    const SizedBox(height: 4),

                    TextButton.icon(
                      onPressed: () => _denunciarOferta(produto),
                      icon: const Icon(Icons.flag_outlined, size: 14),
                      label: const Text(
                        'Denunciar',
                        style: TextStyle(fontSize: 12),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 24),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                  ],
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
                          const Icon(
                            Icons.access_time,
                            size: 15,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              _formatarValidade(produto),
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.25,
                                color: Colors.grey,
                                fontWeight: FontWeight.normal,
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
