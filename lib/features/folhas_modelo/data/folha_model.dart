import 'dart:convert';

class FolhaModelo {
  final int? id;
  final String nome;
  final String imagemModeloPath; // No banco é FOM_CAMINHO
  final Map<String, dynamic>
  layoutConfig; // No banco é FOM_LAYOUT_CONFIG (JSON)

  // Campo apenas para leitura (não vai para o banco na tabela principal)
  final String? anosExibicao;

  FolhaModelo({
    this.id,
    required this.nome,
    required this.imagemModeloPath,
    required this.layoutConfig,
    this.anosExibicao,
  });

  // Converter para Map (Banco de Dados)
  Map<String, dynamic> toMap() {
    return {
      'FOM_ID': id,
      'FOM_NOME': nome,
      'FOM_CAMINHO': imagemModeloPath,
      // CORREÇÃO: FOM_LAYTOU_CONFIG -> FOM_LAYOUT_CONFIG
      'FOM_LAYOUT_CONFIG': jsonEncode(layoutConfig),
    };
  }

  // Criar a partir do Map (Banco de Dados)
  factory FolhaModelo.fromMap(Map<String, dynamic> map) {
    return FolhaModelo(
      id: map['FOM_ID'],
      nome: map['FOM_NOME'],
      imagemModeloPath: map['FOM_CAMINHO'],

      // CORREÇÃO: FOM_LAYTOU_CONFIG -> FOM_LAYOUT_CONFIG
      layoutConfig: map['FOM_LAYOUT_CONFIG'] is String
          ? jsonDecode(map['FOM_LAYOUT_CONFIG'])
          : (map['FOM_LAYOUT_CONFIG'] ?? {}),

      anosExibicao: map['ANOS_LISTA'],
    );
  }
}
