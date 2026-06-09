import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../app_navigation.dart';
import '../selecionar_localizacao_page.dart';
import 'package:image_picker/image_picker.dart';
import '../legal/termo_responsabilidade_pdv_page.dart';
import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';

class CadastroMercadoPage extends StatefulWidget {
  const CadastroMercadoPage({super.key});

  @override
  State<CadastroMercadoPage> createState() => _CadastroMercadoPageState();
}

class _CadastroMercadoPageState extends State<CadastroMercadoPage> {
  final nomeController = TextEditingController();
  final responsavelController = TextEditingController();
  final telefoneController = TextEditingController();
  final enderecoController = TextEditingController();
  final numeroController = TextEditingController();
  final bairroController = TextEditingController();
  final cidadeController = TextEditingController();
  final estadoController = TextEditingController();
  final TextEditingController logoController = TextEditingController();
  final TextEditingController latitudeController = TextEditingController();
  final TextEditingController longitudeController = TextEditingController();
  String estadoSelecionado = 'GO';

  final List<String> estadosBrasil = [
    'AC',
    'AL',
    'AP',
    'AM',
    'BA',
    'CE',
    'DF',
    'ES',
    'GO',
    'MA',
    'MT',
    'MS',
    'MG',
    'PA',
    'PB',
    'PR',
    'PE',
    'PI',
    'RJ',
    'RN',
    'RS',
    'RO',
    'RR',
    'SC',
    'SP',
    'SE',
    'TO',
  ];
  final horarioController = TextEditingController();

  String categoriaSelecionada = 'Mercado / Supermercado';
  bool carregando = false;
  bool aceitouTermoResponsabilidade = false;

  final List<String> categorias = [
    'Mercado / Supermercado',
    'Açougue',
    'Hortifruti',
    'Padaria',
    'Distribuidora de bebidas',
  ];

