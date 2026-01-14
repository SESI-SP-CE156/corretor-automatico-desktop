import 'package:corretor_desktop/core/ui/widgets/app_search_bar.dart';
import 'package:corretor_desktop/core/ui/widgets/app_table.dart';
import 'package:corretor_desktop/core/ui/widgets/confirm_dialog.dart';
import 'package:corretor_desktop/core/ui/widgets/status_bedge.dart';
import 'package:corretor_desktop/features/alunos/data/alunos_repository.dart';
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class AlunosListScreen extends StatefulWidget {
  const AlunosListScreen({super.key});

  @override
  State<AlunosListScreen> createState() => _AlunosListScreenState();
}

class _AlunosListScreenState extends State<AlunosListScreen> {
  final AlunosRepository _repository = AlunosRepository();
  List<Aluno> _allAlunos = [];
  List<Aluno> _filteredAlunos = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  int? _sortColumnIndex;
  bool _isAscending = true;

  @override
  void initState() {
    super.initState();
    _loadAlunos();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  void _onSearchChanged() {
    // Normaliza o que o usuário digitou
    final query = _normalizeText(_searchController.text);

    setState(() {
      _filteredAlunos = _allAlunos.where((a) {
        // Normaliza os dados do aluno antes de comparar
        final nome = _normalizeText(a.nome);
        final rm = _normalizeText(a.rm ?? '');
        final turma = _normalizeText(a.nomeTurma ?? '');

        return nome.contains(query) ||
            rm.contains(query) ||
            turma.contains(query);
      }).toList();

      if (_sortColumnIndex != null) {
        _sortList(_sortColumnIndex!);
      }
    });
  }

  void _onHeaderTap(int columnIndex) {
    setState(() {
      if (_sortColumnIndex == columnIndex) {
        // Se clicou na mesma coluna, inverte a ordem
        _isAscending = !_isAscending;
      } else {
        // Se clicou em nova coluna, define ela como ascendente
        _sortColumnIndex = columnIndex;
        _isAscending = true;
      }
      _sortList(columnIndex);
    });
  }

  void _sortList(int columnIndex) {
    _filteredAlunos.sort((a, b) {
      int cmp = 0;
      switch (columnIndex) {
        case 0: // ID
          cmp = (a.id ?? 0).compareTo(b.id ?? 0);
          break;
        case 1: // Nome
          cmp = a.nome.toLowerCase().compareTo(b.nome.toLowerCase());
          break;
        case 2: // RM
          cmp = (a.rm ?? '').compareTo(b.rm ?? '');
          break;
        case 3: // Turma
          cmp = (a.nomeTurma ?? '').compareTo(b.nomeTurma ?? '');
          break;
        case 4: // Status
          cmp = a.status.compareTo(b.status);
          break;
      }
      return _isAscending ? cmp : -cmp; // Inverte se for descendente
    });
  }

  Future<void> _loadAlunos() async {
    setState(() => _isLoading = true);
    final alunos = await _repository.getAllAlunos();
    if (mounted) {
      setState(() {
        _allAlunos = alunos;
        _filteredAlunos = alunos;
        _isLoading = false;
      });
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Formado':
        return Colors.blue;
      case 'Evasão':
        return Colors.red;
      default:
        return Colors.green; // Cor para 'Ativo'
    }
  }

  Future<void> _handleEvasao(Aluno aluno) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Registrar Evasão',
      content: 'Confirmar evasão de ${aluno.nome}?',
      confirmText: 'CONFIRMAR',
      isDanger: true,
    );

