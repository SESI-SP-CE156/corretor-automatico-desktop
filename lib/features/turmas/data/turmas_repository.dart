import 'package:corretor_desktop/core/database/db_helper.dart';
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:corretor_desktop/features/turmas/data/ano_model.dart';
import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TurmasRepository {
  Future<Database> get _db async => await DatabaseHelper.instance.database;

  // --- ANOS (Para preencher o Dropdown da tela de cadastro) ---
  Future<List<Ano>> getAnos() async {
    final db = await _db;
    final result = await db.query('ANOS', orderBy: 'ANO_CATEGORIA, ANO_NUMERO');
    return result.map((map) => Ano.fromMap(map)).toList();
  }

  // --- TURMAS (Tela 1: Dashboard) ---
  Future<List<Turma>> getAllTurmas() async {
    final db = await _db;
    // Fazemos um JOIN para saber qual é o Ano da turma (Ex: 9 + A)
    final result = await db.rawQuery('''
      SELECT T.*, (CAST(A.ANO_NUMERO AS TEXT) || 'º ' || A.ANO_CATEGORIA) as ANO_DESCRICAO
      FROM TURMAS T
      INNER JOIN ANOS A ON T.FK_ANOS_ANO_ID = A.ANO_ID
    ''');
    return result.map((map) => Turma.fromMap(map)).toList();
  }

  // Criar Turma (Tela 1 -> Modal Criar)
  Future<int> createTurma(Turma turma) async {
    final db = await _db;
    return await db.insert('TURMAS', turma.toMap());
  }

  // Excluir Turma (Tela 3: Modal Excluir)
  Future<int> deleteTurma(int id) async {
    final db = await _db;
    // Como configuramos ON DELETE CASCADE, os alunos serão apagados automaticamente
    return await db.delete('TURMAS', where: 'TUR_ID = ?', whereArgs: [id]);
  }

  // --- ALUNOS (Tela 4: Detalhes da Turma) ---
  Future<List<Aluno>> getAlunosByTurma(int turmaId) async {
    final db = await _db;
    final result = await db.query(
      'ALUNOS',
      // FILTRO ADICIONADO: Traz apenas alunos ativos
      where: 'FK_TURMAS_TUR_ID = ? AND ALU_STATUS = ?',
      whereArgs: [turmaId, 'Ativo'],
      orderBy: 'ALU_NOME',
    );
    return result.map((map) => Aluno.fromMap(map)).toList();
  }

  Future<int> addAluno(Aluno aluno) async {
    final db = await _db;
    return await db.insert('ALUNOS', aluno.toMap());
  }

  // Mover Alunos (Tela 2: Modal Mover)
  Future<void> moveAlunos(List<int> alunoIds, int novaTurmaId) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (var id in alunoIds) {
        await txn.update(
          'ALUNOS',
          {'FK_TURMAS_TUR_ID': novaTurmaId},
          where: 'ALU_ID = ?',
          whereArgs: [id],
        );
      }
    });
  }

  // Buscar uma turma específica (para exibir no título/breadcrumbs)
  Future<Turma?> getTurmaById(int id) async {
    final db = await _db;
    // Faz o JOIN para pegar o nome do ano também
    final result = await db.rawQuery(
      '''
      SELECT T.*, (CAST(A.ANO_NUMERO AS TEXT) || 'º ' || A.ANO_CATEGORIA) as ANO_DESCRICAO
      FROM TURMAS T
      INNER JOIN ANOS A ON T.FK_ANOS_ANO_ID = A.ANO_ID
      WHERE T.TUR_ID = ?
    ''',
      [id],
    );

    if (result.isNotEmpty) {
      return Turma.fromMap(result.first);
    }
    return null;
  }

  // Deletar Aluno
  Future<int> deleteAluno(int id) async {
    final db = await _db;
    return await db.delete('ALUNOS', where: 'ALU_ID = ?', whereArgs: [id]);
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

  Future<List<Turma>> getTurmasByAno(int anoId) async {
    final db = await _db;
    final result = await db.rawQuery(
      '''
      SELECT T.*, 
             (CAST(A.ANO_NUMERO AS TEXT) || 'º ' || REPLACE(A.ANO_CATEGORIA, 'ENSINO MÉDIO', 'EM')) as ANO_DESCRICAO
      FROM TURMAS T
      INNER JOIN ANOS A ON T.FK_ANOS_ANO_ID = A.ANO_ID
      WHERE T.FK_ANOS_ANO_ID = ?
      ORDER BY T.TUR_LETRA
    ''',
      [anoId],
    );

    return result.map((m) => Turma.fromMap(m)).toList();
  }
}
