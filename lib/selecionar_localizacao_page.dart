import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SelecionarLocalizacaoPage extends StatefulWidget {
  const SelecionarLocalizacaoPage({super.key});

  @override
  State<SelecionarLocalizacaoPage> createState() =>
      _SelecionarLocalizacaoPageState();
}

class _SelecionarLocalizacaoPageState extends State<SelecionarLocalizacaoPage> {
  LatLng _posicaoSelecionada = const LatLng(-15.3176, -49.1175);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Selecionar localização'),
        backgroundColor: Colors.green,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              Navigator.of(context).pop(_posicaoSelecionada);
            },
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: LatLng(-15.3176, -49.1175),
          zoom: 15,
        ),
        markers: {
          Marker(
            markerId: const MarkerId('mercado'),
            position: _posicaoSelecionada,
          ),
        },
        onTap: (posicao) {
          setState(() {
            _posicaoSelecionada = posicao;
          });
        },
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(14),
        color: Colors.white,
        child: const Text(
          'Toque no mapa para posicionar o mercado. Depois clique no ✓.',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
