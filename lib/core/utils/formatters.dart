// Formatage des dates, nombres et durées en français.

const _months = [
  'janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin',
  'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.',
];
const _monthsShort = [
  'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Jun',
  'Jul', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc',
];

String _two(int n) => n.toString().padLeft(2, '0');

/// 12 janv. 2024
String formatDate(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// 01/03/2024
String formatDateNumeric(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Avr, Mai… (axe du graphique)
String monthLabel(DateTime d) => _monthsShort[d.month - 1];

/// 12 480 — espace fine insécable entre les milliers.
String formatNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final digits = parts[0].replaceFirst('-', '');
  final buffer = StringBuffer(value < 0 ? '-' : '');
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(' ');
    buffer.write(digits[i]);
  }
  if (parts.length > 1) buffer.write(',${parts[1]}');
  return buffer.toString();
}

/// 0.025 → « 2,5 » (pourcentage sans zéros inutiles)
String formatRate(double rate) {
  final pct = (rate * 100 * 100).round() / 100;
  final text = pct == pct.roundToDouble() ? pct.toInt().toString() : pct.toString();
  return text.replaceAll('.', ',');
}

/// Dernière connexion : « jamais connecté », « il y a 2 h », « il y a 3 j »…
String lastLoginLabel(int? millis) {
  if (millis == null) return 'jamais connecté';
  final diff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(millis));
  if (diff.inMinutes < 60) return 'connecté à l’instant';
  if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
  return 'il y a ${diff.inDays} j';
}

/// Initiales d'un nom : « Carthage Immobilier » → « CI ».
String initialsOf(String name) {
  final words = name.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty) return '?';
  if (words.length == 1) return words.first.substring(0, 1).toUpperCase();
  return (words[0][0] + words[1][0]).toUpperCase();
}
