class RegraNota {
  final int? id;
  final int inicio; // Acertos de...
  final int fim; // Acertos até...
  final double nota; // Nota atribuída

  RegraNota({
    this.id,
    required this.inicio,
    required this.fim,
    required this.nota,
  });

  Map<String, dynamic> toMap() {
    return {
      'RNO_ID': id,
      'RNO_INICIO': inicio,
      'RNO_FIM': fim,
      'RNO_NOTA': nota,
    };
  }

  factory RegraNota.fromMap(Map<String, dynamic> map) {
    return RegraNota(
      id: map['RNO_ID'],
      inicio: map['RNO_INICIO'],
      fim: map['RNO_FIM'],
      nota: map['RNO_NOTA'],
    );
  }
}
