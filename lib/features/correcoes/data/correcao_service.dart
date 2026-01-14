import 'dart:convert'; // Necessário para jsonDecode
import 'dart:io';
import 'dart:ui' as ui;

import 'package:corretor_desktop/core/database/db_helper.dart';
import 'package:corretor_desktop/features/correcoes/data/python_service.dart';
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class CorrecaoService {
  Future<Database> get _db async => await DatabaseHelper.instance.database;
  final _python = PythonService();

  /// 1. Processar PDF: Separa as páginas em imagens temporárias
  Future<List<File>> extrairPaginasDoPdf(String pdfPath) async {
    final doc = await PdfDocument.openFile(pdfPath);
    final List<File> imagens = [];
    final dir = await getApplicationSupportDirectory();

    final sessionDir = Directory(
      p.join(
        dir.path,
        'temp_correcao_${DateTime.now().millisecondsSinceEpoch}',
      ),
    );
    await sessionDir.create();

    try {
      for (int i = 0; i < doc.pages.length; i++) {
        final page = doc.pages[i];

        final pdfImage = await page.render(
          width: (page.width).toInt(),
          height: (page.height).toInt(),
        );

        if (pdfImage != null) {
          final image = await pdfImage.createImage();

          final byteData = await image.toByteData(
            format: ui.ImageByteFormat.png,
          );

          if (byteData != null) {
            final file = File(p.join(sessionDir.path, 'pag_${i + 1}.png'));
            await file.writeAsBytes(byteData.buffer.asUint8List());
            imagens.add(file);
          }
        }
      }
    } finally {
      doc.dispose();
    }
    return imagens;
  }

  /// 2. Buscar Alunos da Série/Ano do Gabarito
  Future<List<Aluno>> getAlunosCompativeis(int gabaritoId) async {
    final db = await _db;

    final gabarito = await db.query(
      'GABARITOS',
      columns: ['FK_ANOS_ANO_ID'],
      where: 'GAB_ID = ?',
      whereArgs: [gabaritoId],
    );

    if (gabarito.isEmpty) return [];
    final anoId = gabarito.first['FK_ANOS_ANO_ID'];

    final result = await db.rawQuery(
      '''
      SELECT A.*, T.TUR_LETRA 
      FROM ALUNOS A
      INNER JOIN TURMAS T ON A.FK_TURMAS_TUR_ID = T.TUR_ID
      WHERE T.FK_ANOS_ANO_ID = ? AND A.ALU_STATUS = 'Ativo'
      ORDER BY A.ALU_NOME
    ''',
      [anoId],
    );

    return result.map((m) => Aluno.fromMap(m)).toList();
  }

  /// 3. Buscar o Gabarito Oficial
  Future<Map<int, String>> getGabaritoOficial(int gabaritoId) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT ALT.ALT_ALTERNATIVA
      FROM ALTERNATIVAS_GABARITO AG
      INNER JOIN ALTERNATIVAS ALT ON AG.FK_ALTERNATIVAS_ALT_ID = ALT.ALT_ID
      WHERE AG.FK_GABARITOS_GAB_ID = ?
      ORDER BY AG.ALG_ID ASC
    ''',
      [gabaritoId],
    );

    final Map<int, String> mapa = {};
    for (int i = 0; i < result.length; i++) {
      mapa[i + 1] = result[i]['ALT_ALTERNATIVA'] as String;
    }
    return mapa;
  }

  /// Helper: Buscar Layout de Configuração da Folha Modelo
  Future<Map<String, dynamic>> _getLayoutConfig(int gabaritoId) async {
    final db = await _db;
    // CORREÇÃO AQUI: Usando os nomes corretos das colunas (FOM_LAYOUT_CONFIG e FOM_ID)
    final result = await db.rawQuery(
      '''
      SELECT F.FOM_LAYOUT_CONFIG
      FROM FOLHAS_MODELO F
      INNER JOIN GABARITOS G ON G.FK_FOLHAS_MODELO_FOM_ID = F.FOM_ID
      WHERE G.GAB_ID = ?
    ''',
      [gabaritoId],
    );

    if (result.isNotEmpty && result.first['FOM_LAYOUT_CONFIG'] != null) {
      final jsonString = result.first['FOM_LAYOUT_CONFIG'] as String;
      try {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        throw Exception("Erro ao decodificar JSON do layout da folha: $e");
      }
    }
    throw Exception(
      'Layout de folha-modelo não encontrado para o Gabarito ID: $gabaritoId',
    );
  }

  /// 4. Calcular Nota
  Future<double> calcularNota(int gabaritoId, int acertos) async {
    final db = await _db;

    final regras = await db.query(
      'REGRAS_NOTAS',
      where: 'FK_GABARITOS_GAB_ID = ?',
      whereArgs: [gabaritoId],
    );

    if (regras.isNotEmpty) {
      for (var r in regras) {
        int inicio = r['RNO_INICIO'] as int;
        int fim = r['RNO_FIM'] as int;
        if (acertos >= inicio && acertos <= fim) {
          return (r['RNO_NOTA'] as num).toDouble();
        }
      }
    }

    final gabData = await db.query(
      'GABARITOS',
      columns: ['GAB_QUANTIDADE_PERGUNTAS'],
      where: 'GAB_ID = ?',
      whereArgs: [gabaritoId],
    );

    if (gabData.isNotEmpty) {
      int total = gabData.first['GAB_QUANTIDADE_PERGUNTAS'] as int;
      if (total == 0) return 0.0;
      return (acertos / total) * 10.0;
    }

    return 0.0;
  }

  /// 5. Salvar Correção
  Future<void> salvarCorrecao({
    required int alunoId,
    required int gabaritoId,
    required double nota,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      final gabData = await txn.query(
        'GABARITOS',
        where: 'GAB_ID = ?',
        whereArgs: [gabaritoId],
      );
      final folhaId = gabData.first['FK_FOLHAS_MODELO_FOM_ID'];
      final materiaId = gabData.first['FK_MATERIAS_MAT_ID'];

      int? provaId;
      final provas = await txn.query(
        'PROVAS',
        where: 'FK_GABARITOS_GAB_ID = ?',
        whereArgs: [gabaritoId],
        limit: 1,
      );

      if (provas.isNotEmpty) {
        provaId = provas.first['PRO_ID'] as int;
      } else {
        provaId = await txn.insert('PROVAS', {
          'FK_GABARITOS_GAB_ID': gabaritoId,
          'FK_FOLHAS_MODELO_FOM_ID': folhaId,
        });
      }

      final notasAntigas = await txn.query(
        'NOTAS',
        where: 'FK_ALUNOS_ALU_ID = ? AND FK_PROVAS_PRO_ID = ?',
        whereArgs: [alunoId, provaId],
      );

      if (notasAntigas.isNotEmpty) {
        await txn.update(
          'NOTAS',
          {'NOT_NOTA': nota},
          where: 'NOT_ID = ?',
          whereArgs: [notasAntigas.first['NOT_ID']],
        );
      } else {
        await txn.insert('NOTAS', {
          'NOT_NOTA': nota,
          'FK_ALUNOS_ALU_ID': alunoId,
          'FK_MATERIAS_MAT_ID': materiaId,
          'FK_PROVAS_PRO_ID': provaId,
        });
      }
    });
  }

  Future<List<Aluno>> getAlunosPorTurma(int turmaId) async {
    final db = await _db;
    final result = await db.query(
      'ALUNOS',
      where: 'FK_TURMAS_TUR_ID = ? AND ALU_STATUS = ?',
      whereArgs: [turmaId, 'Ativo'],
      orderBy: 'ALU_NOME',
    );
    return result.map((m) => Aluno.fromMap(m)).toList();
  }

  /// Processa uma única página (imagem da prova)
  Future<Map<String, dynamic>> processarPagina({
    required File imagem,
    required int gabaritoId,
    required int qtdQuestoes,
  }) async {
    // 1. Busca gabarito oficial (Int -> String)
    final gabaritoOficialMapInt = await getGabaritoOficial(gabaritoId);

    // Converte para (String -> String) para o JSON
    final Map<String, String> gabaritoPayload = gabaritoOficialMapInt.map(
      (key, value) => MapEntry(key.toString(), value),
    );

    // 2. Busca Layout Config do Banco
    final layoutConfig = await _getLayoutConfig(gabaritoId);

    // 3. Chama Python Service (Método corrigido: corrigirProva)
    final resultadoPython = await _python.corrigirProva(
      imagePath: imagem.path,
      layoutConfig: layoutConfig,
      gabarito: gabaritoPayload,
    );

    if (resultadoPython['sucesso'] == true) {
      // O Python retorna as chaves como Strings ("1", "2"), convertemos para int
      final respostasRaw =
          resultadoPython['respostas_detectadas'] as Map<String, dynamic>;
      final Map<int, String> respostasFormatadas = {};

      respostasRaw.forEach((k, v) {
        final keyInt = int.tryParse(k);
        if (keyInt != null) {
          respostasFormatadas[keyInt] = v.toString();
        }
      });

      final int acertos = resultadoPython['acertos'] as int;

      // 4. Calcula Nota usando a lógica do Flutter
      final double notaCalculada = await calcularNota(gabaritoId, acertos);

      return {
        'respostas': respostasFormatadas,
        'imagem': File(resultadoPython['caminho_imagem_corrigida']),
        'acertos': acertos,
        'nota': notaCalculada,
      };
    } else {
      throw Exception(
        resultadoPython['erro'] ??
            "Erro desconhecido ao processar prova via Python.",
      );
    }
  }
}
