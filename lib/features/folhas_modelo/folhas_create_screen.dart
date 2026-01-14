import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:corretor_desktop/features/folhas_modelo/data/folha_model.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/folhas_repository.dart';
import 'package:corretor_desktop/features/turmas/data/ano_model.dart';
import 'package:corretor_desktop/features/turmas/data/turmas_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdfrx/pdfrx.dart';

// Enum para controlar qual região estamos desenhando
enum SelectionStep { none, nomeAluno, turma, gabaritoEsq, gabaritoDir }

class FolhasCreateScreen extends StatefulWidget {
  const FolhasCreateScreen({super.key});

  @override
  State<FolhasCreateScreen> createState() => _FolhasCreateScreenState();
}

class _FolhasCreateScreenState extends State<FolhasCreateScreen> {
  final _folhasRepo = FolhasRepository();
  final _turmasRepo = TurmasRepository();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _qtdQuestoesController = TextEditingController();

  List<Ano> _anosDisponiveis = [];
  final List<int> _anosSelecionadosIds = [];
  File? _selectedImage;
  ui.Image? _imageDimensions; // Para guardar as dimensões reais da imagem

  // Geometria e Desenho
  SelectionStep _currentStep = SelectionStep.none;
  final Map<SelectionStep, Rect> _regions = {};
  Rect? _tempRect;
  Offset? _startDrag;

