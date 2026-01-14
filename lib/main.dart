// lib/main.dart

import 'package:corretor_desktop/core/router/app_router.dart';
import 'package:corretor_desktop/features/correcoes/data/python_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:sizer/sizer.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    pdfrxFlutterInitialize();

    WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

    await windowManager.ensureInitialized();

    WindowOptions windowOptions = const WindowOptions(
      center: true,
      skipTaskbar: false,
      title: 'Corretor Automático SESI',
      size: Size(1280, 720),
      minimumSize: Size(800, 600),
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    // --- MUDANÇA AQUI: Sem 'await' ---
    // Inicia a configuração do Python em background (fire-and-forget).
    // O PythonService gerencia o estado internamente.
    PythonService().initialize();
    // ---------------------------------
  } catch (e) {
    debugPrint('Exception durante inicialização: $e');
  }

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    FlutterNativeSplash.remove();

    // Definição das cores base
    const primaryColor = Color(0xFFDA251D); // Vermelho SESI
    const backgroundColor = Color(0xFFF3F3F3); // Cinza Microsoft/Fluent
    const surfaceColor = Colors.white;
    const borderColor = Color(0xFFE0E0E0); // Bordas sutis
    const textColor = Color(0xFF242424);

    return Sizer(
      builder: (context, orientation, screenType) {
        return MaterialApp.router(
          title: "Corretor Automático SESI",
          debugShowCheckedModeBanner: false,
          routerConfig: appRouter,
          theme: ThemeData(
            useMaterial3: true,
            visualDensity: VisualDensity.compact, // UI mais densa para Desktop
            // 1. Esquema de Cores
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              surface: surfaceColor,
              onSurface: textColor,
              surfaceContainerLow: backgroundColor, // Fundo do Scaffold
              outline: borderColor,
            ),

            // 2. Fundo Geral
            scaffoldBackgroundColor: backgroundColor,

            // 3. Tipografia (Estilo Limpo e Profissional)
            textTheme: GoogleFonts.openSansTextTheme().copyWith(
              displayLarge: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
                letterSpacing: -0.5,
              ),
              titleLarge: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
              bodyLarge: TextStyle(
                fontSize: 12.sp,
                color: const Color(0xFF424242),
              ),
              bodyMedium: TextStyle(
                fontSize: 11.sp,
                color: const Color(0xFF424242),
              ),
              labelLarge: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w600, // Botões
              ),
            ),

            // 4. Cartões (Fluent Style: Borda fina + Sombra difusa)
            cardTheme: CardThemeData(
              color: surfaceColor,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
              shadowColor: Colors.black.withOpacity(0.05), // Sombra muito suave
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  8,
                ), // Canto padrão Microsoft
                side: const BorderSide(color: borderColor, width: 1),
              ),
              margin: EdgeInsets.all(4.sp),
            ),

            // 5. Inputs (Caixas de Texto estilo Windows 11)
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: surfaceColor,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 12.sp,
                vertical: 14.sp, // Um pouco mais alto para conforto
              ),
              isDense: true,
              // Estado Normal
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4), // Canto de Input é 4px
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: borderColor),
              ),
              // Estado Focado (Borda Primary com espessura 2)
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(4),
                borderSide: const BorderSide(color: primaryColor, width: 2),
              ),
              // Labels
              labelStyle: GoogleFonts.openSans(
                color: Colors.grey[700],
                fontSize: 11.sp,
              ),
              floatingLabelStyle: GoogleFonts.openSans(
                color: primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),

            // 6. Botões Elevados (Ação Principal)
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 0, // Fluent prefere flat colors ou sombras mínimas
                padding: EdgeInsets.symmetric(
                  horizontal: 16.sp,
                  vertical: 14.sp,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    4,
                  ), // Canto de Botão é 4px
                ),
                textStyle: GoogleFonts.openSans(fontWeight: FontWeight.w600),
              ),
            ),

            // 7. Botões Contorno (Ação Secundária)
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: textColor,
                backgroundColor: Colors.transparent,
                side: const BorderSide(color: borderColor),
                padding: EdgeInsets.symmetric(
                  horizontal: 16.sp,
                  vertical: 14.sp,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            // 8. Botões de Texto (Links / Ações em tabelas)
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),

            // 9. Menu Lateral (Navigation Rail)
            navigationRailTheme: NavigationRailThemeData(
              backgroundColor: surfaceColor,
              elevation: 1,
              // Indicador estilo "Pílula suave" ou bloco
              indicatorColor: primaryColor.withOpacity(0.1),
              labelType: NavigationRailLabelType.all,

              // Ícones
              selectedIconTheme: const IconThemeData(
                color: primaryColor,
                size: 24,
              ),
              unselectedIconTheme: IconThemeData(
                color: Colors.grey[600],
                size: 24,
              ),

              // Textos do Menu
              selectedLabelTextStyle: GoogleFonts.openSans(
                color: primaryColor,
                fontSize: 9.sp,
                fontWeight: FontWeight.bold,
              ),
              unselectedLabelTextStyle: GoogleFonts.openSans(
                color: Colors.grey[600],
                fontSize: 9.sp,
                fontWeight: FontWeight.w500,
              ),
            ),

            // 10. Diálogos (Modais)
            dialogTheme: DialogThemeData(
              backgroundColor: surfaceColor,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: const BorderSide(color: borderColor),
              ),
              titleTextStyle: GoogleFonts.openSans(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),

            // 11. AppBar
            appBarTheme: AppBarTheme(
              backgroundColor: surfaceColor,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              scrolledUnderElevation: 1,
              shape: const Border(
                bottom: BorderSide(color: borderColor),
              ), // Linha sutil abaixo
              iconTheme: const IconThemeData(color: textColor),
              titleTextStyle: GoogleFonts.openSans(
                color: textColor,
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
              ),
            ),

            // 12. Checkbox
            checkboxTheme: CheckboxThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(3),
              ),
              side: const BorderSide(color: Colors.grey, width: 1.5),
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return primaryColor;
                }
                return null; // Transparente
              }),
            ),
          ),
        );
      },
    );
  }
}