  Future<void> salvarMercado() async {
    final usuario = FirebaseAuth.instance.currentUser;

    if (!aceitouTermoResponsabilidade) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Você precisa aceitar o Termo de Responsabilidade para continuar.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (usuario == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Usuário não logado')));
      return;
    }

    if (nomeController.text.trim().isEmpty ||
        telefoneController.text.trim().isEmpty ||
        cidadeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha pelo menos nome, WhatsApp e cidade'),
        ),
      );
      return;
    }

    String logoUrlFinal = logoController.text.trim();

    if (logoUrlFinal.isNotEmpty && !logoUrlFinal.startsWith('http')) {
      final arquivo = File(logoUrlFinal);
      final nomeArquivo =
          '${usuario.uid}_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final referencia = FirebaseStorage.instance
          .ref()
          .child('logos_mercados')
          .child(nomeArquivo);

      await referencia.putFile(arquivo);
      logoUrlFinal = await referencia.getDownloadURL();
    }

    setState(() => carregando = true);

    try {
      final mercadoRef = FirebaseFirestore.instance
          .collection('mercados')
          .doc(usuario.uid);

      final mercadoDoc = await mercadoRef.get();

      final dadosMercado = <String, dynamic>{
        'nome': nomeController.text.trim(),
        'responsavel': responsavelController.text.trim(),
        'telefone': telefoneController.text.trim(),
        'whatsapp': telefoneController.text.trim(),
        'endereco': enderecoController.text.trim(),
        'numero': numeroController.text.trim(),
        'bairro': bairroController.text.trim(),
        'cidade': cidadeController.text.trim(),
        'estado': estadoSelecionado,
        'categoriaNegocio': categoriaSelecionada,
        'horarioFuncionamento': horarioController.text.trim(),
        'logoUrl': logoUrlFinal,
        'latitude': double.tryParse(
          latitudeController.text.trim().replaceAll(',', '.'),
        ),
        'longitude': double.tryParse(
          longitudeController.text.trim().replaceAll(',', '.'),
        ),
        'uidDono': usuario.uid,
        'emailDono': usuario.email,
        'atualizadoEm': FieldValue.serverTimestamp(),
        'aceitouTermoResponsabilidadePdv': true,
        'versaoTermoResponsabilidadePdv': '1.0',
        'dataAceiteTermoResponsabilidadePdv': FieldValue.serverTimestamp(),
      };

      if (!mercadoDoc.exists) {
        dadosMercado.addAll({
          'plano': 'lancamento',
          'creditosDisponiveis': 100,
          'creditosUsadosTotal': 0,
          'creditosIniciaisRecebidos': true,
          'planoAtivo': false,
          'dataCriacao': FieldValue.serverTimestamp(),
          'dataAtivacaoPlano': null,
          'dataVencimentoPlano': null,
        });
      }

      await mercadoRef.set(dadosMercado, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Mercado salvo com sucesso')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AppNavigation()),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Erro ao salvar mercado: $e')));
    } finally {
      if (mounted) {
        setState(() => carregando = false);
      }
    }
  }

  Future<String?> escolherImagemDoDispositivo() async {
    final ImagePicker picker = ImagePicker();

    final XFile? imagem = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );

    if (imagem == null) {
      return null;
    }

    final arquivo = File(imagem.path);
    final nomeArquivo = '${DateTime.now().millisecondsSinceEpoch}.jpg';

    final referencia = FirebaseStorage.instance
        .ref()
        .child('logos_mercados')
        .child(nomeArquivo);

    await referencia.putFile(arquivo);

    final urlImagem = await referencia.getDownloadURL();

    return urlImagem;
  }

  Widget campoTexto({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType tipo = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cadastrar Mercado')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.storefront, size: 58, color: Colors.green),

            const SizedBox(height: 12),

            const Text(
              'Dados do seu PDV',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 6),

            const Text(
              'Essas informações aparecerão para os consumidores encontrarem sua loja.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 15),
            ),

            const SizedBox(height: 28),

            campoTexto(
              controller: nomeController,
              label: 'Nome do mercado / PDV',
              icon: Icons.store,
            ),

            campoTexto(
              controller: responsavelController,
              label: 'Nome do responsável',
              icon: Icons.person,
            ),

            campoTexto(
              controller: telefoneController,
              label: 'WhatsApp / telefone',
              icon: Icons.phone,
              tipo: TextInputType.phone,
            ),

            campoTexto(
              controller: enderecoController,
              label: 'Endereço',
              icon: Icons.location_on,
            ),

            Row(
              children: [
                Expanded(
                  child: campoTexto(
                    controller: numeroController,
                    label: 'Número',
                    icon: Icons.numbers,
                    tipo: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: campoTexto(
                    controller: bairroController,
                    label: 'Bairro',
                    icon: Icons.map,
                  ),
                ),
              ],
            ),

            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: campoTexto(
                    controller: cidadeController,
                    label: 'Cidade',
                    icon: Icons.location_city,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      value: estadoSelecionado,
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.flag),
                        labelText: 'UF',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      items: estadosBrasil.map((estado) {
                        return DropdownMenuItem(
                          value: estado,
                          child: Text(estado),
                        );
                      }).toList(),
                      onChanged: (valor) {
                        if (valor != null) {
                          setState(() {
                            estadoSelecionado = valor;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: DropdownButtonFormField<String>(
                value: categoriaSelecionada,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.category),
                  labelText: 'Categoria do negócio',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: categorias.map((categoria) {
                  return DropdownMenuItem(
                    value: categoria,
                    child: Text(categoria),
                  );
                }).toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() {
                      categoriaSelecionada = valor;
                    });
                  }
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final abertura = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 7, minute: 0),
                  );

                  if (abertura == null) return;

                  if (!mounted) return;

                  final fechamento = await showTimePicker(
                    context: context,
                    initialTime: const TimeOfDay(hour: 18, minute: 0),
                  );

                  if (fechamento == null) return;

                  final horario =
                      '${abertura.hour.toString().padLeft(2, '0')}:${abertura.minute.toString().padLeft(2, '0')} às ${fechamento.hour.toString().padLeft(2, '0')}:${fechamento.minute.toString().padLeft(2, '0')}';

                  setState(() {
                    horarioController.text = horario;
                  });
                },
                child: IgnorePointer(
                  child: TextField(
                    controller: horarioController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.access_time),
                      labelText: 'Horário de funcionamento',
                      hintText: 'Toque para selecionar o horário',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () async {
                final resultado = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SelecionarLocalizacaoPage(),
                  ),
                );

                if (resultado != null) {
                  setState(() {
                    latitudeController.text = resultado.latitude.toString();
                    longitudeController.text = resultado.longitude.toString();
                  });

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Localização selecionada com sucesso.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.place),
              label: Text(
                latitudeController.text.isEmpty
                    ? 'Selecionar localização no mapa'
                    : 'Localização selecionada',
              ),
            ),

            const SizedBox(height: 10),

            OutlinedButton.icon(
              onPressed: () async {
                final imagem = await escolherImagemDoDispositivo();

                if (imagem != null) {
                  setState(() {
                    logoController.text = imagem;
                  });

                  if (!mounted) return;

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logo/fachada selecionada com sucesso.'),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.image),
              label: Text(
                logoController.text.isEmpty
                    ? 'Adicionar logo ou fachada'
                    : 'Logo/fachada selecionada',
              ),
            ),

            const SizedBox(height: 24),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Checkbox(
                  value: aceitouTermoResponsabilidade,
                  onChanged: (valor) {
                    setState(() {
                      aceitouTermoResponsabilidade = valor ?? false;
                    });
                  },
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TermoResponsabilidadePdvPage(),
                        ),
                      );
                    },
                    child: const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: Text.rich(
                        TextSpan(
                          text: 'Li e aceito o ',
                          children: [
                            TextSpan(
                              text:
                                  'Termo de Responsabilidade de Publicação do PDV',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.bold,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: carregando ? null : salvarMercado,
                child: carregando
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Salvar mercado',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