  // Variáveis para cálculo de escala (Tela vs Imagem Real)
  double _scaleFactor = 1.0;
  Offset _imageOffset = Offset.zero;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAnos();
  }

  Future<void> _loadAnos() async {
    try {
      final anos = await _turmasRepo.getAnos();
      if (mounted) setState(() => _anosDisponiveis = anos);
    } catch (e) {
      debugPrint('Erro ao carregar anos: $e');
    }
  }

  // --- SELEÇÃO DE ARQUIVO ---
  Future<void> _pickImage() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null) {
        final String originalPath = result.files.single.path!;

        setState(() => _isSaving = true);

        try {
          File imageFile;
          // Converte PDF sempre
          if (p.extension(originalPath).toLowerCase() == '.pdf') {
            imageFile = await _convertPdfToImage(originalPath);
          } else {
            imageFile = File(
              originalPath,
            ); // Caso queira suportar imagens diretas no futuro
          }

          // Carrega dimensoes reais para cálculo
          final data = await imageFile.readAsBytes();
          final uiImage = await decodeImageFromList(data);

          setState(() {
            _selectedImage = imageFile;
            _imageDimensions = uiImage;
            _regions.clear();
            _currentStep = SelectionStep.none;
          });
        } catch (e) {
          if (mounted)
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text("Erro: $e")));
        } finally {
          if (mounted) setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      debugPrint("Erro pickImage: $e");
    }
  }

  Future<File> _convertPdfToImage(String pdfPath) async {
    final doc = await PdfDocument.openFile(pdfPath);
    final page = doc.pages[0];

    // Define tamanho fixo de 600x800 conforme solicitado
    const int targetWidth = 600;
    const int targetHeight = 800;

    // Renderiza a página forçando as dimensões alvo
    // O pdfrx não usa 'format' aqui, ele gera uma imagem bruta em memória
    final pdfImage = await page.render(
      width: targetWidth,
      height: targetHeight,
    );

    if (pdfImage == null) throw Exception("Falha ao renderizar PDF");

    final image = await pdfImage.createImage();

    // A conversão para PNG acontece AQUI
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) throw Exception("Falha ao gerar bytes da imagem");

    final buffer = byteData.buffer.asUint8List();

    final directory = await getApplicationSupportDirectory();
    final fileName =
        '${p.basenameWithoutExtension(pdfPath)}_mod_${DateTime.now().millisecondsSinceEpoch}.png';
    final savedImage = File(p.join(directory.path, fileName));
    await savedImage.writeAsBytes(buffer);

    doc.dispose();
    return savedImage;
  }

  // --- INPUT HANDLERS ---
  void _onPanStart(DragStartDetails details) {
    if (_currentStep == SelectionStep.none || _selectedImage == null) return;
    // Converte coordenada local (do widget) para coordenada relativa à imagem desenhada
    final localPos = details.localPosition;
    setState(() {
      _startDrag = localPos;
      _tempRect = Rect.fromPoints(_startDrag!, _startDrag!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (_startDrag == null) return;
    setState(() {
      _tempRect = Rect.fromPoints(_startDrag!, details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (_startDrag == null || _tempRect == null) return;
    setState(() {
      _regions[_currentStep] = _tempRect!;
      _tempRect = null;
      _startDrag = null;
      _currentStep = SelectionStep.none;
    });
  }

  // --- LÓGICA DE CALIBRAÇÃO (MATEMÁTICA) ---
  Map<String, dynamic> _gerarLayoutConfig() {
    if (_imageDimensions == null) return {};

    int totalQ = int.tryParse(_qtdQuestoesController.text) ?? 0;
    int qPorColuna = (totalQ / 2)
        .ceil(); // Assume 2 colunas por padrão se houver Dir

    // Helper para converter Rect da Tela -> Rect da Imagem Real
    List<int> toImgRect(Rect screenRect) {
      // Remove o offset de centralização (letterbox)
      double x = (screenRect.left - _imageOffset.dx) / _scaleFactor;
      double y = (screenRect.top - _imageOffset.dy) / _scaleFactor;
      double w = screenRect.width / _scaleFactor;
      double h = screenRect.height / _scaleFactor;

      // Clamping para não sair da imagem
      return [x.toInt(), y.toInt(), w.toInt(), h.toInt()];
    }

    // Calcula coordenadas da Coluna 1
    Map<String, dynamic> config = {
      'total_questoes': totalQ,
      'questoes_por_coluna': qPorColuna,
      'opcoes_por_questao': 5, // Padrão A-E
    };

    if (_regions.containsKey(SelectionStep.gabaritoEsq)) {
      final rect = toImgRect(_regions[SelectionStep.gabaritoEsq]!);

      // Matemática do Calibrador Python:
      // Largura da ROI / 5 opções (A, B, C, D, E) = espaço horizontal
      int espacoH = (rect[2] / 5).round();
      // Altura da ROI / qtd questoes na coluna = espaço vertical
      int espacoV = (rect[3] / qPorColuna).round();

      // Centro da primeira bolha (A da Q1): TopLeft + Metade do espaço
      int startX = rect[0] + (espacoH ~/ 2);
      int startY = rect[1] + (espacoV ~/ 2);

      config['coluna_1_origem_xy'] = [startX, startY];
      config['espaco_h_bolha'] = espacoH;
      config['espaco_v_bolha'] = espacoV;
      config['raio_bolha'] = (min(espacoH, espacoV) / 2 * 0.7)
          .toInt(); // 70% do espaço

      // ROI Completa para debug/display
      config['ROI_OMR_COL1'] = rect;
    }

    if (_regions.containsKey(SelectionStep.gabaritoDir)) {
      final rect = toImgRect(_regions[SelectionStep.gabaritoDir]!);

      // Usa o mesmo espaçamento calculado na col 1, apenas acha o inicio
      int espacoH = config['espaco_h_bolha'] ?? (rect[2] / 5).round();
      int espacoV =
          config['espaco_v_bolha'] ?? (rect[3] / (totalQ - qPorColuna)).round();

      int startX = rect[0] + (espacoH ~/ 2);
      int startY = rect[1] + (espacoV ~/ 2);

      config['coluna_2_origem_xy'] = [startX, startY];
      config['ROI_OMR_COL2'] = rect;
    }

    // ROIs de Identificação
    if (_regions.containsKey(SelectionStep.nomeAluno)) {
      config['ROI_OCR_NOME'] = toImgRect(_regions[SelectionStep.nomeAluno]!);
    }
    if (_regions.containsKey(SelectionStep.turma)) {
      config['ROI_OCR_TURMA'] = toImgRect(_regions[SelectionStep.turma]!);
    }

    return config;
  }

  // --- SALVAR ---
  Future<void> _saveFolha() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImage == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Selecione um PDF.")));
      return;
    }
    if (!_regions.containsKey(SelectionStep.gabaritoEsq)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Marque ao menos a Coluna Esquerda.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Gera a configuração baseada no desenho
      final layoutConfig = _gerarLayoutConfig();

      // 2. Cria o objeto com os parâmetros CORRETOS
      final novaFolha = FolhaModelo(
        nome: _nomeController.text,
        imagemModeloPath: _selectedImage!.path, // Parâmetro corrigido
        layoutConfig: layoutConfig, // Parâmetro corrigido (Map JSON)
      );

      // 3. Salva no banco
      await _folhasRepo.createFolha(novaFolha, _anosSelecionadosIds);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Modelo salvo com sucesso!")),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nova Folha Modelo")),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: _buildEditorArea()),
          _buildSideForm(),
        ],
      ),
    );
  }

  Widget _buildEditorArea() {
    return Container(
      color: Colors.grey.shade200,
      padding: const EdgeInsets.all(16),
      child: Center(
        child: _selectedImage == null
            ? _buildUploadPlaceholder()
            : _buildImageEditor(),
      ),
    );
  }

  Widget _buildImageEditor() {
    // LayoutBuilder é crucial para sabermos o tamanho disponível na tela
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_imageDimensions != null) {
          // Calcula a escala "contain"
          double wRatio = constraints.maxWidth / _imageDimensions!.width;
          double hRatio = constraints.maxHeight / _imageDimensions!.height;
          double scale = min(wRatio, hRatio);

          _scaleFactor = scale;

          // Calcula o offset para centralizar a imagem no container
          double renderedWidth = _imageDimensions!.width * scale;
          double renderedHeight = _imageDimensions!.height * scale;
          double dx = (constraints.maxWidth - renderedWidth) / 2;
          double dy = (constraints.maxHeight - renderedHeight) / 2;
          _imageOffset = Offset(dx, dy);
        }

        return GestureDetector(
          onPanStart: _onPanStart,
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.file(_selectedImage!, fit: BoxFit.contain),
              // Camada de Desenho (CustomPaint)
              Positioned.fill(
                child: CustomPaint(
                  painter: RegionPainter(
                    regions: _regions,
                    tempRect: _tempRect,
                    activeColor: _getColorForStep(_currentStep),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSideForm() {
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Configurações",
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nomeController,
                decoration: const InputDecoration(labelText: 'Nome do Modelo'),
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const SizedBox(height: 16),
              const Text(
                "Séries Aplicáveis",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 8,
                children: _anosDisponiveis.map((ano) {
                  final isSelected = _anosSelecionadosIds.contains(ano.id);
                  return FilterChip(
                    label: Text(
                      ano.nomeExibicao.replaceAll('Ensino Médio', 'EM'),
                    ),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        val
                            ? _anosSelecionadosIds.add(ano.id)
                            : _anosSelecionadosIds.remove(ano.id);
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _qtdQuestoesController,
                decoration: const InputDecoration(
                  labelText: 'Qtd. Total de Questões',
                ),
                keyboardType: TextInputType.number,
                validator: (v) => v!.isEmpty ? 'Obrigatório' : null,
              ),
              const Divider(height: 32),
              Text(
                "Mapeamento (Desenhe as caixas)",
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _buildStepTile(
                "1. Nome do Aluno",
                SelectionStep.nomeAluno,
                Colors.blue,
              ),
              _buildStepTile("2. Turma/RM", SelectionStep.turma, Colors.orange),
              _buildStepTile(
                "3. Coluna 1 (A-E)",
                SelectionStep.gabaritoEsq,
                Colors.green,
              ),
              _buildStepTile(
                "4. Coluna 2 (A-E)",
                SelectionStep.gabaritoDir,
                Colors.green.shade800,
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _saveFolha,
                  icon: const Icon(Icons.save),
                  label: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("SALVAR MODELO"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepTile(String label, SelectionStep step, Color color) {
    final isDone = _regions.containsKey(step);
    final isActive = _currentStep == step;
    return ListTile(
      leading: Icon(
        isDone ? Icons.check_circle : Icons.circle_outlined,
        color: isDone ? color : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          color: isActive ? color : null,
        ),
      ),
      onTap: () => setState(() => _currentStep = step),
      selected: isActive,
      selectedTileColor: color.withOpacity(0.1),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );
  }

  Widget _buildUploadPlaceholder() {
    return InkWell(
      onTap: _pickImage,
      child: Container(
        width: 300,
        height: 200,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.upload_file, size: 48, color: Colors.grey),
            Text("Clique para carregar PDF"),
          ],
        ),
      ),
    );
  }

  Color _getColorForStep(SelectionStep step) {
    switch (step) {
      case SelectionStep.nomeAluno:
        return Colors.blue;
      case SelectionStep.turma:
        return Colors.orange;
      case SelectionStep.gabaritoEsq:
        return Colors.green;
      case SelectionStep.gabaritoDir:
        return Colors.green.shade800;
      default:
        return Colors.grey;
    }
  }
}

class RegionPainter extends CustomPainter {
  final Map<SelectionStep, Rect> regions;
  final Rect? tempRect;
  final Color activeColor;
  RegionPainter({
    required this.regions,
    this.tempRect,
    required this.activeColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    final fill = Paint()..style = PaintingStyle.fill;

    regions.forEach((step, rect) {
      Color c = Colors.grey;
      if (step == SelectionStep.nomeAluno) c = Colors.blue;
      if (step == SelectionStep.turma) c = Colors.orange;
      if (step == SelectionStep.gabaritoEsq) c = Colors.green;
      if (step == SelectionStep.gabaritoDir) c = Colors.green.shade800;

      paint.color = c;
      fill.color = c.withOpacity(0.3);
      canvas.drawRect(rect, fill);
      canvas.drawRect(rect, paint);
    });

    if (tempRect != null) {
      paint.color = activeColor;
      fill.color = activeColor.withOpacity(0.3);
      canvas.drawRect(tempRect!, fill);
      canvas.drawRect(tempRect!, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
