class CorrecaoListModel {
  final int gabaritoId;
  final String gabaritoNome;
  final String folhaNome;
  final String folhaImagem;
  final String anoTurma;
  final String materia;
  final int totalCorrigidas;

  CorrecaoListModel({
    required this.gabaritoId,
    required this.gabaritoNome,
    required this.folhaNome,
    required this.folhaImagem,
    required this.anoTurma,
    required this.materia,
    required this.totalCorrigidas,
  });

  factory CorrecaoListModel.fromMap(Map<String, dynamic> map) {
    return CorrecaoListModel(
      gabaritoId: map['GAB_ID'],
      gabaritoNome: map['GAB_NOME'] ?? 'Sem Nome',
      folhaNome: map['FOM_NOME'] ?? '',
      folhaImagem: map['FOM_CAMINHO'] ?? '',
      anoTurma: map['ANO_DESCRICAO'] ?? 'Geral',
      materia: map['MAT_NOME'] ?? '',
      totalCorrigidas: map['TOTAL_CORRIGIDAS'] ?? 0,
    );
  }
}
