import 'dart:io';

import 'package:corretor_desktop/features/folhas_modelo/data/folha_model.dart';
import 'package:corretor_desktop/features/folhas_modelo/data/regra_nota_model.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabaritos_repository.dart';
import 'package:corretor_desktop/features/gabaritos/data/materia_model.dart';
import 'package:corretor_desktop/features/turmas/data/ano_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GabaritosCreateScreen extends StatefulWidget {
  const GabaritosCreateScreen({super.key});

  @override
  State<GabaritosCreateScreen> createState() => _GabaritosCreateScreenState();
}

class _GabaritosCreateScreenState extends State<GabaritosCreateScreen> {
  final _repository = GabaritosRepository();
  final _formKey = GlobalKey<FormState>();

  final _nomeController = TextEditingController();
  final _qtdController = TextEditingController();

  final _notaDeController = TextEditingController();
  final _notaAteController = TextEditingController();
  final _notaValorController = TextEditingController();
  final List<RegraNota> _regrasNotas = [];

  List<FolhaModelo> _folhas = [];
  List<Materia> _materias = [];

  // Variáveis para a seleção do Ano
  List<Ano> _anosCompativeis = []; // Anos que a folha permite

  FolhaModelo? _selectedFolha;
  int? _selectedAnoId; // ID do ano único selecionado
  String? _selectedMateriaId;

  final Map<int, String> _respostas = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final dados = await Future.wait([
        _repository.getFolhasModelo(),
        _repository.getMaterias(),
      ]);

      if (mounted) {
        setState(() {
          _folhas = dados[0] as List<FolhaModelo>;
          _materias = dados[1] as List<Materia>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Quando troca a folha, buscamos os anos vinculados a ela
  Future<void> _onFolhaChanged(FolhaModelo? folha) async {
    setState(() {
      _selectedFolha = folha;
      _selectedAnoId = null; // Reseta o ano anterior
      _anosCompativeis = []; // Limpa lista

      if (folha != null) {
        // Extrai a quantidade do JSON de configuração
        final qtd = folha.layoutConfig['total_questoes'];
        _qtdController.text = qtd?.toString() ?? '0';
      }
    });

    if (folha != null && folha.id != null) {
      // Busca anos no banco
      final anos = await _repository.getAnosByFolha(folha.id!);
      setState(() {
        _anosCompativeis = anos;
      });
    }
  }

  void _toggleResposta(int questao, String letra) {
    setState(() {
      if (_respostas[questao] == letra) {
        _respostas.remove(questao);
      } else {
        _respostas[questao] = letra;
      }
    });
  }

  void _addRegra() {
    final de = int.tryParse(_notaDeController.text);
    final ate = int.tryParse(_notaAteController.text);
    final nota = double.tryParse(
      _notaValorController.text.replaceAll(',', '.'),
    );

    if (de != null && ate != null && nota != null) {
      if (de > ate) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('"De" > "Até"')));
        return;
      }
      setState(() {
        _regrasNotas.add(RegraNota(inicio: de, fim: ate, nota: nota));
        _regrasNotas.sort((a, b) => a.inicio.compareTo(b.inicio));
      });
      _notaDeController.clear();
      _notaAteController.clear();
      _notaValorController.clear();
    }
  }

  void _removeRegra(RegraNota regra) {
    setState(() => _regrasNotas.remove(regra));
  }

