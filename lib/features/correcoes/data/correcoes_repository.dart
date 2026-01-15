import 'package:corretor_desktop/core/database/db_helper.dart';
import 'package:corretor_desktop/features/correcoes/data/correcao_detalhes_dto.dart';
import 'package:corretor_desktop/features/correcoes/data/correcao_list_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CorrecoesRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<CorrecaoListModel>> getResumoCorrecoes() async {
    final db = await _db;

    // A mágica acontece nos INNER JOINS com PROVAS e NOTAS.
    // Se não tiver nota, o gabarito não vem no resultado.
    final result = await db.rawQuery('''
      SELECT 
        G.GAB_ID,
        G.GAB_NOME,
        F.FOM_NOME,
        F.FOM_CAMINHO,
        M.MAT_NOME,
        (CAST(A.ANO_NUMERO AS TEXT) || 'º ' || REPLACE(A.ANO_CATEGORIA, 'ENSINO MÉDIO', 'EM')) as ANO_DESCRICAO,
        COUNT(N.NOT_ID) as TOTAL_CORRIGIDAS
      FROM GABARITOS G
      INNER JOIN FOLHAS_MODELO F ON G.FK_FOLHAS_MODELO_FOM_ID = F.FOM_ID
      INNER JOIN MATERIAS M ON G.FK_MATERIAS_MAT_ID = M.MAT_ID
      LEFT JOIN ANOS A ON G.FK_ANOS_ANO_ID = A.ANO_ID
      
      -- Filtro: Só traz gabaritos que tenham provas com notas
      INNER JOIN PROVAS P ON P.FK_GABARITOS_GAB_ID = G.GAB_ID
      INNER JOIN NOTAS N ON N.FK_PROVAS_PRO_ID = P.PRO_ID
      
      GROUP BY G.GAB_ID
      ORDER BY G.GAB_ID DESC
    ''');

    return result.map((m) => CorrecaoListModel.fromMap(m)).toList();
  }

  Future<void> deleteCorrecao(int gabaritoId) async {
    final db = await _db;

    await db.transaction((txn) async {
      // 1. Apaga as NOTAS vinculadas às provas deste gabarito
      await txn.rawDelete(
        '''
        DELETE FROM NOTAS 
        WHERE FK_PROVAS_PRO_ID IN (
          SELECT PRO_ID FROM PROVAS WHERE FK_GABARITOS_GAB_ID = ?
        )
      ''',
        [gabaritoId],
      );

      // 2. Apaga as PROVAS deste gabarito
      await txn.delete(
        'PROVAS',
        where: 'FK_GABARITOS_GAB_ID = ?',
        whereArgs: [gabaritoId],
      );
    });
  }

  Future<List<AlunoNotaDto>> getAlunosNotas(int gabaritoId) async {
    final db = await _db;

    // Assumindo estrutura atual. Para funcionar o download,
    // futuramente adicione a coluna NOT_CAMINHO_IMAGEM na tabela NOTAS.
    final result = await db.rawQuery(
      '''
      SELECT 
        A.ALU_NOME,
        N.NOT_NOTA,
        N.NOT_CAMINHO_IMAGEM,
        N.NOT_CAMINHO_CORRIGIDA, -- Added selection
        (SELECT COUNT(*) FROM RESPOSTAS_ALUNOS R 
         WHERE R.FK_PROVAS_PRO_ID = P.PRO_ID) as RESPOSTAS_REGISTRADAS 
      FROM NOTAS N
      INNER JOIN PROVAS P ON N.FK_PROVAS_PRO_ID = P.PRO_ID
      INNER JOIN ALUNOS A ON N.FK_ALUNOS_ALU_ID = A.ALU_ID
      WHERE P.FK_GABARITOS_GAB_ID = ?
      ORDER BY A.ALU_NOME ASC
    ''',
      [gabaritoId],
    );

    return result.map((m) => AlunoNotaDto.fromMap(m)).toList();
  }

  Future<List<EstatisticaQuestaoDto>> getEstatisticas(int gabaritoId) async {
    final db = await _db;

    // Busca gabarito oficial para saber quantas questões existem
    final gabaritoResult = await db.rawQuery(
      '''
      SELECT AG.ALG_NUMERO_QUESTAO, ALT.ALT_ALTERNATIVA
      FROM ALTERNATIVAS_GABARITO AG
      INNER JOIN ALTERNATIVAS ALT ON AG.FK_ALTERNATIVAS_ALT_ID = ALT.ALT_ID
      WHERE AG.FK_GABARITOS_GAB_ID = ?
      ORDER BY AG.ALG_NUMERO_QUESTAO
    ''',
      [gabaritoId],
    );

    // Mapa: Questão -> Letras Corretas (ex: 1 -> ['A'])
    final Map<int, List<String>> gabaritoMap = {};
    for (var row in gabaritoResult) {
      final q = row['ALG_NUMERO_QUESTAO'] as int;
      final letra = row['ALT_ALTERNATIVA'] as String;
      if (!gabaritoMap.containsKey(q)) gabaritoMap[q] = [];
      gabaritoMap[q]!.add(letra);
    }

    // 2. Busca TODAS as respostas de alunos para provas deste gabarito
    final respostasResult = await db.rawQuery(
      '''
      SELECT R.RES_NUMERO_QUESTAO, R.RES_RESPOSTA
      FROM RESPOSTAS_ALUNOS R
      INNER JOIN PROVAS P ON R.FK_PROVAS_PRO_ID = P.PRO_ID
      WHERE P.FK_GABARITOS_GAB_ID = ?
    ''',
      [gabaritoId],
    );

    // 3. Processamento em Memória (Dart)
    // Estrutura: Questão -> { TotalRespondido, Acertos, ContagemPorLetra }
    final Map<int, Map<String, int>> contagemLetras = {};
    final Map<int, int> totalRespondido = {};
    final Map<int, int> totalAcertos = {};

    for (var row in respostasResult) {
      final q = row['RES_NUMERO_QUESTAO'] as int;
      final resp = row['RES_RESPOSTA'] as String;

      // Inicializa contadores
      if (!contagemLetras.containsKey(q)) contagemLetras[q] = {};
      if (!totalRespondido.containsKey(q)) totalRespondido[q] = 0;
      if (!totalAcertos.containsKey(q)) totalAcertos[q] = 0;

      // Incrementa letra
      contagemLetras[q]![resp] = (contagemLetras[q]![resp] ?? 0) + 1;
      totalRespondido[q] = totalRespondido[q]! + 1;

      // Checa se acertou
      if (gabaritoMap.containsKey(q) && gabaritoMap[q]!.contains(resp)) {
        totalAcertos[q] = totalAcertos[q]! + 1;
      }
    }

    // 4. Monta lista final
    final List<EstatisticaQuestaoDto> lista = [];

    // Itera sobre as questões do gabarito para garantir ordem
    final sortedKeys = gabaritoMap.keys.toList()..sort();

    for (var q in sortedKeys) {
      final corretas = gabaritoMap[q] ?? [];
      final total = totalRespondido[q] ?? 0;
      final acertos = totalAcertos[q] ?? 0;

      // Calcula %
      double percentual = 0.0;
      if (total > 0) {
        percentual = acertos / total;
      }

      // Acha a mais marcada
      String maisMarcada = '-';
      int maxCount = -1;
      if (contagemLetras.containsKey(q)) {
        contagemLetras[q]!.forEach((letra, count) {
          if (count > maxCount) {
            maxCount = count;
            maisMarcada = letra;
          }
        });
      }

      lista.add(
        EstatisticaQuestaoDto(
          numeroQuestao: q,
          respostaCorreta: corretas.join(' ou '),
          respostaMaisMarcada: maisMarcada,
          percentualAcerto: percentual,
        ),
      );
    }

    return lista;
  }

  Future<EstatisticaResumoDto> getResumoEstatistico(int gabaritoId) async {
    final db = await _db;

    final result = await db.rawQuery(
      '''
      SELECT 
        G.GAB_NOME,
        F.FOM_CAMINHO,
        AVG(N.NOT_NOTA) as MEDIA_NOTA
      FROM GABARITOS G
      INNER JOIN FOLHAS_MODELO F ON G.FK_FOLHAS_MODELO_FOM_ID = F.FOM_ID
      LEFT JOIN PROVAS P ON P.FK_GABARITOS_GAB_ID = G.GAB_ID
      LEFT JOIN NOTAS N ON N.FK_PROVAS_PRO_ID = P.PRO_ID
      WHERE G.GAB_ID = ?
      GROUP BY G.GAB_ID
    ''',
      [gabaritoId],
    );

    if (result.isNotEmpty) {
      return EstatisticaResumoDto.fromMap(result.first);
    } else {
      throw Exception("Gabarito não encontrado");
    }
  }
}
