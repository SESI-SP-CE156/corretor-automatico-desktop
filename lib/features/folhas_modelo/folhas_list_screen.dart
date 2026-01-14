import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:corretor_desktop/core/ui/widgets/app_search_bar.dart';
import 'package:corretor_desktop/core/ui/widgets/confirm_dialog.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/folha_model.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/folhas_repository.dart';
import 'package:corretor_desktop/features/folhas_modelo/presentation/widgets/folha_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class FolhasListScreen extends StatefulWidget {
  const FolhasListScreen({super.key});

  @override
  State<FolhasListScreen> createState() => _FolhasListScreenState();
}

class _FolhasListScreenState extends State<FolhasListScreen> {
  final FolhasRepository _repository = FolhasRepository();

  List<FolhaModelo> _allFolhas = [];
  List<FolhaModelo> _filteredFolhas = [];
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
      final folhas = await _repository.getAllFolhas();
      if (mounted) {
        setState(() {
          _allFolhas = folhas;
          _filteredFolhas = folhas;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao carregar folhas: $e')));
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredFolhas = _allFolhas.where((f) {
        return f.nome.toLowerCase().contains(query) ||
            (f.anosExibicao?.toLowerCase().contains(query) ?? false);
      }).toList();
    });
  }

  Future<void> _deleteFolha(FolhaModelo folha) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Excluir Modelo',
      content:
          'Tem certeza que deseja excluir "${folha.nome}"? Gabaritos associados podem ser afetados.',
      confirmText: 'EXCLUIR',
      isDanger: true,
    );

    if (confirmed && folha.id != null) {
      await _repository.deleteFolha(folha.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navega para a criação e recarrega ao voltar
          context
              .push('${AppRoutes.folhas}/${AppRoutes.folhasCreate}')
              .then((_) => _loadData());
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
              hintText: 'Pesquisar por Nome ou Série (ex: 6º)',
            ),
          ),

          const SizedBox(height: 16),

          // Grid de Cards
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFolhas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.description_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma folha modelo encontrada.',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: EdgeInsets.all(16.sp),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 250, // Largura máxima do card
                      childAspectRatio:
                          0.75, // Proporção Altura/Largura (Retangular vertical)
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                    ),
                    itemCount: _filteredFolhas.length,
                    itemBuilder: (context, index) {
                      final folha = _filteredFolhas[index];
                      return FolhaCard(
                        folha: folha,
                        onTap: () {
                          // Futuro: Abrir detalhes ou editar
                          // context.go(...);
                        },
                        onDelete: () => _deleteFolha(folha),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
