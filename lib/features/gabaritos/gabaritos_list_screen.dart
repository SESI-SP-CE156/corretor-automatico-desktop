import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:corretor_desktop/core/ui/widgets/app_search_bar.dart';
import 'package:corretor_desktop/core/ui/widgets/confirm_dialog.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabarito_model.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabaritos_repository.dart';
import 'package:corretor_desktop/features/gabaritos/presentation/widgets/gabarito_card.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class GabaritosListScreen extends StatefulWidget {
  const GabaritosListScreen({super.key});

  @override
  State<GabaritosListScreen> createState() => _GabaritosListScreenState();
}

class _GabaritosListScreenState extends State<GabaritosListScreen> {
  final GabaritosRepository _repository = GabaritosRepository();

  List<GabaritoModelo> _allGabaritos = [];
  List<GabaritoModelo> _filteredGabaritos = [];
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
      final gabaritos = await _repository.getAllGabaritos();
      if (mounted) {
        setState(() {
          _allGabaritos = gabaritos;
          _filteredGabaritos = gabaritos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar gabaritos: $e')),
        );
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredGabaritos = _allGabaritos.where((g) {
        return g.nome.toLowerCase().contains(query) ||
            g.nomeFolhaModelo.toLowerCase().contains(query) ||
            g.anosExibicao.toLowerCase().contains(query);
      }).toList();
    });
  }

  Future<void> _deleteGabarito(GabaritoModelo gabarito) async {
    final confirmed = await ConfirmDialog.show(
      context: context,
      title: 'Excluir Gabarito',
      content:
          'Deseja excluir "${gabarito.nome}"?\nAs provas corrigidas com este gabarito perderão a referência.',
      confirmText: 'EXCLUIR',
      isDanger: true,
    );

    if (confirmed && gabarito.id != null) {
      await _repository.deleteGabarito(gabarito.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context
              .push('${AppRoutes.gabaritos}/${AppRoutes.gabaritosCreate}')
              .then((_) => _loadData());
          // Navega para criar Gabarito (ainda a ser implementado)
          // Ex: context.push('${AppRoutes.gabaritos}/${AppRoutes.gabaritosCreate}').then((_) => _loadData());
          // ScaffoldMessenger.of(context).showSnackBar(
          //   const SnackBar(
          //     content: Text(
          //       "Funcionalidade de Criar Gabarito será implementada a seguir",
          //     ),
          //   ),
          // );
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
              hintText: 'Pesquisar Gabarito, Modelo ou Série...',
            ),
          ),

          const SizedBox(height: 16),

          // Grid de Gabaritos
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredGabaritos.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 48,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhum gabarito cadastrado.',
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
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent:
                              280, // Um pouco mais largo que a folha
                          childAspectRatio: 0.8, // Formato do card
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: _filteredGabaritos.length,
                    itemBuilder: (context, index) {
                      final gabarito = _filteredGabaritos[index];
                      return GabaritoCard(
                        gabarito: gabarito,
                        onTap: () {
                          // Abrir detalhes/edição
                        },
                        onDelete: () => _deleteGabarito(gabarito),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
