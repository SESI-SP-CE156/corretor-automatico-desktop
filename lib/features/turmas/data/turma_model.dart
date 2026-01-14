class Turma {
  final int? id;
  final String letra;
  final int anoId;
  // Campos opcionais para JOIN (exibição)
  final String? nomeAnoExibicao;

  Turma({
    this.id,
    required this.letra,
    required this.anoId,
    this.nomeAnoExibicao,
  });

  Map<String, dynamic> toMap() {
    return {'TUR_ID': id, 'TUR_LETRA': letra, 'FK_ANOS_ANO_ID': anoId};
  }

  factory Turma.fromMap(Map<String, dynamic> map) {
    return Turma(
      id: map['TUR_ID'],
      letra: map['TUR_LETRA'],
      anoId: map['FK_ANOS_ANO_ID'],
      // Se fizermos um JOIN, o banco retornará colunas extras
      nomeAnoExibicao: map['ANO_DESCRICAO'],
    );
  }
}
