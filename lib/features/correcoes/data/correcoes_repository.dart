import 'package:corretor_desktop/core/database/db_helper.dart';
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
}
