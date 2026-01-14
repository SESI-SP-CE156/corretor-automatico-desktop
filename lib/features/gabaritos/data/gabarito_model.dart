class GabaritoModelo {
  final int? id;
  final String nome;
  final String nomeFolhaModelo;
  final String caminhoImagem;
  final String anosExibicao; // Ex: "9º EM"
  final int qtdPerguntas;
  final String materia;
  final int? anoId; // <--- NOVO CAMPO OBRIGATÓRIO PARA O FILTRO

  GabaritoModelo({
    this.id,
    required this.nome,
    required this.nomeFolhaModelo,
    required this.caminhoImagem,
    required this.anosExibicao,
    required this.qtdPerguntas,
    required this.materia,
    this.anoId,
  });

  factory GabaritoModelo.fromMap(Map<String, dynamic> map) {
    return GabaritoModelo(
      id: map['GAB_ID'],
      nome: map['GAB_NOME'] ?? 'Gabarito sem nome',
      nomeFolhaModelo: map['FOM_NOME'] ?? 'Desconhecido',
      caminhoImagem: map['FOM_CAMINHO'] ?? '',
      anosExibicao: map['ANOS_LISTA'] ?? 'Geral',
      qtdPerguntas: map['GAB_QUANTIDADE_PERGUNTAS'] ?? 0,
      materia: map['MAT_NOME'] ?? 'Geral',
      anoId: map['FK_ANOS_ANO_ID'], // <--- Lendo do banco
    );
  }
}
