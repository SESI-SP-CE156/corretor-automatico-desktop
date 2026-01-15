import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PythonSetupState {
  final String message;
  final double progress; // 0.0 a 1.0
  final bool hasError;

  const PythonSetupState({
    required this.message,
    required this.progress,
    this.hasError = false,
  });
}

class PythonService {
  static final PythonService _instance = PythonService._internal();
  factory PythonService() => _instance;
  PythonService._internal();

  static String? _cachedVenvPython;

  final ValueNotifier<PythonSetupState> stateNotifier = ValueNotifier(
    const PythonSetupState(message: 'Aguardando início...', progress: 0.0),
  );

  bool _isInitialized = false;

  String get _scriptPath {
    if (kDebugMode) {
      return 'assets/python/omr_worker.py';
    } else {
      // Ajuste para estrutura de Release do Flutter Desktop
      return p.join(
        p.dirname(Platform.resolvedExecutable),
        'data',
        'flutter_assets',
        'assets',
        'python',
        'omr_worker.py',
      );
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) {
      stateNotifier.value = const PythonSetupState(
        message: 'Pronto',
        progress: 1.0,
      );
      return;
    }

    try {
      await _setupVenvAndRequirements();
      _isInitialized = true;
      stateNotifier.value = const PythonSetupState(
        message: 'Inicialização concluída!',
        progress: 1.0,
      );
    } catch (e) {
      stateNotifier.value = PythonSetupState(
        message: 'Erro na configuração: $e',
        progress: 0.0,
        hasError: true,
      );
      debugPrint('Erro crítico no setup Python: $e');
      rethrow;
    }
  }

  Future<String> get _venvDirectory async {
    final appDir = await getApplicationSupportDirectory();
    return p.join(appDir.path, 'sesi_omr_venv');
  }

