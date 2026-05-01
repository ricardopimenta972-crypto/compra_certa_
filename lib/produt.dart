class Produto {
  String nome;
  double preco;
  bool comprado;
  String categoria;
  String mercado;
  bool ehOferta;
  bool enquantoDurar;
  DateTime? validade;
  String imagemUrl;
  DateTime? inicioProgramado;
  DateTime? fimProgramado;
  bool ehRelampago;

  Produto({
    required this.nome,
    required this.preco,
    this.comprado = false,
    this.categoria = 'Geral',
    this.mercado = 'Sem mercado',
    this.ehOferta = false,
    this.enquantoDurar = false,
    this.validade,
    this.imagemUrl = '',
    this.inicioProgramado,
    this.fimProgramado,
    this.ehRelampago = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'preco': preco,
      'comprado': comprado,
      'categoria': categoria,
      'mercado': mercado,
      'ehOferta': ehOferta,
      'enquantoDurar': enquantoDurar,
      'validade': validade?.millisecondsSinceEpoch,
      'imagemUrl': imagemUrl,
      'inicioProgramado': inicioProgramado?.millisecondsSinceEpoch,
      'fimProgramado': fimProgramado?.millisecondsSinceEpoch,
      'ehRelampago': ehRelampago,
    };
  }

  factory Produto.fromMap(Map<String, dynamic> map) {
    return Produto(
      nome: map['nome'] ?? '',
      preco: (map['preco'] ?? 0).toDouble(),
      comprado: map['comprado'] ?? false,
      categoria: map['categoria'] ?? 'Geral',
      mercado: map['mercado'] ?? 'Sem mercado',
      ehOferta: map['ehOferta'] ?? false,
      enquantoDurar: map['enquantoDurar'] ?? false,
      validade: map['validade'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['validade'])
          : null,
      imagemUrl: map['imagemUrl'] ?? '',
      inicioProgramado: map['inicioProgramado'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['inicioProgramado'])
          : null,
      fimProgramado: map['fimProgramado'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['fimProgramado'])
          : null,
      ehRelampago: map['ehRelampago'] ?? false,
    );
  }

  String get nomeNormalizado {
    return nome.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }
}
