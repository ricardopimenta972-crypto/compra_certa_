class Mercado {
  String nome;
  String responsavel;
  String telefone;
  String whatsapp;
  String endereco;
  String numero;
  String bairro;
  String cidade;
  String estado;
  String uf;
  String categoriaNegocio;
  String horarioFuncionamento;
  String logoUrl;
  double? latitude;
  double? longitude;
  int creditos;

  Mercado({
    required this.nome,
    this.responsavel = '',
    required this.telefone,
    String? whatsapp,
    required this.endereco,
    this.numero = '',
    this.bairro = '',
    this.cidade = '',
    this.estado = '',
    String? uf,
    this.categoriaNegocio = '',
    this.horarioFuncionamento = '',
    required this.logoUrl,
    this.latitude,
    this.longitude,
    this.creditos = 100,
  })  : whatsapp = whatsapp ?? telefone,
        uf = uf ?? estado;

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'responsavel': responsavel,
      'telefone': telefone,
      'whatsapp': whatsapp,
      'endereco': endereco,
      'numero': numero,
      'bairro': bairro,
      'cidade': cidade,
      'estado': estado,
      'uf': uf,
      'categoriaNegocio': categoriaNegocio,
      'horarioFuncionamento': horarioFuncionamento,
      'logoUrl': logoUrl,
      'latitude': latitude,
      'longitude': longitude,
      'creditos': creditos,
    };
  }

  factory Mercado.fromMap(Map<String, dynamic> map) {
    return Mercado(
      nome: map['nome'] ?? '',
      responsavel: map['responsavel'] ?? '',
      telefone: map['telefone'] ?? map['whatsapp'] ?? '',
      whatsapp: map['whatsapp'] ?? map['telefone'] ?? '',
      endereco: map['endereco'] ?? '',
      numero: map['numero'] ?? '',
      bairro: map['bairro'] ?? '',
      cidade: map['cidade'] ?? '',
      estado: map['estado'] ?? map['uf'] ?? '',
      uf: map['uf'] ?? map['estado'] ?? '',
      categoriaNegocio: map['categoriaNegocio'] ?? '',
      horarioFuncionamento: map['horarioFuncionamento'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
      creditos: map['creditos'] ?? 100,
    );
  }
}