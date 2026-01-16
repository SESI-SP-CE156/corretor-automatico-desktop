import 'dart:io';

import 'package:corretor_desktop/core/ui/widgets/app_table.dart';
import 'package:corretor_desktop/features/correcoes/data/correcao_detalhes_dto.dart';
import 'package:corretor_desktop/features/correcoes/data/correcoes_repository.dart';
import 'package:diacritic/diacritic.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sizer/sizer.dart';

class CorrecoesDetailsScreen extends StatefulWidget {
  final String gabaritoId;

  const CorrecoesDetailsScreen({super.key, required this.gabaritoId});

  @override
  State<CorrecoesDetailsScreen> createState() => _CorrecoesDetailsScreenState();
}

class _CorrecoesDetailsScreenState extends State<CorrecoesDetailsScreen>
    with SingleTickerProviderStateMixin {
  final _repository = CorrecoesRepository();
  late TabController _tabController;

  bool _isLoading = true;
  List<AlunoNotaDto> _alunos = [];
  List<EstatisticaQuestaoDto> _estatisticas = [];

  EstatisticaResumoDto? _resumo;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final id = int.parse(widget.gabaritoId);
      final dados = await Future.wait([
        _repository.getAlunosNotas(id),
        _repository.getEstatisticas(id),
        _repository.getResumoEstatistico(id),
      ]);

      if (mounted) {
        setState(() {
          _alunos = dados[0] as List<AlunoNotaDto>;
          _estatisticas = dados[1] as List<EstatisticaQuestaoDto>;
          _resumo = dados[2] as EstatisticaResumoDto; // Salva o resumo
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar detalhes: $e')),
        );
      }
    }
  }

  String _generateFileName(String nome, double nota, bool isCorrigida) {
    String cleanName = removeDiacritics(nome);
    List<String> parts = cleanName.split(' ');
    String camelCase = parts
        .map((part) {
          if (part.isEmpty) return '';
          return part[0].toUpperCase() + part.substring(1).toLowerCase();
        })
        .join('');

    String gradeStr = nota.toStringAsFixed(1).replaceAll('.', '-');
    String suffix = isCorrigida
        ? '_CORRIGIDA'
        : ''; // Diferencia no nome do arquivo

    return '${camelCase}_$gradeStr$suffix.png';
  }

  Future<void> _downloadImage(AlunoNotaDto aluno, bool comCorrecao) async {
    // 1. Determina qual caminho usar
    String? caminhoArquivo = comCorrecao
        ? aluno.caminhoImagemCorrigida
        : aluno.caminhoImagem;

    if (caminhoArquivo == null || caminhoArquivo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            comCorrecao
                ? 'Arquivo corrigido não disponível.'
                : 'Arquivo original não encontrado.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final sourceFile = File(caminhoArquivo);
      if (!sourceFile.existsSync()) {
        throw Exception(
          "Arquivo físico não existe mais no disco: $caminhoArquivo",
        );
      }

      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        throw Exception("Pasta de downloads não encontrada.");
      }

      // Gera nome apropriado
      final fileName = _generateFileName(
        aluno.alunoNome,
        aluno.nota,
        comCorrecao,
      );
      final destinationPath = p.join(downloadsDir.path, fileName);

      await sourceFile.copy(destinationPath);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Salvo: $fileName'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao baixar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Detalhes da Correção"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Resultados por Aluno", icon: Icon(Icons.people)),
            Tab(text: "Estatísticas da Prova", icon: Icon(Icons.analytics)),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildAlunosList(), _buildStatistics()],
            ),
    );
  }

  Widget _buildAlunosList() {
    if (_alunos.isEmpty) {
      return const Center(child: Text("Nenhum aluno corrigido nesta prova."));
    }

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            "Clique nos ícones para baixar a imagem da prova.",
            style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          ),
        ),
        Expanded(
          child: AppTable(
            headerCells: const [
              AppTableHeaderCell(label: 'ALUNO', flex: 4),
              AppTableHeaderCell(label: 'PROVA ORIGINAL', flex: 2),
              AppTableHeaderCell(label: 'PROVA CORRIGIDA', flex: 2),
              AppTableHeaderCell(label: 'NOTA FINAL', flex: 2),
            ],
            body: ListView.separated(
              itemCount: _alunos.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final aluno = _alunos[index];

                Color notaColor = Colors.black;
                if (aluno.nota >= 6) {
                  notaColor = Colors.green;
                } else if (aluno.nota >= 4) {
                  notaColor = Colors.orange;
                } else {
                  notaColor = Colors.red;
                }

                // Verifica se os arquivos existem para habilitar/desabilitar botões visualmente
                final hasOriginal =
                    aluno.caminhoImagem != null &&
                    aluno.caminhoImagem!.isNotEmpty;
                final hasCorrigida =
                    aluno.caminhoImagemCorrigida != null &&
                    aluno.caminhoImagemCorrigida!.isNotEmpty;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Text(
                          aluno.alunoNome,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Tooltip(
                            message: hasOriginal
                                ? "Baixar Original"
                                : "Indisponível",
                            child: IconButton(
                              icon: const Icon(Icons.image_outlined),
                              onPressed: hasOriginal
                                  ? () => _downloadImage(aluno, false)
                                  : null,
                              color: Colors.blueGrey,
                              disabledColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Tooltip(
                            message: hasCorrigida
                                ? "Baixar com Correção"
                                : "Indisponível",
                            child: IconButton(
                              icon: const Icon(Icons.fact_check_outlined),
                              onPressed: hasCorrigida
                                  ? () => _downloadImage(aluno, true)
                                  : null,
                              color: Theme.of(context).primaryColor,
                              disabledColor: Colors.grey.shade200,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: notaColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: notaColor.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              aluno.nota.toStringAsFixed(1),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: notaColor,
                                fontSize: 11.sp,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    if (_estatisticas.isEmpty || _resumo == null) {
      return const Center(child: Text("Dados estatísticos indisponíveis."));
    }

    return Column(
      children: [
        Card(
          margin: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // 1. Imagem da Folha Modelo
                Container(
                  width: 80,
                  height: 100,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade100,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_resumo!.caminhoImagemModelo),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.broken_image),
                    ),
                  ),
                ),

                const SizedBox(width: 24),

                // 2. Informações (Nome e Média)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "PROVA",
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _resumo!.nomeProva,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "MÉDIA DA TURMA",
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            color: Theme.of(context).primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _resumo!.mediaNota.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 20.sp,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: AppTable(
            headerCells: const [
              AppTableHeaderCell(label: 'QUESTÃO', flex: 2),
              AppTableHeaderCell(label: 'GABARITO', flex: 2),
              AppTableHeaderCell(label: 'MAIS MARCADA', flex: 3),
              AppTableHeaderCell(label: '% ACERTO', flex: 2),
            ],
            body: ListView.separated(
              itemCount: _estatisticas.length,
              separatorBuilder: (c, i) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final stat = _estatisticas[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 16,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            "${stat.numeroQuestao}",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            stat.respostaCorreta,
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Center(child: Text(stat.respostaMaisMarcada)),
                      ),
                      Expanded(
                        flex: 2,
                        child: Center(
                          child: Text(
                            "${(stat.percentualAcerto * 100).toStringAsFixed(0)}%",
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
