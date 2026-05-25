class Mercado {
  String nome;
  String responsavel;
  String endereco;
  String numero;
  String bairro;
  String cidade;
  String estado;
  String categoria;
  String logoUrl;
  String telefone;
  String whatsapp;
  String horarioFuncionamento;
  int creditos;
  double? latitude;
  double? longitude;

  Mercado({
    required this.nome,
    this.responsavel = '',
    required this.endereco,
    this.numero = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    this.categoria = '',
    required this.logoUrl,
    required this.telefone,
    this.whatsapp = '',
    this.horarioFuncionamento = '',
    this.creditos = 100,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'responsavel': responsavel,
      'endereco': endereco,
      'numero': numero,
      'bairro': bairro,
      'cidade': cidade,
      'estado': estado,
      'categoria': categoria,
      'logoUrl': logoUrl,
      'telefone': telefone,
      'whatsapp': whatsapp,
      'horarioFuncionamento': horarioFuncionamento,
      'creditos': creditos,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Mercado.fromMap(Map<String, dynamic> map) {
    return Mercado(
      nome: map['nome'] ?? '',
      responsavel: map['responsavel'] ?? '',
      endereco: map['endereco'] ?? '',
      numero: map['numero'] ?? '',
      bairro: map['bairro'] ?? '',
      cidade: map['cidade'] ?? '',
      estado: map['estado'] ?? '',
      categoria: map['categoria'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      telefone: map['telefone'] ?? '',
      whatsapp: map['whatsapp'] ?? '',
      horarioFuncionamento: map['horarioFuncionamento'] ?? '',
      creditos: map['creditos'] ?? 100,
      latitude: map['latitude']?.toDouble(),
      longitude: map['longitude']?.toDouble(),
    );
  }
}
