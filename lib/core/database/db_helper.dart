import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sesi_corretor.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final Directory appSupportDir = await getApplicationSupportDirectory();
    await appSupportDir.create(recursive: true);

    final path = join(appSupportDir.path, filePath);

    print('Banco de dados localizado em: $path');

    return await openDatabase(
      path,
      version: 10,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
  }

  // --- Lógica de Criação (Para novos usuários) ---
  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ANOS (
        ANO_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ANO_NUMERO INTEGER,
        ANO_CATEGORIA TEXT NOT NULL CHECK(ANO_CATEGORIA IN ('FUNDAMENTAL', 'ENSINO MÉDIO'))
      );
    ''');

    await db.execute('''
      CREATE TABLE TURMAS (
        TUR_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        TUR_LETRA TEXT,
        FK_ANOS_ANO_ID INTEGER,
        FOREIGN KEY (FK_ANOS_ANO_ID) REFERENCES ANOS (ANO_ID) ON DELETE CASCADE
      );
    ''');

    // 3. ATUALIZADO NO CREATE TAMBÉM (Para instalações limpas)
    await db.execute('''
      CREATE TABLE FOLHAS_MODELO (
        FOM_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        FOM_NOME TEXT,
        FOM_CAMINHO TEXT,
        FOM_LAYOUT_CONFIG TEXT NOT NULL
      );
    ''');

    await db.execute('''
      CREATE TABLE MATERIAS (
        MAT_ID TEXT PRIMARY KEY,
        MAT_NOME TEXT
      );
    ''');

    await db.execute('''
      CREATE TABLE GABARITOS (
        GAB_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        GAB_NOME TEXT, 
        GAB_QUANTIDADE_PERGUNTAS INTEGER,
        FK_MATERIAS_MAT_ID TEXT,
        FK_FOLHAS_MODELO_FOM_ID INTEGER,
        FK_ANOS_ANO_ID INTEGER, -- NOVA COLUNA
        FOREIGN KEY (FK_MATERIAS_MAT_ID) REFERENCES MATERIAS (MAT_ID) ON DELETE RESTRICT ON UPDATE CASCADE,
        FOREIGN KEY (FK_FOLHAS_MODELO_FOM_ID) REFERENCES FOLHAS_MODELO (FOM_ID) ON DELETE CASCADE ON UPDATE CASCADE,
        FOREIGN KEY (FK_ANOS_ANO_ID) REFERENCES ANOS (ANO_ID) ON DELETE CASCADE ON UPDATE CASCADE -- NOVA FK
      );
    ''');

    await db.execute('''
      CREATE TABLE ALUNOS (
        ALU_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ALU_RM TEXT,
        ALU_NOME TEXT,
        FK_TURMAS_TUR_ID INTEGER,
        ALU_STATUS TEXT DEFAULT 'Ativo' CHECK(ALU_STATUS IN ('Ativo', 'Formado', 'Evasão')),
        FOREIGN KEY (FK_TURMAS_TUR_ID) REFERENCES TURMAS (TUR_ID) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE ALTERNATIVAS (
        ALT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ALT_ALTERNATIVA TEXT NOT NULL CHECK(ALT_ALTERNATIVA IN ('A', 'B', 'C', 'D', 'E')),
        ALT_NUMERO INTEGER
      );
    ''');

    await db.execute('''
      CREATE TABLE ALTERNATIVAS_GABARITO (
        ALG_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        ALG_NUMERO_QUESTAO INTEGER,
        FK_GABARITOS_GAB_ID INTEGER,
        FK_ALTERNATIVAS_ALT_ID INTEGER,
        FOREIGN KEY (FK_GABARITOS_GAB_ID) REFERENCES GABARITOS (GAB_ID) ON DELETE CASCADE, 
        FOREIGN KEY (FK_ALTERNATIVAS_ALT_ID) REFERENCES ALTERNATIVAS (ALT_ID)
      );
    ''');

    await db.execute('''
      CREATE TABLE ANO_FOLHAS_MODELO (
        AFM_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        FK_ANOS_ANO_ID INTEGER,
        FK_FOLHAS_MODELO_FOM_ID INTEGER,
        FOREIGN KEY (FK_ANOS_ANO_ID) REFERENCES ANOS (ANO_ID) ON DELETE CASCADE, 
        FOREIGN KEY (FK_FOLHAS_MODELO_FOM_ID) REFERENCES FOLHAS_MODELO (FOM_ID) ON DELETE CASCADE ON UPDATE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE PROVAS (
        PRO_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        FK_GABARITOS_GAB_ID INTEGER,
        FK_FOLHAS_MODELO_FOM_ID INTEGER,
        FOREIGN KEY (FK_GABARITOS_GAB_ID) REFERENCES GABARITOS (GAB_ID) ON DELETE CASCADE,
        FOREIGN KEY (FK_FOLHAS_MODELO_FOM_ID) REFERENCES FOLHAS_MODELO (FOM_ID) ON DELETE CASCADE
      );
    ''');

    await db.execute('''
      CREATE TABLE NOTAS (
        NOT_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        NOT_NOTA REAL,
        FK_ALUNOS_ALU_ID INTEGER,
        FK_MATERIAS_MAT_ID TEXT,
        FK_PROVAS_PRO_ID INTEGER,
        FOREIGN KEY (FK_ALUNOS_ALU_ID) REFERENCES ALUNOS (ALU_ID) ON DELETE CASCADE,
        FOREIGN KEY (FK_MATERIAS_MAT_ID) REFERENCES MATERIAS (MAT_ID) ON DELETE CASCADE,
        FOREIGN KEY (FK_PROVAS_PRO_ID) REFERENCES PROVAS (PRO_ID) ON DELETE RESTRICT
      );
    ''');

    await db.execute('''
      CREATE TABLE REGRAS_NOTAS (
        RNO_ID INTEGER PRIMARY KEY AUTOINCREMENT,
        RNO_INICIO INTEGER,
        RNO_FIM INTEGER,
        RNO_NOTA REAL,
        FK_GABARITOS_GAB_ID INTEGER, -- Agora aponta para Gabarito
        FOREIGN KEY (FK_GABARITOS_GAB_ID) REFERENCES GABARITOS (GAB_ID) ON DELETE CASCADE
      );
    ''');

    // Insere dados iniciais...
    await _insertSeedData(db);
  }

  // --- Lógica de Atualização (Para quem já tem o app instalado) ---
  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print(
      "Atualizando banco de dados da versão $oldVersion para $newVersion...",
    );

    if (oldVersion < 2) {
      await db.execute(
        'ALTER TABLE FOLHAS_MODELO ADD COLUMN FOM_QTD_QUESTOES INTEGER DEFAULT 10',
      );
      print('Migração v2: Adicionada coluna FOM_QTD_QUESTOES.');
    }

    if (oldVersion < 3) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE ANO_FOLHAS_MODELO_NEW (
            AFM_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            FK_ANOS_ANO_ID INTEGER,
            FK_FOLHAS_MODELO_FOM_ID INTEGER,
            FOREIGN KEY (FK_ANOS_ANO_ID) REFERENCES ANOS (ANO_ID) ON DELETE CASCADE ON UPDATE CASCADE,
            FOREIGN KEY (FK_FOLHAS_MODELO_FOM_ID) REFERENCES FOLHAS_MODELO (FOM_ID) ON DELETE CASCADE ON UPDATE CASCADE
          );
        ''');
        await txn.execute('''
          INSERT INTO ANO_FOLHAS_MODELO_NEW (AFM_ID, FK_ANOS_ANO_ID, FK_FOLHAS_MODELO_FOM_ID)
          SELECT AFM_ID, FK_ANOS_ANO_ID, FK_FOLHAS_MODELO_FOM_ID FROM ANO_FOLHAS_MODELO;
        ''');
        await txn.execute('DROP TABLE ANO_FOLHAS_MODELO');
        await txn.execute(
          'ALTER TABLE ANO_FOLHAS_MODELO_NEW RENAME TO ANO_FOLHAS_MODELO',
        );
      });
      print('Migração v3: Tabela ANO_FOLHAS_MODELO recriada.');
    }

    if (oldVersion < 4) {
      await db.execute('''
        CREATE TABLE REGRAS_NOTAS (
          RNO_ID INTEGER PRIMARY KEY AUTOINCREMENT,
          RNO_INICIO INTEGER,
          RNO_FIM INTEGER,
          RNO_NOTA REAL,
          FK_FOLHAS_MODELO_FOM_ID INTEGER,
          FOREIGN KEY (FK_FOLHAS_MODELO_FOM_ID) REFERENCES FOLHAS_MODELO (FOM_ID) ON DELETE CASCADE
        );
      ''');
      print('Migração v4: Tabela REGRAS_NOTAS criada.');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE GABARITOS ADD COLUMN GAB_NOME TEXT');
      print('Migração v5: Coluna GAB_NOME adicionada.');
    }

    if (oldVersion < 6) {
      await db.execute(
        'ALTER TABLE GABARITOS ADD COLUMN FK_ANOS_ANO_ID INTEGER REFERENCES ANOS(ANO_ID) ON DELETE CASCADE',
      );
      print('Migração v6: Coluna FK_ANOS_ANO_ID adicionada.');
    }

    if (oldVersion < 7) {
      await db.transaction((txn) async {
        await txn.execute('''
          CREATE TABLE ALTERNATIVAS_GABARITO_NEW (
            ALG_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            FK_GABARITOS_GAB_ID INTEGER,
            FK_ALTERNATIVAS_ALT_ID INTEGER,
            FOREIGN KEY (FK_GABARITOS_GAB_ID) REFERENCES GABARITOS (GAB_ID) ON DELETE CASCADE,
            FOREIGN KEY (FK_ALTERNATIVAS_ALT_ID) REFERENCES ALTERNATIVAS (ALT_ID)
          );
        ''');
        await txn.execute('''
          INSERT INTO ALTERNATIVAS_GABARITO_NEW (ALG_ID, FK_GABARITOS_GAB_ID, FK_ALTERNATIVAS_ALT_ID)
          SELECT ALG_ID, FK_GABARITOS_GAB_ID, FK_ALTERNATIVAS_ALT_ID FROM ALTERNATIVAS_GABARITO;
        ''');
        await txn.execute('DROP TABLE ALTERNATIVAS_GABARITO');
        await txn.execute(
          'ALTER TABLE ALTERNATIVAS_GABARITO_NEW RENAME TO ALTERNATIVAS_GABARITO',
        );
      });
      print('Migração v7: ALTERNATIVAS_GABARITO recriada.');
    }

    if (oldVersion < 8) {
      print('Migração v8: Movendo REGRAS_NOTAS para GABARITOS...');
      await db.transaction((txn) async {
        try {
          await txn.execute(
            'ALTER TABLE REGRAS_NOTAS RENAME TO REGRAS_NOTAS_OLD',
          );
        } catch (e) {
          // Fallback se a tabela não existir
          await txn.execute(
            'CREATE TABLE REGRAS_NOTAS_OLD (RNO_ID INTEGER, RNO_INICIO INTEGER, RNO_FIM INTEGER, RNO_NOTA REAL, FK_FOLHAS_MODELO_FOM_ID INTEGER)',
          );
        }

        await txn.execute('''
          CREATE TABLE REGRAS_NOTAS (
            RNO_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            RNO_INICIO INTEGER,
            RNO_FIM INTEGER,
            RNO_NOTA REAL,
            FK_GABARITOS_GAB_ID INTEGER,
            FOREIGN KEY (FK_GABARITOS_GAB_ID) REFERENCES GABARITOS (GAB_ID) ON DELETE CASCADE
          );
        ''');

        // Tenta migrar dados se possível (Inner Join para pegar ID do gabarito via Folha)
        await txn.execute('''
          INSERT INTO REGRAS_NOTAS (RNO_INICIO, RNO_FIM, RNO_NOTA, FK_GABARITOS_GAB_ID)
          SELECT 
            RO.RNO_INICIO, 
            RO.RNO_FIM, 
            RO.RNO_NOTA, 
            G.GAB_ID 
          FROM REGRAS_NOTAS_OLD RO
          INNER JOIN GABARITOS G ON G.FK_FOLHAS_MODELO_FOM_ID = RO.FK_FOLHAS_MODELO_FOM_ID
        ''');

        await txn.execute('DROP TABLE REGRAS_NOTAS_OLD');
      });
    }

    // --- CORREÇÃO APLICADA AQUI ---
    if (oldVersion < 9) {
      print(
        'Migração v9: Removendo colunas da FOLHAS_MODELO (Com PRAGMA Fix)...',
      );

      // 1. Desliga verificação de Chaves Estrangeiras
      // Isso impede que GABARITOS e ANO_FOLHAS_MODELO apontem para "_OLD" quando renomearmos.
      await db.execute('PRAGMA foreign_keys = OFF');

      await db.transaction((txn) async {
        // 2. Renomeia a tabela antiga (Backup)
        await txn.execute(
          'ALTER TABLE FOLHAS_MODELO RENAME TO FOLHAS_MODELO_OLD',
        );

        // 3. Cria a nova tabela com a estrutura atualizada
        await txn.execute('''
          CREATE TABLE FOLHAS_MODELO (
            FOM_ID INTEGER PRIMARY KEY AUTOINCREMENT,
            FOM_NOME TEXT,
            FOM_CAMINHO TEXT,
            FOM_LAYOUT_CONFIG TEXT NOT NULL
          );
        ''');

        // 4. Copia os dados, injetando '{}' no JSON config
        await txn.execute('''
          INSERT INTO FOLHAS_MODELO (FOM_ID, FOM_NOME, FOM_CAMINHO, FOM_LAYOUT_CONFIG)
          SELECT 
            FOM_ID, 
            FOM_NOME, 
            FOM_CAMINHO, 
            '{}'
          FROM FOLHAS_MODELO_OLD;
        ''');

        // 5. Remove a tabela antiga com segurança
        await txn.execute('DROP TABLE FOLHAS_MODELO_OLD');
      });

      // 6. Religa a verificação. Como a tabela nova tem o mesmo nome "FOLHAS_MODELO"
      // e os mesmos IDs primários, as referências órfãs voltam a ser válidas.
      await db.execute('PRAGMA foreign_keys = ON');
    }

    if (oldVersion < 10) {
      print(
        'Migração v10: Adicionando número da questão em ALTERNATIVAS_GABARITO...',
      );
      // Adiciona a coluna
      await db.execute(
        'ALTER TABLE ALTERNATIVAS_GABARITO ADD COLUMN ALG_NUMERO_QUESTAO INTEGER',
      );

      // Tenta migrar dados antigos assumindo ordem sequencial (ALG_ID)
      // Como o SQLite antigo é limitado, faremos uma lógica simples:
      // Dados antigos continuarão com NULL e trataremos isso no código (fallback para índice sequencial)
    }
  }

  Future<void> _insertSeedData(Database db) async {
    final List<Map<String, dynamic>> anos = [
      {'num': 1, 'cat': 'FUNDAMENTAL'},
      {'num': 2, 'cat': 'FUNDAMENTAL'},
      {'num': 3, 'cat': 'FUNDAMENTAL'},
      {'num': 4, 'cat': 'FUNDAMENTAL'},
      {'num': 5, 'cat': 'FUNDAMENTAL'},
      {'num': 6, 'cat': 'FUNDAMENTAL'},
      {'num': 7, 'cat': 'FUNDAMENTAL'},
      {'num': 8, 'cat': 'FUNDAMENTAL'},
      {'num': 9, 'cat': 'FUNDAMENTAL'},
      {'num': 1, 'cat': 'ENSINO MÉDIO'},
      {'num': 2, 'cat': 'ENSINO MÉDIO'},
      {'num': 3, 'cat': 'ENSINO MÉDIO'},
    ];
    for (var ano in anos) {
      await db.rawInsert(
        "INSERT INTO ANOS (ANO_NUMERO, ANO_CATEGORIA) VALUES (?, ?)",
        [ano['num'], ano['cat']],
      );
    }
  }
}
