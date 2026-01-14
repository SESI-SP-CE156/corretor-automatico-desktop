// lib/features/turmas/turmas_details_screen.dart

import 'package:corretor_desktop/core/ui/widgets/app_search_bar.dart';
import 'package:corretor_desktop/core/ui/widgets/app_table.dart';
import 'package:corretor_desktop/core/ui/widgets/confirm_dialog.dart';
import 'package:corretor_desktop/core/ui/widgets/status_bedge.dart'; // Verifique se o arquivo é status_badge.dart
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:corretor_desktop/features/turmas/data/turmas_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class TurmasDetailsScreen extends StatefulWidget {
  final String turmaId;

  const TurmasDetailsScreen({super.key, required this.turmaId});

  @override
  State<TurmasDetailsScreen> createState() => _TurmasDetailsScreenState();
}

class _TurmasDetailsScreenState extends State<TurmasDetailsScreen> {
  final TurmasRepository _repository = TurmasRepository();

  // Estado
  bool _isLoading = true;
  Turma? _turma;
  List<Aluno> _todosAlunos = [];
  List<Aluno> _alunosFiltrados = [];
  final Set<int> _alunosSelecionadosIds = {};
  final TextEditingController _searchController = TextEditingController();
  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _alunosFiltrados = _todosAlunos.where((aluno) {
        return aluno.nome.toLowerCase().contains(query) ||
            (aluno.rm!.contains(query));
      }).toList();

