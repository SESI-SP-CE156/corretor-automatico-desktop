import 'package:corretor_desktop/core/database/db_helper.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/folha_model.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/regra_nota_model.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabarito_model.dart';
import 'package:corretor_desktop/features/gabaritos/data/materia_model.dart';
import 'package:corretor_desktop/features/turmas/data/ano_model.dart';
import 'package:sqflite/sqflite.dart';

class GabaritosRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<GabaritoModelo>> getAllGabaritos() async {
    final db = await _db;
    final result = await db.rawQuery('''
      SELECT 
        G.GAB_ID,
        G.GAB_NOME,
        G.GAB_QUANTIDADE_PERGUNTAS,
        G.FK_ANOS_ANO_ID, -- <--- Adicionado
        F.FOM_NOME,
        F.FOM_CAMINHO,
        M.MAT_NOME,
        (CAST(A.ANO_NUMERO AS TEXT) || 'º ' || REPLACE(A.ANO_CATEGORIA, 'ENSINO MÉDIO', 'EM')) as ANOS_LISTA
      FROM GABARITOS G
      INNER JOIN FOLHAS_MODELO F ON G.FK_FOLHAS_MODELO_FOM_ID = F.FOM_ID
      INNER JOIN MATERIAS M ON G.FK_MATERIAS_MAT_ID = M.MAT_ID
      LEFT JOIN ANOS A ON G.FK_ANOS_ANO_ID = A.ANO_ID
      ORDER BY G.GAB_ID DESC
    ''');
    return result.map((m) => GabaritoModelo.fromMap(m)).toList();
  }

  Future<int> deleteGabarito(int id) async {
    final db = await _db;
    return await db.delete('GABARITOS', where: 'GAB_ID = ?', whereArgs: [id]);
  }

  Future<List<FolhaModelo>> getFolhasModelo() async {
    final db = await _db;
    final result = await db.query('FOLHAS_MODELO');
    return result.map((m) => FolhaModelo.fromMap(m)).toList();
  }

  // Busca matérias (se vazio, insere padrão)
  Future<List<Materia>> getMaterias() async {
    final db = await _db;
    var result = await db.query('MATERIAS');

    if (result.isEmpty) {
      // Seed inicial de matérias se não existirem
      await db.insert('MATERIAS', {'MAT_ID': 'MAT', 'MAT_NOME': 'Matemática'});
      await db.insert('MATERIAS', {'MAT_ID': 'POR', 'MAT_NOME': 'Português'});
      await db.insert('MATERIAS', {'MAT_ID': 'HIS', 'MAT_NOME': 'História'});
      await db.insert('MATERIAS', {'MAT_ID': 'GEO', 'MAT_NOME': 'Geografia'});
      await db.insert('MATERIAS', {'MAT_ID': 'CIE', 'MAT_NOME': 'Ciências'});
      result = await db.query('MATERIAS');
    }

    return result.map((m) => Materia.fromMap(m)).toList();
  }

  Future<void> _ensureAlternativas(DatabaseExecutor txn) async {
    final count = Sqflite.firstIntValue(
      await txn.rawQuery('SELECT COUNT(*) FROM ALTERNATIVAS'),
    );
    if (count == 0) {
      final alts = ['A', 'B', 'C', 'D', 'E'];
      for (var i = 0; i < alts.length; i++) {
        await txn.insert('ALTERNATIVAS', {
          'ALT_ALTERNATIVA': alts[i],
          'ALT_NUMERO': i + 1,
        });
      }
    }
  }

  Future<List<Ano>> getAnosByFolha(int folhaId) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT A.* FROM ANOS A
      INNER JOIN ANO_FOLHAS_MODELO AFM ON A.ANO_ID = AFM.FK_ANOS_ANO_ID
      WHERE AFM.FK_FOLHAS_MODELO_FOM_ID = ?
      ORDER BY A.ANO_CATEGORIA, A.ANO_NUMERO
    ''',
      [folhaId],
    );

    return result.map((m) => Ano.fromMap(m)).toList();
  }

  // Salvar Gabarito
  Future<void> createGabarito({
    required String nome,
    required String materiaId,
    required int folhaId,
    required int anoId, // <--- Novo Parâmetro
    required int qtdQuestoes,
    required Map<int, String> respostas,
    required List<RegraNota> regras,
  }) async {
    final db = await _db;

    await db.transaction((txn) async {
      await _ensureAlternativas(txn);

      final gabId = await txn.insert('GABARITOS', {
        'GAB_NOME': nome,
        'GAB_QUANTIDADE_PERGUNTAS': qtdQuestoes,
        'FK_MATERIAS_MAT_ID': materiaId, // Matéria registrada aqui
        'FK_FOLHAS_MODELO_FOM_ID': folhaId,
        'FK_ANOS_ANO_ID': anoId,
      });

      for (int i = 1; i <= qtdQuestoes; i++) {
        final letra = respostas[i];
        if (letra != null) {
          final altResult = await txn.query(
            'ALTERNATIVAS',
            where: 'ALT_ALTERNATIVA = ?',
            whereArgs: [letra],
          );
          if (altResult.isNotEmpty) {
            await txn.insert('ALTERNATIVAS_GABARITO', {
              'FK_GABARITOS_GAB_ID': gabId,
              'FK_ALTERNATIVAS_ALT_ID': altResult.first['ALT_ID'],
            });
          }
        }
      }

      for (var regra in regras) {
        await txn.insert('REGRAS_NOTAS', {
          'RNO_INICIO': regra.inicio,
          'RNO_FIM': regra.fim,
          'RNO_NOTA': regra.nota,
          'FK_GABARITOS_GAB_ID': gabId, // Vinculado ao Gabarito
        });
      }
    });
  }
}
