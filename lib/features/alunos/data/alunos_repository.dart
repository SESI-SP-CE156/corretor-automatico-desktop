import 'package:corretor_desktop/core/database/db_helper.dart';
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class AlunosRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  Future<List<Aluno>> getAllAlunos() async {
    final db = await _db;

    // JOIN complexo para pegar Nome da Turma (Ex: "9º A" ou "3º EM B")
    final result = await db.rawQuery('''
      SELECT 
        A.*, 
        (CAST(AN.ANO_NUMERO AS TEXT) || 'º ' || 
         CASE WHEN AN.ANO_CATEGORIA = 'ENSINO MÉDIO' THEN 'EM' ELSE '' END || 
         ' ' || T.TUR_LETRA) as NOME_TURMA
      FROM ALUNOS A
      LEFT JOIN TURMAS T ON A.FK_TURMAS_TUR_ID = T.TUR_ID
      LEFT JOIN ANOS AN ON T.FK_ANOS_ANO_ID = AN.ANO_ID
      ORDER BY A.ALU_NOME
    ''');

    return result.map((map) => Aluno.fromMap(map)).toList();
  }

  // ... (mantenha os métodos create, delete, batch)

  // Deletar aluno
  Future<int> deleteAluno(int id) async {
    final db = await _db;
    return await db.delete('ALUNOS', where: 'ALU_ID = ?', whereArgs: [id]);
  }

  // Criar um aluno
  Future<int> createAluno(Aluno aluno) async {
    final db = await _db;
    return await db.insert('ALUNOS', aluno.toMap());
  }

  // Criar vários alunos (Transação para o CSV)
  Future<void> createBatchAlunos(List<Aluno> alunos) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var aluno in alunos) {
        await txn.insert('ALUNOS', aluno.toMap());
      }
    });
  }

  Future<void> formarAluno(int alunoId) async {
    final db = await _db;
    await db.update(
      'ALUNOS',
      {'ALU_STATUS': 'Formado'}, // Mantém a turma, só muda o status
      where: 'ALU_ID = ?',
      whereArgs: [alunoId],
    );
  }

  Future<void> registrarEvasao(int alunoId) async {
    final db = await _db;
    await db.update(
      'ALUNOS',
      {'ALU_STATUS': 'Evasão'},
      where: 'ALU_ID = ?',
      whereArgs: [alunoId],
    );
  }
}