    if (confirmed && aluno.id != null) {
      await _repository.deleteAluno(aluno.id!);
      _loadAlunos();
    }
  }

  Future<void> _formarAluno(Aluno aluno) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: "Formar Aluno",
      content:
          "Deseja marcar ${aluno.nome} como FORMADO?\nEle não aparecerá mais na lista da turma, mas continuará no histórico.",
      confirmText: "CONFIRMAR",
      isDanger: false,
    );

    if (confirmed == true && aluno.id != null) {
      await _repository.formarAluno(aluno.id!);
      _loadAlunos(); // Atualiza a lista para mostrar o novo status

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${aluno.nome} foi formado com sucesso!')),
        );
      }
    }
  }

  String _normalizeText(String text) {
    return text
        .toLowerCase()
        .replaceAll('º', '°') // Transforma ordinal em grau
        .replaceAll(
          'ª',
          'a',
        ); // Opcional: normaliza feminino também se necessário
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        heroTag: 'alunos_fab',
        onPressed: () {
          // Ao voltar da criação, recarrega a lista
          context.push('/alunos/create').then((_) => _loadAlunos());
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0)),

          // Barra de Pesquisa
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.sp),
            child: AppSearchBar(
              controller: _searchController,
              hintText: 'Pesquisar por Nome, RM',
            ),
          ),

          const SizedBox(height: 16),

          // Tabela Estilo Microsoft Clean
          Expanded(
            child: AppTable(
              // Definição limpa do cabeçalho
              headerCells: [
                AppTableHeaderCell(
                  label: 'ID',
                  flex: 1,
                  isSorted: _sortColumnIndex == 0,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(0),
                ),
                AppTableHeaderCell(
                  label: 'NOME COMPLETO',
                  flex: 3,
                  isSorted: _sortColumnIndex == 1,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(1),
                ),
                AppTableHeaderCell(
                  label: 'RM',
                  flex: 2,
                  isSorted: _sortColumnIndex == 2,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(2),
                ), // Sem sort
                AppTableHeaderCell(
                  label: 'TURMA',
                  flex: 2,
                  isSorted: _sortColumnIndex == 3,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(3),
                ),
                AppTableHeaderCell(
                  label: 'STATUS',
                  flex: 2,
                  isSorted: _sortColumnIndex == 4,
                  isAscending: _isAscending,
                  onTap: () => _onHeaderTap(4),
                ),
                const AppTableHeaderCell(label: 'AÇÕES', flex: 3),
              ],
              // Corpo da tabela
              body: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.separated(
                      itemCount: _filteredAlunos.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final aluno = _filteredAlunos[index];

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 8,
                            horizontal: 16,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 1,
                                child: Text(
                                  aluno.id.toString(),
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  aluno.nome,
                                  textAlign: TextAlign.justify,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  aluno.rm ?? '-',
                                  textAlign: TextAlign.justify,
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  aluno.nomeTurma ?? '-',
                                  textAlign: TextAlign.center,
                                ),
                              ),

                              // 3. Badge Reutilizável
                              Expanded(
                                flex: 2,
                                child: Center(
                                  child: StatusBadge(status: aluno.status),
                                ),
                              ),

                              Expanded(
                                flex: 3,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Tooltip(
                                      message: "Mover Aluno",
                                      child: IconButton(
                                        onPressed: () {
                                          // Lógica mover
                                        },
                                        icon: const Icon(
                                          Icons.drive_file_move_outline,
                                          size: 20,
                                        ),
                                        color: Colors.orange,
                                        splashRadius:
                                            20, // Toque menor e mais elegante
                                      ),
                                    ),
                                    if (aluno.nomeTurma!.contains("3") &&
                                        aluno.nomeTurma!.contains("EM") &&
                                        aluno.status.contains("Ativo"))
                                      Tooltip(
                                        message: 'Formar Aluno',
                                        child: IconButton(
                                          onPressed: () => _formarAluno(aluno),
                                          icon: const Icon(
                                            Icons.school_outlined,
                                            size: 20,
                                          ),
                                          color: Colors.blue,
                                          splashRadius: 20,
                                        ),
                                      ),
                                    Tooltip(
                                      message: 'Registrar Evasão',
                                      child: IconButton(
                                        onPressed: () => _handleEvasao(aluno),
                                        icon: const Icon(
                                          Icons.person_remove_outlined,
                                          size: 20,
                                        ),
                                        color: Colors.red,
                                        splashRadius: 20,
                                      ),
                                    ),
                                    // TextButton.icon(
                                    //   style: TextButton.styleFrom(
                                    //     foregroundColor: Colors.orange,
                                    //   ),
                                    //   onPressed: () {},
                                    //   label: const Text("MOVER"),
                                    //   icon: Icon(
                                    //     Icons.drive_file_move_outline,
                                    //     size: 20,
                                    //   ),
                                    // ),
                                    // TextButton.icon(
                                    //   style: TextButton.styleFrom(
                                    //     foregroundColor: Colors.blue,
                                    //   ),
                                    //   onPressed: () => _formarAluno(aluno),
                                    //   label: const Text("FORMAR"),
                                    //   icon: Icon(Icons.school_outlined),
                                    // ),
                                    // TextButton.icon(
                                    //   style: TextButton.styleFrom(
                                    //     foregroundColor: Colors.red,
                                    //   ),
                                    //   onPressed: () => _handleEvasao(aluno),
                                    //   label: const Text("EVASÃO"),
                                    //   icon: Icon(Icons.person_remove_outlined),
                                    // ),
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
