class Mercado {
  String nome;
  String endereco;
  String logoUrl;
  String telefone;
  double? latitude;
  double? longitude;

  Mercado({
    required this.nome,
    required this.endereco,
    required this.logoUrl,
    required this.telefone,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'endereco': endereco,
      'logoUrl': logoUrl,
      'telefone': telefone,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Mercado.fromMap(Map<String, dynamic> map) {
    return Mercado(
      nome: map['nome'] ?? '',
      endereco: map['endereco'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      telefone: map['telefone'] ?? '',
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
    );
  }
}