import 'dart:io';

import 'package:corretor_desktop/core/router/app_routes.dart';
import 'package:corretor_desktop/features/correcoes/data/correcao_service.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabarito_model.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabaritos_repository.dart';
import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:corretor_desktop/features/turmas/data/turmas_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

class CorrecoesScannerScreen extends StatefulWidget {
  const CorrecoesScannerScreen({super.key});

  @override
  State<CorrecoesScannerScreen> createState() => _CorrecoesScannerScreenState();
}

class _CorrecoesScannerScreenState extends State<CorrecoesScannerScreen> {
  final _gabaritosRepo = GabaritosRepository();
  final _turmasRepo = TurmasRepository();
  final _service = CorrecaoService();

  List<GabaritoModelo> _gabaritos = [];
  List<Turma> _turmasDisponiveis = [];

  GabaritoModelo? _selectedGabarito;
  Turma? _selectedTurma;
  File? _selectedPdf;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadGabaritos();
  }

  Future<void> _loadGabaritos() async {
    final list = await _gabaritosRepo.getAllGabaritos();
    if (mounted) setState(() => _gabaritos = list);
  }

  Future<void> _onGabaritoChanged(GabaritoModelo? gabarito) async {
    setState(() {
      _selectedGabarito = gabarito;
      _selectedTurma = null;
      _turmasDisponiveis = [];
    });

    if (gabarito != null && gabarito.anoId != null) {
      final turmas = await _turmasRepo.getTurmasByAno(gabarito.anoId!);
      if (mounted) setState(() => _turmasDisponiveis = turmas);
    }
  }

  Future<void> _pickPdf() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'], // Garante apenas PDF
      );

      if (result != null && result.files.single.path != null) {
        setState(() => _selectedPdf = File(result.files.single.path!));
      }
    } catch (e) {
      // Ignora erro de JSON do Linux se o arquivo não foi selecionado
      debugPrint('Erro no FilePicker (provavelmente cancelado): $e');
    }
  }

  Future<void> _iniciarCorrecao() async {
    if (_selectedGabarito == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Selecione o Gabarito.')));
      return;
    }
    if (_selectedTurma == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a Turma da prova.')),
      );
      return;
    }
    if (_selectedPdf == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o PDF das provas.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      // 1. Processa PDF em imagens
      final paginas = await _service.extrairPaginasDoPdf(_selectedPdf!.path);

      if (!mounted) return;

      // 2. Navega para tela de revisão
      context.push(
        '${AppRoutes.correcoes}/review',
        extra: {
          'gabarito': _selectedGabarito,
          'paginas': paginas,
          'turmaId': _selectedTurma!.id, // Envia a turma para filtrar alunos
        },
      );
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Erro ao processar: $e')));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Nova Correção"),
        leading: const BackButton(),
      ),
      body: Center(
        child: Container(
          width: 550,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(blurRadius: 15, color: Colors.black.withOpacity(0.1)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.document_scanner_outlined,
                size: 64,
                color: Colors.blueGrey,
              ),
              const SizedBox(height: 24),
              Text(
                "Configurar Leitura",
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // 1. GABARITO (Com Matéria e Ano)
              DropdownButtonFormField<GabaritoModelo>(
                value: _selectedGabarito,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selecione o Gabarito',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.assignment),
                ),
                // Exibe: "P1 Bimestral - Matemática - 9º EM"
                items: _gabaritos
                    .map(
                      (g) => DropdownMenuItem(
                        value: g,
                        child: Text(
                          "${g.nome} - ${g.materia} - ${g.anosExibicao}",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _onGabaritoChanged,
              ),
              const SizedBox(height: 16),

              // 2. TURMA (Obrigatória)
              DropdownButtonFormField<Turma>(
                value: _selectedTurma,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Selecione a Turma',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.people_alt),
                ),
                hint: const Text("Selecione o gabarito primeiro"),
                disabledHint: const Text("Selecione o gabarito primeiro"),
                items: _turmasDisponiveis
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text("${t.nomeAnoExibicao} ${t.letra}"),
                      ),
                    )
                    .toList(),
                onChanged: _turmasDisponiveis.isEmpty
                    ? null
                    : (v) => setState(() => _selectedTurma = v),
              ),
              const SizedBox(height: 16),

              // 3. UPLOAD PDF
              InkWell(
                onTap: _pickPdf,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey.shade400,
                      style: BorderStyle.solid,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey.shade50,
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.upload_file,
                        size: 32,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _selectedPdf != null
                            ? p.basename(_selectedPdf!.path)
                            : "Clique para carregar o PDF escaneado",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _selectedPdf != null
                              ? Colors.black87
                              : Colors.grey.shade600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_selectedPdf == null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            "(Apenas arquivos .pdf)",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // BOTÃO INICIAR
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _iniciarCorrecao,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(
                    _isProcessing ? "PROCESSANDO..." : "INICIAR CORREÇÃO",
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
