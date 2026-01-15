class AlunoNotaDto {
  final String alunoNome;
  final double nota;
  final String? caminhoImagem;
  final String? caminhoImagemCorrigida;
  final int totalAcertos;

  AlunoNotaDto({
    required this.alunoNome,
    required this.nota,
    this.caminhoImagem,
    this.caminhoImagemCorrigida,
    this.totalAcertos = 0,
  });

  factory AlunoNotaDto.fromMap(Map<String, dynamic> map) {
    return AlunoNotaDto(
      alunoNome: map['ALU_NOME'] ?? 'Desconhecido',
      nota: (map['NOT_NOTA'] as num?)?.toDouble() ?? 0.0,
      caminhoImagem: map['NOT_CAMINHO_IMAGEM'],
      caminhoImagemCorrigida: map['NOT_CAMINHO_CORRIGIDA'],
      totalAcertos: map['TOTAL_ACERTOS'] ?? 0,
    );
  }
}

class EstatisticaQuestaoDto {
  final int numeroQuestao;
  final String respostaCorreta;
  final String respostaMaisMarcada;
  final double percentualAcerto;

  EstatisticaQuestaoDto({
    required this.numeroQuestao,
    required this.respostaCorreta,
    required this.respostaMaisMarcada,
    required this.percentualAcerto,
  });
}

class EstatisticaResumoDto {
  final String nomeProva;
  final String caminhoImagemModelo;
  final double mediaNota;

  EstatisticaResumoDto({
    required this.nomeProva,
    required this.caminhoImagemModelo,
    required this.mediaNota,
  });

  factory EstatisticaResumoDto.fromMap(Map<String, dynamic> map) {
    return EstatisticaResumoDto(
      nomeProva: map['GAB_NOME'] ?? 'Sem Nome',
      caminhoImagemModelo: map['FOM_CAMINHO'] ?? '',
      mediaNota: (map['MEDIA_NOTA'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