  Future<void> _salvarGabarito() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedFolha == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Selecione uma Folha Modelo")),
      );
      return;
    }

    final qtd = int.tryParse(_qtdController.text) ?? 0;
    if (_respostas.length != qtd) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Preencha todas as $qtd questões.")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _repository.createGabarito(
        nome: _nomeController.text,
        materiaId: _selectedMateriaId!,
        folhaId: _selectedFolha!.id!,
        anoId: _selectedAnoId!,
        qtdQuestoes: qtd,
        respostas: _respostas,
        regras: _regrasNotas,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gabarito criado com sucesso!")),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Erro ao salvar: $e")));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Novo Gabarito"),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // PREVIEW DA FOLHA
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.grey.shade200,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _selectedFolha == null
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.description_outlined,
                                  size: 64,
                                  color: Colors.grey.shade400,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "Selecione uma Folha Modelo",
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            )
                          : Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade400),
                                boxShadow: [
                                  BoxShadow(
                                    blurRadius: 10,
                                    color: Colors.black.withOpacity(0.1),
                                  ),
                                ],
                              ),
                              // CORREÇÃO: Uso de imagemModeloPath
                              child: Image.file(
                                File(_selectedFolha!.imagemModeloPath),
                                fit: BoxFit.contain,
                              ),
                            ),
                    ),
                  ),
                ),

                // FORMULÁRIO
                Container(
                  width: 450,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      left: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "Dados da Prova",
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                const SizedBox(height: 24),

                                TextFormField(
                                  controller: _nomeController,
                                  decoration: const InputDecoration(
                                    labelText:
                                        'Nome do Gabarito (Ex: P1 - 1º Bimestre)',
                                  ),
                                  validator: (v) =>
                                      v!.isEmpty ? 'Obrigatório' : null,
                                ),
                                const SizedBox(height: 16),

                                // Seleção de Folha
                                DropdownButtonFormField<FolhaModelo>(
                                  value: _selectedFolha,
                                  decoration: const InputDecoration(
                                    labelText: 'Folha Modelo',
                                  ),
                                  items: _folhas
                                      .map(
                                        (f) => DropdownMenuItem(
                                          value: f,
                                          child: Text(f.nome),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: _onFolhaChanged,
                                  validator: (v) =>
                                      v == null ? 'Selecione a folha' : null,
                                ),
                                const SizedBox(height: 16),

                                // Seleção de Ano (Dependente da Folha)
                                DropdownButtonFormField<int>(
                                  value: _selectedAnoId,
                                  decoration: const InputDecoration(
                                    labelText: 'Série / Ano da Prova',
                                  ),
                                  hint: const Text(
                                    "Selecione a folha primeiro",
                                  ),
                                  disabledHint: const Text(
                                    "Selecione a folha primeiro",
                                  ),
                                  items: _anosCompativeis.isEmpty
                                      ? []
                                      : _anosCompativeis
                                            .map(
                                              (a) => DropdownMenuItem(
                                                value: a.id,
                                                child: Text(
                                                  a.nomeExibicao.replaceAll(
                                                    'Ensino Médio',
                                                    'EM',
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                  onChanged: _anosCompativeis.isEmpty
                                      ? null
                                      : (v) =>
                                            setState(() => _selectedAnoId = v),
                                  validator: (v) =>
                                      v == null ? 'Selecione a série' : null,
                                ),
                                const SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: DropdownButtonFormField<String>(
                                        value: _selectedMateriaId,
                                        decoration: const InputDecoration(
                                          labelText: 'Matéria',
                                        ),
                                        items: _materias
                                            .map(
                                              (m) => DropdownMenuItem(
                                                value: m.id,
                                                child: Text(m.nome),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (v) => setState(
                                          () => _selectedMateriaId = v,
                                        ),
                                        validator: (v) =>
                                            v == null ? 'Obrigatório' : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      flex: 1,
                                      child: TextFormField(
                                        controller: _qtdController,
                                        decoration: const InputDecoration(
                                          labelText: 'Qtd.',
                                        ),
                                        keyboardType: TextInputType.number,
                                        // Bloqueia edição manual se preferir que venha do modelo
                                        readOnly: true,
                                      ),
                                    ),
                                  ],
                                ),

                                const Divider(height: 32),

                                // --- SEÇÃO: ESCALA DE NOTAS (Opcional) ---
                                Text(
                                  "Escala de Notas (Opcional)",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextFormField(
                                        controller: _notaDeController,
                                        decoration: const InputDecoration(
                                          labelText: 'De',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _notaAteController,
                                        decoration: const InputDecoration(
                                          labelText: 'Até',
                                          isDense: true,
                                        ),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextFormField(
                                        controller: _notaValorController,
                                        decoration: const InputDecoration(
                                          labelText: 'Nota',
                                          isDense: true,
                                        ),
                                        keyboardType:
                                            TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                      ),
                                    ),
                                    IconButton.filled(
                                      onPressed: _addRegra,
                                      icon: const Icon(Icons.add),
                                    ),
                                  ],
                                ),
                                if (_regrasNotas.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Container(
                                    height: 100,
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: ListView.separated(
                                      itemCount: _regrasNotas.length,
                                      separatorBuilder: (_, __) =>
                                          const Divider(height: 1),
                                      itemBuilder: (ctx, i) {
                                        final r = _regrasNotas[i];
                                        return ListTile(
                                          dense: true,
                                          title: Text(
                                            "${r.inicio} a ${r.fim} acertos = Nota ${r.nota}",
                                          ),
                                          trailing: InkWell(
                                            onTap: () => _removeRegra(r),
                                            child: const Icon(
                                              Icons.close,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],

                                const Divider(height: 32),
                                Text(
                                  "Respostas",
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                _buildAnswerGrid(),
                              ],
                            ),
                          ),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _salvarGabarito,
                            icon: const Icon(Icons.save),
                            label: _isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text("SALVAR GABARITO"),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildAnswerGrid() {
    final qtd = int.tryParse(_qtdController.text) ?? 0;
    if (qtd <= 0) return const Text("Defina a quantidade (Selecione a Folha).");

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: qtd,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final questao = index + 1;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Text(
                  "$questao.",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: ['A', 'B', 'C', 'D', 'E'].map((letra) {
                    final isSelected = _respostas[questao] == letra;
                    return InkWell(
                      onTap: () => _toggleResposta(questao, letra),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Theme.of(context).primaryColor
                              : Colors.white,
                          border: Border.all(
                            color: isSelected
                                ? Theme.of(context).primaryColor
                                : Colors.grey.shade400,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            letra,
                            style: TextStyle(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
