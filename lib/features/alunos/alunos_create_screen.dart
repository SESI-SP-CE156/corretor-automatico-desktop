// lib/features/alunos/presentation/alunos_create_screen.dart

import 'dart:convert';
import 'dart:io';

import 'package:corretor_desktop/features/alunos/data/alunos_repository.dart';
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:corretor_desktop/features/turmas/data/ano_model.dart'; // Import do Ano
import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:corretor_desktop/features/turmas/data/turmas_repository.dart';
import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class AlunosCreateScreen extends StatefulWidget {
  const AlunosCreateScreen({super.key});

  @override
  State<AlunosCreateScreen> createState() => _AlunosCreateScreenState();
}

class _AlunosCreateScreenState extends State<AlunosCreateScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();

  // Repositórios
  final _turmasRepo = TurmasRepository();
  final _alunosRepo = AlunosRepository();

  // Dados do Formulário Manual
  String? _nome;
  String? _rm;
  int? _selectedTurmaId;
  List<Turma> _turmasDisponiveis = [];
  List<Ano> _anosDisponiveis = []; // Lista de Anos para criar novas turmas

  // Dados do CSV
  List<Aluno> _alunosCSV = [];
  bool _isCsvLoaded = false;
  bool _isImporting = false; // Loading durante a gravação no banco

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDadosIniciais();
  }

  Future<void> _loadDadosIniciais() async {
    final turmas = await _turmasRepo.getAllTurmas();
    final anos = await _turmasRepo.getAnos();
    setState(() {
      _turmasDisponiveis = turmas;
      _anosDisponiveis = anos;
    });
  }

  // --- PARSERS AUXILIARES ---

  /// Tenta encontrar o ID de uma turma existente. Retorna 0 se não encontrar (para criar depois).
  int _findTurmaIdFromCsvString(String serieString) {
    final s = serieString.trim().toUpperCase();
    if (s.isEmpty) return 0;

    try {
      final parsed = _parseSerieString(s);
      if (parsed == null) return 0;

      final int anoNumero = parsed['numero'];
      final bool isEM = parsed['isEM'];
      final String letra = parsed['letra'];

      final turma = _turmasDisponiveis.where((t) {
        if (t.letra.toUpperCase() != letra) return false;

        // AQUI: Normaliza a descrição do banco para garantir match (º -> °)
        final desc = (t.nomeAnoExibicao?.toUpperCase() ?? '').replaceAll(
          'º',
          '°',
        );

        // Verifica número (corrigido o typo do código original que repetia a verificação)
        if (!desc.startsWith('$anoNumero°')) return false;

        if (isEM) {
          return desc.contains('ENSINO MÉDIO') || desc.contains('EM');
        } else {
          return desc.contains('FUNDAMENTAL');
        }
      }).firstOrNull;

      return turma?.id ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Quebra a string "3° EM A" em componentes dados
  Map<String, dynamic>? _parseSerieString(String s) {
    // Ajuste: Regex agora aceita tanto ° quanto º
    final regex = RegExp(
      r'^(\d+)[°º]?\s*(EM|ENSINO M[ÉE]DIO|MEDIO)?\s*([A-Z])$',
      caseSensitive: false,
    );
    final match = regex.firstMatch(s.trim());

    if (match == null) return null;

    return {
      'numero': int.parse(match.group(1)!),
      'isEM': match.group(2) != null,
      'letra': match.group(3)!.toUpperCase(),
    };
  }

  // --- LÓGICA DE LEITURA DO CSV ---
  Future<void> _pickAndParseCsv() async {
    try {
      await Future.delayed(const Duration(milliseconds: 200));

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result != null) {
        final file = File(result.files.single.path!);

        // Leitura UTF-8 (Conforme solicitado)
        final fileContent = await file.readAsString(encoding: utf8);

        // Conversão com parâmetros explícitos
        final List<List<dynamic>> fields = const CsvToListConverter(
          fieldDelimiter: ',', // Solicitado: vírgula
          textDelimiter: '"', // Solicitado: aspas duplas
          shouldParseNumbers: false,
          eol: '\n',
        ).convert(fileContent);

        if (fields.isEmpty) return;

        // Identificação de Cabeçalhos
        final headers = fields[0]
            .map((e) => e.toString().toUpperCase().trim())
            .toList();

        // Remove BOM se existir
        if (headers.isNotEmpty && headers[0].startsWith('\uFEFF')) {
          headers[0] = headers[0].substring(1);
        }

        // Normaliza para encontrar colunas
        String normalize(String s) => s
            .replaceAll(RegExp(r'[ÁÀÂÃ]'), 'A')
            .replaceAll('É', 'E')
            .replaceAll('Í', 'I')
            .replaceAll('Ó', 'O')
            .replaceAll('Ú', 'U')
            .replaceAll('Ç', 'C');

        int indexSerie = -1;
        int indexAluno = -1;
        int indexRM = -1;

        for (int i = 0; i < headers.length; i++) {
          final h = normalize(headers[i]);
          if (h.contains('SERIE')) indexSerie = i;
          if (h.contains('ALUNO') || h.contains('NOME')) indexAluno = i;
          if (h == 'RM') indexRM = i;
        }

        if (indexSerie == -1 || indexAluno == -1) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Colunas não encontradas. Cabeçalhos lidos: $headers',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        List<Aluno> parsedAlunos = [];

        // Ignora cabeçalho (i=1)
        for (var i = 1; i < fields.length; i++) {
          final row = fields[i];
          if (row.length <= indexSerie || row.length <= indexAluno) continue;

          final rawSerie = row[indexSerie].toString().trim().replaceAll(
            'º',
            '°',
          );
          final rawNome = row[indexAluno].toString().trim();
          final rawRM = (indexRM != -1 && row.length > indexRM)
              ? row[indexRM].toString().trim()
              : '';

          if (rawNome.isEmpty) continue;

          // Tenta achar ID existente ou retorna 0 (Novo)
          final turmaId = _findTurmaIdFromCsvString(rawSerie);

          parsedAlunos.add(
            Aluno(
              nome: rawNome,
              rm: rawRM,
              turmaId: turmaId, // 0 se for nova turma
              nomeTurma: rawSerie, // Guarda a string original para criar depois
            ),
          );
        }

        setState(() {
          _alunosCSV = parsedAlunos;
          _isCsvLoaded = true;
        });
      }
    } catch (e) {
      print('Erro CSV: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao ler: $e')));
      }
    }
  }

  // --- LÓGICA DE IMPORTAÇÃO E CRIAÇÃO NO BANCO ---
  Future<void> _processImport() async {
    setState(() => _isImporting = true);

    try {
      // Cache local para não criar a mesma turma várias vezes na mesma importação
      final Map<String, int> turmasCriadasCache = {}; // "3° EM A" -> ID 10

      // Lista final para inserção
      final List<Aluno> alunosParaInserir = [];

      for (var aluno in _alunosCSV) {
        int finalTurmaId = aluno.turmaId;

        // Se turmaId é 0, precisamos encontrar ou criar a turma baseada no texto 'nomeTurma'
        if (finalTurmaId == 0 && aluno.nomeTurma != null) {
          final serieRaw = aluno.nomeTurma!;

          // 1. Verifica se já criamos essa turma nesta sessão
          if (turmasCriadasCache.containsKey(serieRaw)) {
            finalTurmaId = turmasCriadasCache[serieRaw]!;
          } else {
            // 2. Tenta criar a turma no Banco
            final parsed = _parseSerieString(serieRaw);
            if (parsed != null) {
              final int anoNum = parsed['numero'];
              final bool isEM = parsed['isEM'];
              final String letra = parsed['letra'];

              // Acha o ID do Ano no banco (ex: ID do "3° Ensino Médio")
              final anoObj = _anosDisponiveis.firstWhere(
                (a) {
                  if (a.numero != anoNum) return false;
                  if (isEM) return a.categoria == 'ENSINO MÉDIO';
                  return a.categoria == 'FUNDAMENTAL';
                },
                orElse: () => _anosDisponiveis.first,
              ); // Fallback perigoso, mas evita crash

              // Verifica se a turma já existe no banco (para não duplicar se rodar import 2x)
              // (Pode ter sido criada por outro usuário enquanto digitávamos)
              // Aqui simplificamos assumindo criação.

              // Cria a Turma
              final novoId = await _turmasRepo.createTurma(
                Turma(letra: letra, anoId: anoObj.id),
              );

              // Atualiza cache e ID
              turmasCriadasCache[serieRaw] = novoId;
              finalTurmaId = novoId;

              // Atualiza a lista local para próximas iterações
              // _turmasDisponiveis.add(...) // Opcional
            }
          }
        }

        if (finalTurmaId != 0) {
          alunosParaInserir.add(
            Aluno(
              nome: aluno.nome,
              rm: aluno.rm,
              turmaId: finalTurmaId,
              status: 'Ativo',
            ),
          );
        }
      }

      // Salva todos os alunos
      if (alunosParaInserir.isNotEmpty) {
        await _alunosRepo.createBatchAlunos(alunosParaInserir);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${alunosParaInserir.length} alunos importados e turmas atualizadas!',
              ),
            ),
          );
          context.pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Nenhum aluno válido para importar.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao salvar: $e')));
      }
    } finally {
      setState(() => _isImporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cadastrar Alunos'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Manual', icon: Icon(Icons.edit)),
            Tab(text: 'Importar CSV', icon: Icon(Icons.upload_file)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildManualForm(), _buildCsvImport()],
      ),
    );
  }

  // --- ABA MANUAL (Mantida igual) ---
  Widget _buildManualForm() {
    return Center(
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Nome do Aluno',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
                onSaved: (v) => _nome = v,
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'RM',
                  border: OutlineInputBorder(),
                ),
                onSaved: (v) => _rm = v,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(
                  labelText: 'Turma',
                  border: OutlineInputBorder(),
                ),
                items: _turmasDisponiveis
                    .map(
                      (t) => DropdownMenuItem(
                        value: t.id,
                        child: Text('${t.nomeAnoExibicao} - ${t.letra}'),
                      ),
                    )
                    .toList(),
                onChanged: (v) => _selectedTurmaId = v,
                validator: (v) => v == null ? 'Selecione a turma' : null,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () async {
                  if (_formKey.currentState!.validate()) {
                    _formKey.currentState!.save();
                    await _alunosRepo.createAluno(
                      Aluno(
                        nome: _nome!,
                        rm: _rm ?? '',
                        turmaId: _selectedTurmaId!,
                      ),
                    );
                    if (mounted) context.pop();
                  }
                },
                child: const Text('CADASTRAR'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- ABA IMPORTAR CSV ---
  Widget _buildCsvImport() {
    if (_isCsvLoaded) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Confira os dados (${_alunosCSV.length} alunos). Turmas novas serão criadas automaticamente.',
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('SÉRIE (CSV)')),
                  DataColumn(label: Text('ALUNO')),
                  DataColumn(label: Text('AÇÃO')),
                ],
                rows: _alunosCSV.map((a) {
                  // Se ID for 0, será criada
                  final bool isNewTurma = a.turmaId == 0;
                  return DataRow(
                    cells: [
                      DataCell(
                        Row(
                          children: [
                            Text(a.nomeTurma ?? '-'),
                            if (isNewTurma)
                              Padding(
                                padding: const EdgeInsets.only(left: 8.0),
                                child: Chip(
                                  label: const Text(
                                    'Nova Turma',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                    ),
                                  ),
                                  backgroundColor: Colors.blue,
                                  visualDensity: VisualDensity.compact,
                                  padding: EdgeInsets.zero,
                                ),
                              ),
                          ],
                        ),
                      ),
                      DataCell(Text(a.nome)),
                      DataCell(
                        Text(isNewTurma ? 'Criar & Inserir' : 'Inserir'),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: _isImporting
                      ? null
                      : () => setState(() {
                          _isCsvLoaded = false;
                          _alunosCSV.clear();
                        }),
                  child: const Text('CANCELAR'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isImporting ? null : _processImport,
                  child: _isImporting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('CONFIRMAR IMPORTAÇÃO'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Center(
      child: InkWell(
        onTap: _pickAndParseCsv,
        child: Container(
          width: 400,
          height: 250,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey, width: 2),
            borderRadius: BorderRadius.circular(12),
            color: Colors.grey.shade50,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.upload_file, size: 40.sp, color: Colors.grey),
              const SizedBox(height: 16),
              const Text('Clique para selecionar o arquivo .CSV'),
              const SizedBox(height: 8),
              const Text(
                'Colunas: SÉRIE, ALUNO',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
