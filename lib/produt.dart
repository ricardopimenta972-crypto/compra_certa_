class Produto {
  String nome;
  double preco;
  double quantidade;
  String unidadeMedida;
  bool comprado;
  String categoria;
  String mercado;
  String endereco;
  bool ehOferta;
  bool enquantoDurar;
  DateTime? validade;
  String imagemUrl;
  String logoMercadoUrl;
  DateTime? inicioProgramado;
  DateTime? fimProgramado;
  bool ehRelampago;
  double? latitude;
  double? longitude;

  Produto({
    required this.nome,
    required this.preco,
    this.quantidade = 1,
    this.unidadeMedida = 'un',
    this.comprado = false,
    this.categoria = 'Geral',
    this.mercado = 'Sem mercado',
    this.endereco = 'Endereço não informado',
    this.ehOferta = true,
    this.enquantoDurar = false,
    this.validade,
    this.imagemUrl = '',
    this.logoMercadoUrl = '',
    this.inicioProgramado,
    this.fimProgramado,
    this.ehRelampago = false,
    this.latitude,
    this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'preco': preco,
      'quantidade': quantidade,
      'unidadeMedida': unidadeMedida,
      'comprado': comprado,
      'categoria': categoria,
      'mercado': mercado,
      'endereco': endereco,
      'ehOferta': ehOferta,
      'enquantoDurar': enquantoDurar,
      'validade': validade?.millisecondsSinceEpoch,
      'imagemUrl': imagemUrl,
      'logoMercadoUrl': logoMercadoUrl,
      'inicioProgramado': inicioProgramado?.millisecondsSinceEpoch,
      'fimProgramado': fimProgramado?.millisecondsSinceEpoch,
      'ehRelampago': ehRelampago,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      nome: map['nome'] ?? '',
      preco: (map['preco'] ?? 0).toDouble(),
      quantidade: (map['quantidade'] ?? 1).toDouble(),
      unidadeMedida: map['unidadeMedida'] ?? 'un',
      comprado: map['comprado'] ?? false,
      categoria: map['categoria'] ?? 'Geral',
      mercado: map['mercado'] ?? 'Sem mercado',
      endereco: map['endereco'] ?? 'Endereço não informado',
      ehOferta: map['ehOferta'] ?? true,
      enquantoDurar: map['enquantoDurar'] ?? false,
      validade: map['validade'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['validade'])
          : null,
      imagemUrl: map['imagemUrl'] ?? '',
      logoMercadoUrl: map['logoMercadoUrl'] ?? '',
      inicioProgramado: map['inicioProgramado'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['inicioProgramado'])
          : null,
      fimProgramado: map['fimProgramado'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['fimProgramado'])
          : null,
      ehRelampago: map['ehRelampago'] ?? false,
      latitude: map['latitude'] != null
          ? (map['latitude'] as num).toDouble()
          : null,
      longitude: map['longitude'] != null
          ? (map['longitude'] as num).toDouble()
          : null,
    );
  }

  String get nomeNormalizado {
    return nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
