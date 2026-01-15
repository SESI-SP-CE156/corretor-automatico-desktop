import 'dart:io';

import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:corretor_desktop/core/ui/scaffold_with_rail.dart';
import 'package:corretor_desktop/core/ui/screens/python_setup_screen.dart';
import 'package:corretor_desktop/features/alunos/alunos_create_screen.dart';
import 'package:corretor_desktop/features/alunos/alunos_list_screen.dart';
import 'package:corretor_desktop/features/correcoes/correcoes_details_screen.dart';
import 'package:corretor_desktop/features/correcoes/correcoes_list_screen.dart';
import 'package:corretor_desktop/features/correcoes/correcoes_review_screen.dart';
import 'package:corretor_desktop/features/correcoes/correcoes_scanner_screen.dart';
import 'package:corretor_desktop/features/folhas_modelo/folhas_create_screen.dart';
import 'package:corretor_desktop/features/folhas_modelo/folhas_list_screen.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabarito_model.dart';
import 'package:corretor_desktop/features/gabaritos/gabaritos_create_screen.dart';
import 'package:corretor_desktop/features/gabaritos/gabaritos_list_screen.dart';
import 'package:corretor_desktop/features/turmas/turmas_details_screen.dart';
import 'package:corretor_desktop/features/turmas/turmas_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Chaves globais para navegação
final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey =
    GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.setup,
  routes: [
    GoRoute(
      path: AppRoutes.setup,
      builder: (context, state) => const PythonSetupScreen(),
    ),
    // MUDANÇA PRINCIPAL: Usamos ShellRoute ao invés de StatefulShellRoute
    // Isso garante que as telas sejam reconstruídas ao trocar de rota
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        return ScaffoldWithRail(child: child);
      },
      routes: [
        // --- TURMAS ---
        GoRoute(
          path: AppRoutes.turmas,
          builder: (context, state) => const TurmasListScreen(),
          routes: [
            GoRoute(
              path: ':id',
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return TurmasDetailsScreen(turmaId: id);
              },
            ),
          ],
        ),

        // --- ALUNOS ---
        GoRoute(
          path: AppRoutes.alunos,
          builder: (context, state) => const AlunosListScreen(),
          routes: [
            GoRoute(
              path: AppRoutes.alunosCreate.toString(),
              builder: (context, state) => const AlunosCreateScreen(),
            ),
          ],
        ),

        // --- FOLHAS ---
        GoRoute(
          path: AppRoutes.folhas,
          builder: (context, state) => const FolhasListScreen(),
          routes: [
            GoRoute(
              path: AppRoutes.folhasCreate.toString(),
              builder: (context, state) => const FolhasCreateScreen(),
            ),
          ],
        ),

        // --- GABARITOS ---
        GoRoute(
          path: AppRoutes.gabaritos,
          builder: (context, state) => const GabaritosListScreen(),
          routes: [
            // ADICIONE ESTA SUB-ROTA
            GoRoute(
              path: AppRoutes.gabaritosCreate.toString(),
              builder: (context, state) => const GabaritosCreateScreen(),
            ),
          ],
        ),

        // --- CORREÇÕES ---
        GoRoute(
          path: AppRoutes.correcoes,
          builder: (context, state) => const CorrecoesListScreen(),
        ),

        GoRoute(
          path: AppRoutes.correcoes,
          builder: (context, state) => const CorrecoesListScreen(),
          routes: [
            // Sub-rota: Scanner (Upload)
            GoRoute(
              path: AppRoutes.correcoesScanner.toString(),
              builder: (context, state) => const CorrecoesScannerScreen(),
            ),
            // Sub-rota: Review (Correção Manual/Visual)
            GoRoute(
              path: AppRoutes.correcoesReview.toString(),
              builder: (context, state) {
                // Recupera os objetos passados via "extra"
                final extra = state.extra as Map<String, dynamic>;
                final gabarito = extra['gabarito'] as GabaritoModelo;
                final paginas = extra['paginas'] as List<File>;
                final turmaId = extra['turmaId'] as int;

                return CorrecoesReviewScreen(
                  gabarito: gabarito,
                  paginas: paginas,
                  turmaId: turmaId,
                );
              },
            ),

            GoRoute(
              path:
                  'details/:id', // Note: 'details/:id' is relative to /correcoes
              builder: (context, state) {
                final id = state.pathParameters['id']!;
                return CorrecoesDetailsScreen(gabaritoId: id);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);
