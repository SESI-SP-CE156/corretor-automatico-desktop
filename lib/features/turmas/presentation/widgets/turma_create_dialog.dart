import 'package:corretor_desktop/features/turmas/data/ano_model.dart';
import 'package:corretor_desktop/features/turmas/data/turma_model.dart';
import 'package:corretor_desktop/features/turmas/data/turmas_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class TurmaCreateDialog extends StatefulWidget {
  const TurmaCreateDialog({super.key});

  @override
  State<TurmaCreateDialog> createState() => _TurmaCreateDialogState();
}

class _TurmaCreateDialogState extends State<TurmaCreateDialog> {
  final _formKey = GlobalKey<FormState>();
  final _repository = TurmasRepository();

  String? _selectedLetra;
  int? _selectedAnoId;
  List<Ano> _anos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnos();
  }

  Future<void> _fetchAnos() async {
    try {
      final anos = await _repository.getAnos();
      if (mounted) {
        setState(() {
          _anos = anos;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      try {
        final novaTurma = Turma(letra: _selectedLetra!, anoId: _selectedAnoId!);
        await _repository.createTurma(novaTurma);

        if (mounted) {
          context.pop(true);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Turma criada com sucesso!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Erro ao criar turma: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nova Turma'),
      content: SizedBox(
        width: 400,
        child: _isLoading
            ? const SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              )
            : Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Dropdown de Anos
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Ano / Categoria',
                        border: OutlineInputBorder(),
                      ),
                      items: _anos.map((ano) {
                        return DropdownMenuItem(
                          value: ano.id,
                          child: Text(ano.nomeExibicao),
                        );
                      }).toList(),
                      onChanged: (value) => _selectedAnoId = value,
                      validator: (value) =>
                          value == null ? 'Selecione um ano' : null,
                    ),
                    const SizedBox(height: 16),
                    // Campo de Texto para Letra
                    TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Letra (Ex: A, B, C)',
                        border: OutlineInputBorder(),
                      ),
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 1,
                      onSaved: (value) => _selectedLetra = value,
                      validator: (value) => (value == null || value.isEmpty)
                          ? 'Digite a letra'
                          : null,
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => context.pop(false),
          child: const Text('CANCELAR', style: TextStyle(color: Colors.red)),
        ),
        ElevatedButton(onPressed: _submitForm, child: const Text('CRIAR')),
      ],
    );
  }
}
