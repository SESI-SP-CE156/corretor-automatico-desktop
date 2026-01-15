// lib/features/correcoes/correcoes_review_screen.dart

import 'dart:io';

import 'package:corretor_desktop/features/correcoes/data/correcao_service.dart';
import 'package:corretor_desktop/features/gabaritos/data/gabarito_model.dart';
import 'package:corretor_desktop/features/turmas/data/aluno_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class CorrecoesReviewScreen extends StatefulWidget {
  final GabaritoModelo gabarito;
  final List<File> paginas;
  final int turmaId; // <--- RECEBE TURMA ID

  const CorrecoesReviewScreen({
    super.key,
    required this.gabarito,
    required this.paginas,
    required this.turmaId,
  });

  @override
  State<CorrecoesReviewScreen> createState() => _CorrecoesReviewScreenState();
}

class _CorrecoesReviewScreenState extends State<CorrecoesReviewScreen> {
  final _service = CorrecaoService();

  List<Aluno> _alunos = [];
  Map<int, List<String>> _gabaritoOficial = {};

  // --- NOVA LISTA: Mantém IDs dos alunos já processados nesta sessão ---
  final List<int> _alunosJaCorrigidos = [];

  // Estado da Página
  int _currentIndex = 0;
  File? _imagemExibida; // Imagem processada pelo Python
  Aluno? _selectedAluno;
  Map<int, String> _respostasAluno = {};
  double _nota = 0.0;
  int _acertos = 0;

  bool _isPageLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    final alunos = await _service.getAlunosPorTurma(widget.turmaId);
    final gabarito = await _service.getGabaritoOficial(widget.gabarito.id!);

