import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class PythonService {
  static String? _cachedVenvPython;
  static Future<void>? _initTask;

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

  Future<void> initialize() {
    _initTask ??= _setupVenvAndRequirements();
    return _initTask!;
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

  Future<String> _findSystemPython() async {
    List<String> candidates;
    if (Platform.isWindows) {
      candidates = ['python', 'py -3.11', 'py -3.12', 'python3', 'py'];
    } else {
      candidates = ['python3.11', 'python3.12', 'python3.10', 'python3'];
    }

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
    throw Exception('Nenhum Python compatível encontrado no sistema.');
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
    if (result.exitCode != 0)
      throw Exception('Falha ao criar venv: ${result.stderr}');
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
    try {
      final venvPython = await _venvPythonExecutable;
      final venvDir = await _venvDirectory;
      final venvFile = File(venvPython);

      if (!await venvFile.exists()) {
        final systemPython = await _findSystemPython();
        await _createVenvParams(systemPython, venvDir);
      }

      if (!Platform.isMacOS) {
        await _runPip(venvPython, [
          'install',
          'torch',
          'torchvision',
          '--index-url',
          'https://download.pytorch.org/whl/cpu',
          '--no-cache-dir',
        ]);
      }

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

      if (await tempRequirementsFile.exists())
        await tempRequirementsFile.delete();
      debugPrint('✅ Ambiente Python configurado.');
    } catch (e) {
      debugPrint('Erro crítico no setup Python: $e');
      _initTask = null;
      rethrow;
    }
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
