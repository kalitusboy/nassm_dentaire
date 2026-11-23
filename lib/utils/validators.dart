String? validateUsername(String? v) {
  final s = (v ?? '').trim();
  if (s.length < 3) return '3 caractères minimum';
  if (!RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]*$').hasMatch(s)) {
    return 'Lettres, chiffres, . _ - uniquement (sans espace ni accent)';
  }
  return null;
}