  Future<String> get _modelsDirectory async {
    final appDir = await getApplicationSupportDirectory();
    final modelsDir = Directory(p.join(appDir.path, 'models'));
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  Future<String> get _venvPythonExecutable async {
    if (_cachedVenvPython != null) return _cachedVenvPython!;
    final venvDir = await _venvDirectory;
    if (Platform.isWindows) {
      _cachedVenvPython = p.join(venvDir, 'Scripts', 'python.exe');
    } else {
      _cachedVenvPython = p.join(venvDir, 'bin', 'python');
    }
    return _cachedVenvPython!;
  }

  void _updateStatus(String msg, double progress) {
    stateNotifier.value = PythonSetupState(message: msg, progress: progress);
    debugPrint('[PythonService] $msg');
  }

  Future<String> _findSystemPython() async {
    List<String> candidates;
    if (Platform.isWindows) {
      candidates = ['python', 'py -3.11', 'py -3.12', 'python3', 'py'];
    } else {
      candidates = ['python3.11', 'python3.12', 'python3.10', 'python3'];
    }

    _updateStatus('Procurando Python no sistema...', 0.1);

    for (final cmd in candidates) {
      try {
        final parts = cmd.split(' ');
        final executable = parts[0];
        final args = parts.length > 1
            ? [...parts.sublist(1), '--version']
            : ['--version'];
        final result = await Process.run(executable, args);
        if (result.exitCode == 0) return cmd;
      } catch (e) {
        continue;
      }
    }
    throw Exception(
      'Nenhum Python compatível encontrado. Instale o Python 3.10+.',
    );
  }

  Future<void> _createVenvParams(
    String systemPythonCmd,
    String venvPath,
  ) async {
    debugPrint('Criando venv: $venvPath usando $systemPythonCmd...');
    final parts = systemPythonCmd.split(' ');
    final executable = parts[0];
    final prefixArgs = parts.length > 1 ? parts.sublist(1) : <String>[];

    final result = await Process.run(executable, [
      ...prefixArgs,
      '-m',
      'venv',
      venvPath,
      '--clear',
    ]);
    if (result.exitCode != 0) {
      throw Exception('Falha ao criar venv: ${result.stderr}');
    }
  }

  Future<int> _runPip(String pythonExe, List<String> args) async {
    final process = await Process.start(pythonExe, [
      '-m',
      'pip',
      ...args,
    ], runInShell: Platform.isWindows);
    process.stdout.transform(utf8.decoder).listen(stdout.write);
    process.stderr.transform(utf8.decoder).listen(stderr.write);
    return await process.exitCode;
  }

  Future<void> _setupVenvAndRequirements() async {
    final venvPython = await _venvPythonExecutable;
    final venvDir = await _venvDirectory;
    final venvFile = File(venvPython);

    // 1. Verificar/Criar VENV
    if (!await venvFile.exists()) {
      final systemPython = await _findSystemPython();
      _updateStatus('Criando ambiente virtual (venv)...', 0.2);
      await _createVenvParams(systemPython, venvDir);
    }

    // 2. Instalar PyTorch (Pesado)
    if (!Platform.isMacOS) {
      _updateStatus('Baixando bibliotecas de IA (Isso pode demorar)...', 0.4);
      await _runPip(venvPython, [
        'install',
        'torch',
        'torchvision',
        '--index-url',
        'https://download.pytorch.org/whl/cpu',
        '--no-cache-dir',
      ]);
    }

    // 3. Instalar Requirements.txt
    _updateStatus('Instalando dependências auxiliares...', 0.7);

    final String requirementsContent = await rootBundle.loadString(
      'assets/python/requirements.txt',
    );
    final Directory tempDir = await getTemporaryDirectory();
    final File tempRequirementsFile = File(
      p.join(tempDir.path, 'requirements_temp.txt'),
    );
    await tempRequirementsFile.writeAsString(requirementsContent);

    await _runPip(venvPython, [
      'install',
      '-r',
      tempRequirementsFile.path,
      '--disable-pip-version-check',
      '--no-warn-script-location',
      '--no-cache-dir',
    ]);

    if (await tempRequirementsFile.exists()) {
      await tempRequirementsFile.delete();
    }

    // 4. Extrair Modelos (Labels, YOLO, Keras)
    _updateStatus('Configurando modelos de IA...', 0.9);
    // (O método corrigirProva faz a extração, mas podemos pré-extrair aqui se quiser,
    // ou deixar como está e considerar 100% após o pip)

    _updateStatus('Ambiente configurado!', 1.0);
  }

  Future<String> _extractAsset(String assetPath, String targetFilename) async {
    final modelsDir = await _modelsDirectory;
    final targetFile = File(p.join(modelsDir, targetFilename));
    // Removemos a verificação "if exists" para FORÇAR a atualização do JSON
    // caso você tenha alterado ele recentemente.
    debugPrint('Extraindo $targetFilename...');
    final byteData = await rootBundle.load(assetPath);
    await targetFile.writeAsBytes(byteData.buffer.asUint8List());
    return targetFile.path;
  }

  Future<Map<String, dynamic>> corrigirProva({
    required String imagePath,
    required Map<String, dynamic> layoutConfig,
    required Map<String, String> gabarito,
  }) async {
    await initialize();

    try {
      final executable = await _venvPythonExecutable;

      // 1. Extração dos modelos e LABELS
      final pathYolo = await _extractAsset(
        'assets/models/modelo_yolo.pt',
        'modelo_yolo.pt',
      );
      final pathOmr = await _extractAsset(
        'assets/models/omr_model.keras',
        'omr_model.keras',
      );

      // CRÍTICO: Extrair o arquivo JSON de labels
      final pathLabels = await _extractAsset(
        'assets/models/omr_labels.json',
        'omr_labels.json',
      );

      final Map<String, dynamic> payload = {
        "caminho_imagem": imagePath,
        "layout_config": layoutConfig,
        "gabarito": gabarito,
        "model_paths": {
          "yolo": pathYolo,
          "omr": pathOmr,
          "labels": pathLabels, // Enviando o caminho para o Python
        },
      };

      final process = await Process.start(executable, [
        _scriptPath,
      ], runInShell: Platform.isWindows);

      final stdoutBuffer = StringBuffer();
      final stderrBuffer = StringBuffer();

      process.stdout.transform(utf8.decoder).listen((data) {
        stdout.write('[PY] $data');
        stdoutBuffer.write(data);
      });
      process.stderr.transform(utf8.decoder).listen((data) {
        stderr.write('[PY-ERR] $data');
        stderrBuffer.write(data);
      });

      process.stdin.writeln(jsonEncode(payload));
      await process.stdin.flush();
      await process.stdin.close();

      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        throw Exception("Erro no script Python: ${stderrBuffer.toString()}");
      }

      final outputString = stdoutBuffer.toString().trim();
      final jsonStart = outputString.indexOf('{');
      final jsonEnd = outputString.lastIndexOf('}');
      if (jsonStart != -1 && jsonEnd != -1) {
        return jsonDecode(outputString.substring(jsonStart, jsonEnd + 1));
      }

      throw Exception("O script Python não retornou um JSON válido.");
    } catch (e) {
      print("Erro no serviço de correção: $e");
      return {"sucesso": false, "erro": e.toString()};
    }
  }
}
