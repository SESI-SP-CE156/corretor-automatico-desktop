import 'dart:io';

import 'package:corretor_desktop/features/folhas_modelo/data/folha_model.dart';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

class FolhaCard extends StatelessWidget {
  final FolhaModelo folha;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const FolhaCard({
    super.key,
    required this.folha,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Tenta obter a quantidade de questões do JSON de configuração
    final qtdQuestoes = folha.layoutConfig['total_questoes']?.toString() ?? '?';

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Área da Imagem (Thumbnail)
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    // CORREÇÃO 1: caminhoArquivo -> imagemModeloPath
                    child: Image.file(
                      File(folha.imagemModeloPath),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.broken_image_outlined,
                              size: 24.sp,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Erro",
                              style: TextStyle(
                                fontSize: 8.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // 2. Título (Nome)
              Text(
                folha.nome,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 4),

              // 3. Séries
              Row(
                children: [
                  Icon(
                    Icons.class_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      folha.anosExibicao ?? "Geral",
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 4),

              // 4. Quantidade de Questões (CORREÇÃO 2)
              Row(
                children: [
                  Icon(
                    Icons.question_mark_outlined,
                    size: 14,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      "$qtdQuestoes Questões", // Exibe do layoutConfig
                      style: TextStyle(
                        fontSize: 10.sp,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // 5. Rodapé
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Modelo Personalizado",
                    style: TextStyle(fontSize: 9.sp, color: Colors.grey),
                  ),
                  InkWell(
                    onTap: onDelete,
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
