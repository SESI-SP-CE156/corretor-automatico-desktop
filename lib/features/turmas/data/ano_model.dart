class Ano {
  final int id;
  final int numero;
  final String categoria;

  Ano({required this.id, required this.numero, required this.categoria});

  factory Ano.fromMap(Map<String, dynamic> map) {
    return Ano(
      id: map['ANO_ID'],
      numero: map['ANO_NUMERO'],
      categoria: map['ANO_CATEGORIA'],
    );
  }

  // Helper para exibição: "9º Ano - Fundamental"
  String get nomeExibicao =>
      '$numeroº ${categoria == "ENSINO MÉDIO" ? "EM" : "Ano"}';
}
