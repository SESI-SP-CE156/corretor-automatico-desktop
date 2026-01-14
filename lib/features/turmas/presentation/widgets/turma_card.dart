// lib/features/turmas/presentation/widgets/turma_card.dart

import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class TurmaCard extends StatelessWidget {
  final Turma turma;

  const TurmaCard({super.key, required this.turma});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300, width: 1),
      ),
      child: InkWell(
        onTap: () {
          // Navegação para detalhes: /turmas/1
          context.go('${AppRoutes.turmas}/${turma.id}');
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Cabeçalho do Card: Ano e Categoria
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4.sp),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  turma.nomeAnoExibicao ?? 'Ano Desconhecido',
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              // Corpo do Card: A Letra da Turma
              Expanded(
                child: Center(
                  child: Text(
                    turma.letra,
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      // Usa a cor primária do tema
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),

              // Rodapé: Botão Editar
              // SizedBox(
              //   width: double.infinity,
              //   child: OutlinedButton.icon(
              //     onPressed: () {
              //       context.go('${AppRoutes.turmas}/${turma.id}');
              //     },
              //     icon: const Icon(Icons.edit, size: 16),
              //     label: const Text('EDITAR'),
              //     style: OutlinedButton.styleFrom(
              //       visualDensity: VisualDensity.compact,
              //     ),
              //   ),
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
