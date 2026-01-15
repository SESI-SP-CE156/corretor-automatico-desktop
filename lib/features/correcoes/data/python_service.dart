import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

const int _currentSetupVersion = 1;

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

  Process? _workerProcess;
  Completer<void>? _workerReadyCompleter;
  Completer<Map<String, dynamic>>? _currentTaskCompleter;
  StreamSubscription? _stdoutSubscription;
  StreamSubscription? _stderrSubscription;

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
    if (_isInitialized && _workerProcess != null) {
      stateNotifier.value = const PythonSetupState(
        message: 'Pronto',
        progress: 1.0,
      );
      return;
    }

    try {
      // 1. Garante dependências (pip, venv)
      await _setupVenvAndRequirements();

      // 2. Inicia o PROCESSO PERSISTENTE
      await _startWorkerProcess();

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
      _killWorker(); // Limpa se falhou
      rethrow;
    }
  }

  Future<void> _startWorkerProcess() async {
    _killWorker(); // Garante que não tem outro rodando

    final executable = await _venvPythonExecutable;

    _updateStatus("Iniciando motor de IA...", 0.95);

    _workerProcess = await Process.start(executable, [
      _scriptPath,
    ], runInShell: Platform.isWindows);

    _workerReadyCompleter = Completer<void>();

    // Escuta STDOUT (Onde virão os resultados)
    _stdoutSubscription = _workerProcess!.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) {
          _handleWorkerOutput(line);
        });

    // Escuta STDERR (Logs de erro do Python)
    _stderrSubscription = _workerProcess!.stderr.transform(utf8.decoder).listen(
      (data) {
        debugPrint('[PY-ERR] $data');
      },
    );

    // Aguarda o Python imprimir "READY" (timeout de 30s para carregar libs pesadas)
    try {
      await _workerReadyCompleter!.future.timeout(const Duration(seconds: 40));
    } catch (e) {
      throw Exception("Tempo limite excedido ao iniciar IA. Verifique logs.");
    }
  }

  void _handleWorkerOutput(String line) {
    final trimmed = line.trim();

    // 1. Sinal de prontidão
    if (!_workerReadyCompleter!.isCompleted && trimmed == "READY") {
      debugPrint("[PY] Worker Ready!");
      _workerReadyCompleter!.complete();
      return;
    }

    // 2. Resposta de uma tarefa (JSON)
    if (_currentTaskCompleter != null && !_currentTaskCompleter!.isCompleted) {
      try {
        // Tenta parsear JSON
        if (trimmed.startsWith('{') && trimmed.endsWith('}')) {
          final json = jsonDecode(trimmed);
          _currentTaskCompleter!.complete(json);
          _currentTaskCompleter = null; // Libera para próxima
        } else {
          debugPrint("[PY-LOG] $trimmed"); // Logs normais (print) do python
        }
      } catch (e) {
        debugPrint("[PY-PARSE-ERR] $e na linha: $trimmed");
      }
    } else {
      debugPrint("[PY-IDLE] $trimmed");
    }
  }

  void _killWorker() {
    _stdoutSubscription?.cancel();
    _stderrSubscription?.cancel();
    _workerProcess?.kill();
    _workerProcess = null;
    _isInitialized = false;
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

    final appDir = await getApplicationSupportDirectory();
    final versionFile = File(
      p.join(appDir.path, '.setup_completed_v$_currentSetupVersion'),
    );

    if (await venvFile.exists() && await versionFile.exists()) {
      _updateStatus('Ambiente verificado (Cache).', 1.0);
      return;
    }

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

    await _extractAsset('assets/models/modelo_yolo.pt', 'modelo_yolo.pt');
    await _extractAsset('assets/models/omr_model.keras', 'omr_model.keras');
    await _extractAsset('assets/models/omr_labels.json', 'omr_labels.json');

    await versionFile.create();

    final dirList = appDir.listSync();
    for (var entity in dirList) {
      if (entity is File &&
          p.basename(entity.path).startsWith('.setup_completed_v') &&
          p.basename(entity.path) !=
              '.setup_completed_v$_currentSetupVersion') {
        await entity.delete();
      }
    }

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
    if (!_isInitialized || _workerProcess == null) {
      await initialize();
    }

    if (_currentTaskCompleter != null) {
      throw Exception("O corretor está ocupado processando outra imagem.");
    }

    _currentTaskCompleter = Completer<Map<String, dynamic>>();

    try {
      // --- LOGS VERBOSOS INICIAIS ---
      debugPrint("========================================");
      debugPrint("[Dart] Solicitando correção para: ${p.basename(imagePath)}");

      final modelsDir = await _modelsDirectory;

      final pathYolo = p.join(modelsDir, 'modelo_yolo.pt');
      final pathOmr = p.join(modelsDir, 'omr_model.keras');
      final pathLabels = p.join(modelsDir, 'omr_labels.json');

      final Map<String, dynamic> payload = {
        "caminho_imagem": imagePath,
        "layout_config": layoutConfig,
        "gabarito": gabarito,
        "model_paths": {"yolo": pathYolo, "omr": pathOmr, "labels": pathLabels},
      };

      final jsonStr = jsonEncode(payload);

      // --- LOG DO ENVIO ---
      debugPrint(
        "[Dart] Enviando payload (${jsonStr.length} bytes) para o Python Worker...",
      );
      // Se quiser ver o JSON inteiro, descomente a linha abaixo:
      // debugPrint("[Dart] JSON: $jsonStr");

      _workerProcess!.stdin.writeln(jsonStr);
      await _workerProcess!.stdin.flush();

      // Aguarda resposta
      final result = await _currentTaskCompleter!.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () {
          debugPrint("[Dart] TIMEOUT aguardando resposta do Python.");
          return {"sucesso": false, "erro": "Timeout na correção"};
        },
      );

      // --- LOG DA RESPOSTA ---
      debugPrint("[Dart] Resposta recebida. Sucesso: ${result['sucesso']}");
      if (result['sucesso'] == true) {
        debugPrint(
          "[Dart] Respostas detectadas: ${result['respostas_detectadas']}",
        );
      } else {
        debugPrint("[Dart] Erro retornado pelo Python: ${result['erro']}");
      }
      debugPrint("========================================");

      return result;
    } catch (e) {
      _currentTaskCompleter = null;
      debugPrint("[Dart] EXCEPTION crítica em corrigirProva: $e");
      return {"sucesso": false, "erro": e.toString()};
    }
  }

  void dispose() {
    _killWorker();
  }
}
