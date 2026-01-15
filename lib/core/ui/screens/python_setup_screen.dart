import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:corretor_desktop/features/correcoes/data/python_service.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class PythonSetupScreen extends StatefulWidget {
  const PythonSetupScreen({super.key});

  @override
  State<PythonSetupScreen> createState() => _PythonSetupScreenState();
}

class _PythonSetupScreenState extends State<PythonSetupScreen> {
  final _pythonService = PythonService();

  @override
  void initState() {
    super.initState();
    _startSetup();
  }

  Future<void> _startSetup() async {
    try {
      // Inicia o processo. O ValueNotifier cuidará de atualizar a UI.
      await _pythonService.initialize();

      if (mounted) {
        // Aguarda um pequeno delay para o usuário ver o 100%
        await Future.delayed(const Duration(milliseconds: 500));
        context.go(AppRoutes.turmas);
      }
    } catch (e) {
      // O erro já é capturado no notifier, mas garantimos que não crashe
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ValueListenableBuilder<PythonSetupState>(
            valueListenable: _pythonService.stateNotifier,
            builder: (context, state, child) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo ou Ícone
                  Icon(
                    Icons.settings_system_daydream,
                    size: 64,
                    color: state.hasError
                        ? Colors.red
                        : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 24),

                  // Título
                  Text(
                    state.hasError
                        ? "Falha na Configuração"
                        : "Preparando Ambiente",
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Barra de Progresso
                  if (!state.hasError)
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: state.progress,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "${(state.progress * 100).toInt()}%",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Mensagem de Status
                  Text(
                    state.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: state.hasError ? Colors.red : Colors.grey.shade600,
                    ),
                  ),

                  // Botão de Tentar Novamente (apenas se erro)
                  if (state.hasError) ...[
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        // Reseta e tenta novamente
                        _startSetup();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text("Tentar Novamente"),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
