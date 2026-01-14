import 'package:corretor_desktop/core/database/db_helper.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/folha_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class FolhasRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<FolhaModelo>> getAllFolhas() async {
    final db = await _db;

    // Utilizamos GROUP_CONCAT para transformar as múltiplas linhas de anos
    // em uma única string separada por vírgula.
    final result = await db.rawQuery('''
      SELECT 
        F.*,
        GROUP_CONCAT(CAST(A.ANO_NUMERO AS TEXT) || 'º', ', ') as ANOS_LISTA
      FROM FOLHAS_MODELO F
      LEFT JOIN ANO_FOLHAS_MODELO AFM ON F.FOM_ID = AFM.FK_FOLHAS_MODELO_FOM_ID
      LEFT JOIN ANOS A ON AFM.FK_ANOS_ANO_ID = A.ANO_ID
      GROUP BY F.FOM_ID
      ORDER BY F.FOM_NOME
    ''');

    return result.map((map) => FolhaModelo.fromMap(map)).toList();
  }

  Future<int> deleteFolha(int id) async {
    final db = await _db;
    return await db.delete(
      'FOLHAS_MODELO',
      where: 'FOM_ID = ?',
      whereArgs: [id],
    );
  }

  Future<int> createFolha(FolhaModelo folha, List<int> anosIds) async {
    final db = await _db;

    return await db.transaction((txn) async {
      // 1. Insere a Folha Modelo
      // O método toMap() já retorna as chaves corretas:
      // FOM_NOME, FOM_CAMINHO, FOM_LAYOUT_CONFIG
      final folhaId = await txn.insert('FOLHAS_MODELO', folha.toMap());

      // 2. Insere os relacionamentos com Anos (Tabela Pivô)
      for (final anoId in anosIds) {
        await txn.insert('ANO_FOLHAS_MODELO', {
          'FK_ANOS_ANO_ID': anoId,
          'FK_FOLHAS_MODELO_FOM_ID': folhaId,
        });
      }

      return folhaId;
    });
  }
}
