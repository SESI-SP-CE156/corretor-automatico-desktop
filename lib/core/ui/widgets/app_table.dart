// lib/core/ui/widgets/app_table.dart
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class AppTable extends StatelessWidget {
  final List<Widget> headerCells;
  final Widget body; // O ListView ou conteúdo da tabela

  const AppTable({super.key, required this.headerCells, required this.body});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.sp, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Cabeçalho
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(8),
              ),
            ),
            child: Row(children: headerCells),
          ),
          const Divider(height: 1),
          // Corpo
          Expanded(child: body),
        ],
      ),
    );
  }
}

// Widget auxiliar para células do cabeçalho com ordenação
class AppTableHeaderCell extends StatelessWidget {
  final String label;
  final int flex;
  final bool isSorted;
  final bool isAscending;
  final VoidCallback? onTap;

  const AppTableHeaderCell({
    super.key,
    required this.label,
    this.flex = 1,
    this.isSorted = false,
    this.isAscending = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround, // Alinhamento à esquerda padrão
            children: [
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isSorted
                      ? Theme.of(context).primaryColor
                      : Colors.black87,
                  fontSize: 11.sp,
                ),
              ),
              if (isSorted) ...[
                const SizedBox(width: 4),
                Icon(
                  isAscending ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 14,
                  color: Theme.of(context).primaryColor,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
