import 'package:corretor_desktop/core/router/app_routes.dart'; // <--- Importante
import 'package:corretor_desktop/core/ui/widgets/app_search_bar.dart';
import 'package:corretor_desktop/core/ui/widgets/confirm_dialog.dart';
import 'package:corretor_desktop/features/correcoes/data/correcao_list_model.dart';
import 'package:corretor_desktop/features/correcoes/data/correcoes_repository.dart';
import 'package:corretor_desktop/features/correcoes/presentation/widgets/correcao_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // <--- Importante
import 'package:sizer/sizer.dart';

class CorrecoesListScreen extends StatefulWidget {
  const CorrecoesListScreen({super.key});

  @override
  State<CorrecoesListScreen> createState() => _CorrecoesListScreenState();
}

class _CorrecoesListScreenState extends State<CorrecoesListScreen> {
  final CorrecoesRepository _repository = CorrecoesRepository();

  List<CorrecaoListModel> _allCorrecoes = [];
  List<CorrecaoListModel> _filteredCorrecoes = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();

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

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final dados = await _repository.getResumoCorrecoes();
      if (mounted) {
        setState(() {
          _allCorrecoes = dados;
          _filteredCorrecoes = dados;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        // Apenas loga no console para não atrapalhar a UX se for primeira execução
        debugPrint('Erro ao carregar correções: $e');
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCorrecoes = _allCorrecoes.where((c) {
        return c.gabaritoNome.toLowerCase().contains(query) ||
            c.materia.toLowerCase().contains(query) ||
            c.anoTurma.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _deleteCorrecao(CorrecaoListModel correcao) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Excluir Correção',
      content:
          'Tem certeza que deseja apagar todas as correções da prova "${correcao.gabaritoNome}"?\n\nAs notas dos alunos para esta prova serão perdidas.',
      confirmText: 'EXCLUIR',
      isDanger: true,
    );

    if (confirmed) {
      try {
        await _repository.deleteCorrecao(correcao.gabaritoId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Correção excluída com sucesso!")),
          );
          _loadData(); // Recarrega a lista
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Erro ao excluir: $e")));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Botão Flutuante (FAB) atualizado
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // CORREÇÃO: Navega para a tela de scanner e recarrega a lista ao voltar
          context.push('${AppRoutes.correcoes}/scanner').then((_) {
            _loadData(); // Atualiza a lista após corrigir novas provas
          });
        },
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
        label: const Text(
          "CORRIGIR PROVAS",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
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
              hintText: 'Pesquisar Prova, Matéria ou Turma...',
            ),
          ),

          const SizedBox(height: 16),

          // Grid de Correções
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCorrecoes.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.fact_check_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma correção realizada ainda.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.sp,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clique em "CORRIGIR PROVAS" para começar.',
                          style: TextStyle(
                            color: Colors.grey[500],
                            fontSize: 10.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(16.sp),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 280,
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _filteredCorrecoes.length,
                    itemBuilder: (context, index) {
                      final item = _filteredCorrecoes[index];
                      return CorrecaoCard(
                        correcao: item,
                        onTap: () {
                          // Futuro: Navegar para detalhes da correção
                        },
                        onDelete: () => _deleteCorrecao(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
