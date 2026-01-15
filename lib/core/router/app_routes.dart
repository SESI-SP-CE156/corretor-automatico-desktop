class AppRoutes {
  const AppRoutes._();

  // Root
  static const String home = '/';

  // Rota de Setup
  static const String setup = '/setup';

  // Turmas
  static const String turmas = '/turmas';
  static const String turmasDetails = ':id'; // Caminho relativo

  // Alunos
  static const String alunos = '/alunos';
  static const String alunosCreate = 'create';
  static const String alunosDetails = ':id';

  // Folhas Modelo
  static const String folhas = '/folhas';
  static const String folhasCreate = 'create';

  // Gabaritos
  static const String gabaritos = '/gabaritos';
  static const String gabaritosCreate = 'create';

  // Correções
  static const String correcoes = '/correcoes';
  static const String correcoesScanner = 'scanner';
  static const String correcoesReview = 'review';

  // Matérias (Sugestão baseada no diagrama)
  static const String materias = '/materias';
}
