import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';

class ScaffoldWithRail extends StatelessWidget {
  // Agora recebemos o 'child' (a tela atual) em vez do 'navigationShell'
  const ScaffoldWithRail({super.key, required this.child});

  final Widget child;

  // Função para descobrir qual aba está ativa com base na URL
  int _calculateSelectedIndex(BuildContext context) {
    final String location = GoRouterState.of(context).uri.path;

    if (location.startsWith(AppRoutes.alunos)) return 1;
    if (location.startsWith(AppRoutes.folhas)) return 2;
    if (location.startsWith(AppRoutes.gabaritos)) return 3;
    if (location.startsWith(AppRoutes.correcoes)) return 4;

    // Default: Turmas (Index 0)
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _calculateSelectedIndex(context);

    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (int index) {
              // Navegação manual baseada no índice clicado
              switch (index) {
                case 0:
                  context.go(AppRoutes.turmas);
                  break;
                case 1:
                  context.go(AppRoutes.alunos);
                  break;
                case 2:
                  context.go(AppRoutes.folhas);
                  break;
                case 3:
                  context.go(AppRoutes.gabaritos);
                  break;
                case 4:
                  context.go(AppRoutes.correcoes);
                  break;
              }
            },
            labelType: NavigationRailLabelType.all,
            leading: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SvgPicture.asset(
                'assets/vectors/sesi-logo.svg',
                semanticsLabel: 'SESI Logo',
                placeholderBuilder: (BuildContext context) => Container(
                  child: const CircularProgressIndicator.adaptive(),
                ),
                width: 72,
              ),
            ),
            // Estilos para garantir que o texto fique legível
            selectedLabelTextStyle: TextStyle(
              color: Theme.of(context).primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 10.sp,
            ),
            unselectedLabelTextStyle: TextStyle(
              color: Colors.grey[700],
              fontSize: 10.sp,
            ),
            destinations: const [
              NavigationRailDestination(
                icon: Icon(Icons.class_outlined),
                selectedIcon: Icon(Icons.class_),
                label: Text('Turmas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                selectedIcon: Icon(Icons.people),
                label: Text('Alunos'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.description_outlined),
                selectedIcon: Icon(Icons.description),
                label: Text('Folhas'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.assignment_turned_in_outlined),
                selectedIcon: Icon(Icons.assignment_turned_in),
                label: Text('Gabarito'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check),
                label: Text('Correções'),
              ),
            ],
          ),

          const VerticalDivider(thickness: 1, width: 1),

          // Exibe o conteúdo da rota atual
          Expanded(child: child),
        ],
      ),
    );
  }
}
