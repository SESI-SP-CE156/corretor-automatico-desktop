class Aluno {
  final int? id;
  final String nome;
  final String? rm;
  final int turmaId;
  final String? nomeTurma;
  final String status; // Agora é um campo real do banco

  Aluno({
    this.id,
    required this.nome,
    this.rm,
    required this.turmaId,
    this.nomeTurma,
    this.status = 'Ativo', // Valor padrão
  });

  Map<String, dynamic> toMap() {
    return {
      'ALU_ID': id,
      'ALU_NOME': nome,
      'ALU_RM': rm,
      'FK_TURMAS_TUR_ID': turmaId,
      'ALU_STATUS': status, // Salvando no banco
    };
  }

  factory Aluno.fromMap(Map<String, dynamic> map) {
    return Aluno(
      id: map['ALU_ID'],
      nome: map['ALU_NOME'],
      rm: map['ALU_RM'],
      turmaId: map['FK_TURMAS_TUR_ID'],
      nomeTurma: map['NOME_TURMA'],
      status: map['ALU_STATUS'] ?? 'Ativo', // Lendo do banco
    );
  }
}