      // Reaplica ordenação se houver
      if (_sortColumnIndex != null) {
        _sortList(_sortColumnIndex!);
      }
    });
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final id = int.parse(widget.turmaId);

      final dados = await Future.wait([
        _repository.getTurmaById(id),
        _repository.getAlunosByTurma(id),
      ]);

      if (mounted) {
        setState(() {
          _turma = dados[0] as Turma?;
          _todosAlunos = dados[1] as List<Aluno>;
          _alunosFiltrados = List.from(_todosAlunos);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar dados: $e')));
      }
    }
  }

  // Lógica do "Select All"
  void _toggleSelectAll(bool? value) {
    setState(() {
      if (value == true) {
        _alunosSelecionadosIds.addAll(_alunosFiltrados.map((a) => a.id!));
      } else {
        _alunosSelecionadosIds.clear();
      }
    });
  }

  // Refatorado para usar ConfirmDialog
  Future<void> _registerEvasao(Aluno aluno) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Registrar Evasão',
      content:
          'Deseja marcar ${aluno.nome} como EVASÃO?\nEle será removido desta lista de ativos.',
      confirmText: 'CONFIRMAR',
      isDanger: true,
    );

    if (confirmed && aluno.id != null) {
      await _repository.registrarEvasao(aluno.id!);
      _loadData();
    }
  }

  void _onHeaderTap(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        _isAscending = !_isAscending;
      } else {
        _sortColumnIndex = columnIndex;
        _isAscending = true;
      }
      _sortList(columnIndex);
    });
  }

  void _sortList(int columnIndex) {
    _alunosFiltrados.sort((a, b) {
      int cmp = 0;
      switch (columnIndex) {
        case 0: // Nome
          cmp = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          break;
        case 1: // RM
          cmp = (a.rm ?? '').compareTo(b.rm ?? '');
          break;
        case 2: // Status
          cmp = a.status.compareTo(b.status);
          break;
      }
      return _isAscending ? cmp : -cmp;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSelectionMode = _alunosSelecionadosIds.isNotEmpty;

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_turma == null) {
      return const Scaffold(body: Center(child: Text("Turma não encontrada")));
    }

    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Cabeçalho com Voltar (Pode ser melhorado visualmente ou extraído se desejar)
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            color: Theme.of(
              context,
            ).scaffoldBackgroundColor, // Cor do fundo padrão
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Voltar',
                    ),
                    const SizedBox(width: 8),
                    // Título da Turma
                    Text(
                      '${_turma!.nomeAnoExibicao ?? ""} ${_turma!.letra}',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          // 2. Barra de Ações e Pesquisa
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 8.sp),
            child: Row(
              children: [
                // Barra de Pesquisa Reutilizável
                Expanded(
                  flex: 2,
                  child: AppSearchBar(
                    controller: _searchController,
                    hintText: 'Pesquisar Nome ou RM',
                  ),
                ),

                SizedBox(width: 16.sp),

                // Botões de Ação em Massa
                ElevatedButton.icon(
                  onPressed: isSelectionMode
                      ? () {
                          // Lógica para MOVER N alunos
                        }
                      : null,
                  icon: const Icon(Icons.drive_file_move_outline, size: 18),
                  label: Text('MOVER (${_alunosSelecionadosIds.length})'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                ),

                SizedBox(width: 8.sp),

                OutlinedButton.icon(
                  onPressed: () {
                    // Lógica para Formar Turma Inteira
                  },
                  icon: const Icon(Icons.school_outlined, size: 18),
                  label: const Text('FORMAR TURMA'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // 3. Tabela Reutilizável (AppTable)
          Expanded(
            child: AppTable(
              // Cabeçalho da Tabela
              headerCells: [
                // Checkbox Header
                SizedBox(
                  width: 50,
                  child: Checkbox(
                    value:
                        _alunosFiltrados.isNotEmpty &&
                        _alunosSelecionadosIds.length ==
                            _alunosFiltrados.length,
                    onChanged: _toggleSelectAll,
                  ),
                ),
                AppTableHeaderCell(
                  label: 'NOME',
                  flex: 4,
                  isSorted: _sortColumnIndex == 0,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(0),
                ),
                AppTableHeaderCell(
                  label: 'RM',
                  flex: 2,
                  isSorted: _sortColumnIndex == 1,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(1),
                ),
                AppTableHeaderCell(
                  label: 'STATUS',
                  flex: 2,
                  isSorted: _sortColumnIndex == 2,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(2),
                ),
                const AppTableHeaderCell(label: 'AÇÕES', flex: 3),
              ],

              // Corpo da Tabela
              body: _alunosFiltrados.isEmpty
                  ? const Center(
                      child: Text('Nenhum aluno encontrado nesta turma.'),
                    )
                  : ListView.separated(
                      itemCount: _alunosFiltrados.length,
                      separatorBuilder: (c, i) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final aluno = _alunosFiltrados[index];
                        final isSelected = _alunosSelecionadosIds.contains(
                          aluno.id,
                        );

                        // Lógica para saber se é 3º Ano EM (para mostrar botão Formar)
                        final isTerceiroAno =
                            _turma!.nomeAnoExibicao != null &&
                            (_turma!.nomeAnoExibicao!.contains(
                                  "3º ENSINO MÉDIO",
                                ) ||
                                _turma!.nomeAnoExibicao!.contains(
                                  "3° ENSINO MÉDIO",
                                ));

                        return Container(
                          color: isSelected
                              ? Theme.of(context).primaryColor.withOpacity(0.05)
                              : null,
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              // Checkbox Linha
                              SizedBox(
                                width: 50,
                                child: Checkbox(
                                  value: isSelected,
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        _alunosSelecionadosIds.add(aluno.id!);
                                      } else {
                                        _alunosSelecionadosIds.remove(aluno.id);
                                      }
                                    });
                                  },
                                ),
                              ),

                              // Nome
                              Expanded(
                                flex: 4,
                                child: Text(
                                  aluno.nome,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),

                              // RM
                              Expanded(flex: 2, child: Text(aluno.rm ?? '-')),

                              // Status Badge Reutilizável
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: StatusBadge(status: aluno.status),
                                ),
                              ),

                              // Ações (IconButtons padronizados)
                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Tooltip(
                                      message: "Mover Aluno",
                                      child: IconButton(
                                        onPressed: () {
                                          // Lógica individual de mover
                                        },
                                        icon: const Icon(
                                          Icons.drive_file_move_outline,
                                          size: 20,
                                        ),
                                        color: Colors.orange,
                                        splashRadius: 20,
                                      ),
                                    ),
                                    if (isTerceiroAno)
                                      Tooltip(
                                        message: "Formar Aluno",
                                        child: IconButton(
                                          onPressed: () {
                                            // Lógica formar
                                          },
                                          icon: const Icon(
                                            Icons.school_outlined,
                                            size: 20,
                                          ),
                                          color: Colors.blue,
                                          splashRadius: 20,
                                        ),
                                      ),
                                    Tooltip(
                                      message: "Registrar Evasão",
                                      child: IconButton(
                                        onPressed: () => _registerEvasao(aluno),
                                        icon: const Icon(
                                          Icons.person_remove_outlined,
                                          size: 20,
                                        ),
                                        color: Colors.red,
                                        splashRadius: 20,
                                      ),
                                    ),
                                  ],
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
      ),
    );
  }
}
