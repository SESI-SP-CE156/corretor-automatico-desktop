// lib/features/turmas/presentation/turmas_list_screen.dart

import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:corretor_desktop/features/turmas/data/turmas_repository.dart';
import 'package:corretor_desktop/features/turmas/presentation/widgets/turma_card.dart';
import 'package:corretor_desktop/features/turmas/presentation/widgets/turma_create_dialog.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class TurmasListScreen extends StatefulWidget {
  const TurmasListScreen({super.key});

  @override
  State<TurmasListScreen> createState() => _TurmasListScreenState();
}

class _TurmasListScreenState extends State<TurmasListScreen> {
  final TurmasRepository _repository = TurmasRepository();
  late Future<List<Turma>> _turmasFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _turmasFuture = _repository.getAllTurmas();
    });
  }

  // Função helper para abrir o modal
  Future<void> _openCreateDialog() async {
    // Aguarda o fechamento do diálogo
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (context) => const TurmaCreateDialog(),
    );

    // Se result for true, significa que uma turma foi criada
    if (result == true) {
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        backgroundColor: colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 16.0)),
          Expanded(
            child: FutureBuilder<List<Turma>>(
              future: _turmasFuture,
              builder: (context, snapshot) {
                // Estado: Carregando
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                // Estado: Erro
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text('Erro ao carregar turmas: ${snapshot.error}'),
                        TextButton(
                          onPressed: _loadData,
                          child: const Text('Tentar Novamente'),
                        ),
                      ],
                    ),
                  );
                }
                // Estado: Lista Vazia
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 48,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Nenhuma turma cadastrada.',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Clique no botão "+" para começar.',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                // Estado: Sucesso
                final turmas = snapshot.data!;

                return GridView.builder(
                  padding: EdgeInsets.all(8.sp),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 250,
                    childAspectRatio: 0.85,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: turmas.length,
                  itemBuilder: (context, index) {
                    final turma = turmas[index];
                    // Uso do componente separado
                    return TurmaCard(turma: turma);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