    if (mounted) {
      setState(() {
        _alunos = alunos;
        _gabaritoOficial = gabarito;
      });
      _processarPaginaAtual();
    }
  }

  Future<void> _processarPaginaAtual() async {
    setState(() {
      _isPageLoading = true;
      _selectedAluno = null;
      _respostasAluno = {};
      _nota = 0;
      _acertos = 0;
      _imagemExibida =
          widget.paginas[_currentIndex]; // Mostra original enquanto carrega
    });

    try {
      // Chama o serviço que chama o Python
      final resultado = await _service.processarPagina(
        imagem: widget.paginas[_currentIndex],
        gabaritoId: widget.gabarito.id!,
        qtdQuestoes: widget.gabarito.qtdPerguntas,
      );

      if (mounted) {
        setState(() {
          _imagemExibida =
              resultado['imagem']; // Exibe a imagem riscada pelo Python
          _respostasAluno = resultado['respostas'];
          _acertos =
              resultado['acertos']; // O Python já calculou (mas recalculamos se o prof editar)
          _nota = (resultado['nota'] as num).toDouble();
          _isPageLoading = false;
        });

        // Recalcula localmente para garantir consistência com o banco (regras de nota)
        _recalcularNotaLocal();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Erro na IA: $e. Corrija manualmente.")),
        );
        setState(() => _isPageLoading = false);
      }
    }
  }

  void _recalcularNotaLocal() async {
    int contaAcertos = 0;
    _respostasAluno.forEach((q, letra) {
      // Verifica se a letra do aluno está na lista de corretas
      if (_gabaritoOficial[q] != null && _gabaritoOficial[q]!.contains(letra)) {
        contaAcertos++;
      }
    });

    final notaCalc = await _service.calcularNota(
      widget.gabarito.id!,
      contaAcertos,
    );
    setState(() {
      _acertos = contaAcertos;
      _nota = notaCalc;
    });
  }

  void _toggleResposta(int questao, String letra) {
    setState(() {
      if (_respostasAluno[questao] == letra) {
        _respostasAluno.remove(questao);
      } else {
        _respostasAluno[questao] = letra;
      }
      _recalcularNotaLocal(); // Recalcula se o professor mudar algo
    });
  }

  Future<void> _salvarEProximo() async {
    if (_selectedAluno == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Selecione o aluno!")));
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _service.salvarCorrecao(
        alunoId: _selectedAluno!.id!,
        gabaritoId: widget.gabarito.id!,
        nota: _nota,
        respostasAluno: _respostasAluno,
        caminhoImagem: widget.paginas[_currentIndex].path, // Original Split
        caminhoImagemCorrigida:
            _imagemExibida!.path, // Corrected (Python Output)
      );

      // --- CORREÇÃO DO CRASH ---
      // Atualizamos a lista de ignorados e limpamos a seleção ATOMICAMENTE.
      // Isso impede que o Dropdown tente renderizar um valor que não existe mais na lista.
      if (mounted) {
        setState(() {
          _alunosJaCorrigidos.add(_selectedAluno!.id!);
          _selectedAluno = null; // <--- Importante: Anula a seleção
        });
      }

      if (_currentIndex < widget.paginas.length - 1) {
        _currentIndex++;
        await _processarPaginaAtual();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text("Correção Finalizada!")));
          context.go('/correcoes');
        }
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
    // --- FILTRAGEM DOS ALUNOS ---
    final alunosDisponiveis = _alunos
        .where((a) => !_alunosJaCorrigidos.contains(a.id))
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text("Corrigindo: ${widget.gabarito.nome}"),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                "Prova ${_currentIndex + 1} de ${widget.paginas.length}",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
      body: Row(
        children: [
          // ESQUERDA: IMAGEM (Processada pelo Python)
          Expanded(
            flex: 2,
            child: Container(
              color: Colors.black87,
              child: _isPageLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                  : InteractiveViewer(
                      minScale: 0.1,
                      maxScale: 5.0,
                      constrained: false,
                      child: Center(child: Image.file(_imagemExibida!)),
                    ),
            ),
          ),

          // DIREITA: CONTROLES
          Container(
            width: 400,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(left: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Column(
              children: [
                // 1. Aluno (Filtrado pela Turma)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: DropdownButtonFormField<Aluno>(
                    value: _selectedAluno,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: "Aluno",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                    items:
                        alunosDisponiveis // <--- MUDANÇA: Usa lista filtrada
                            .map(
                              (a) => DropdownMenuItem(
                                value: a,
                                child: Text(a.nome),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _selectedAluno = v),
                  ),
                ),
                const Divider(),

                // 2. Gabarito Interativo
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: widget.gabarito.qtdPerguntas,
                    separatorBuilder: (_, __) => const Divider(height: 8),
                    itemBuilder: (context, index) {
                      final q = index + 1;
                      final corretas = _gabaritoOficial[q] ?? [];
                      final marcada = _respostasAluno[q];

                      final isAcerto =
                          marcada != null && corretas.contains(marcada);
                      return Row(
                        children: [
                          SizedBox(
                            width: 30,
                            child: Text(
                              "$q.",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: isAcerto
                                    ? Colors.green
                                    : (marcada != null
                                          ? Colors.red
                                          : Colors.black),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: ['A', 'B', 'C', 'D', 'E'].map((letra) {
                                final isSelected = marcada == letra;
                                final isGabarito = corretas.contains(letra);

                                Color bg = Colors.white;
                                if (isSelected) {
                                  bg = isAcerto ? Colors.green : Colors.red;
                                } else if (isGabarito) {
                                  // Mostra visualmente quais eram as corretas (borda ou fundo suave)
                                  bg = Colors.green.shade50;
                                }

                                Color textC = isSelected
                                    ? Colors.white
                                    : Colors.black;
                                return InkWell(
                                  onTap: () => _toggleResposta(q, letra),
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: bg,
                                      border: Border.all(
                                        color: isGabarito
                                            ? Colors.green
                                            : Colors.grey.shade400,
                                        width: isGabarito ? 2 : 1,
                                      ),
                                    ),
                                    child: Center(
                                      child: Text(
                                        letra,
                                        style: TextStyle(
                                          color: textC,
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
                      );
                    },
                  ),
                ),

                // 3. Rodapé
                Container(
                  padding: const EdgeInsets.all(24),
                  color: Colors.grey.shade100,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            "Acertos: $_acertos",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            "Nota: ${_nota.toStringAsFixed(1)}",
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: _isSaving || _isPageLoading
                              ? null
                              : _salvarEProximo,
                          icon: const Icon(Icons.check),
                          label: Text(_isSaving ? "SALVANDO..." : "CONFIRMAR"),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
