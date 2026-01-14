class Materia {
  final String id; // Ex: 'MAT', 'POR'
  final String nome;

  Materia({required this.id, required this.nome});

  factory Materia.fromMap(Map<String, dynamic> map) {
    return Materia(id: map['MAT_ID'], nome: map['MAT_NOME']);
  }
}
