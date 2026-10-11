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

/// 09:00
String formatTime(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${_two(d.hour)}:${_two(d.minute)}';
}

/// 01/03/2024
String formatDateNumeric(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

/// Avr, Mai… (axe du graphique)
String monthLabel(DateTime d) => _monthsShort[d.month - 1];

const _monthsFull = [
  'Janvier', 'Février', 'Mars', 'Avril', 'Mai', 'Juin',
  'Juillet', 'Août', 'Septembre', 'Octobre', 'Novembre', 'Décembre',
];
const _weekdaysShort = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
const _weekdaysLong = [
  'lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche',
];

/// Septembre 2026 (titre du calendrier)
String monthTitle(DateTime d) => '${_monthsFull[d.month - 1]} ${d.year}';

/// « Mar », « Sam »… (DateTime.weekday : 1 = lundi)
String weekdayShort(DateTime d) => _weekdaysShort[d.weekday - 1];

/// « mardi », « samedi »…
String weekdayLong(DateTime d) => _weekdaysLong[d.weekday - 1];

/// « Lun 29 » — puces de jour du formulaire de visite.
String formatDayChip(DateTime d) => '${_weekdaysShort[d.weekday - 1]} ${d.day}';

/// « Mar 30 sept. · 10:00 » — cartes et en-têtes de visite.
String formatDateTimeShort(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${weekdayShort(d)} ${d.day} ${_months[d.month - 1]} '
      '· ${_two(d.hour)}:${_two(d.minute)}';
}

/// « mardi 30 sept. » — texte du dialogue de confirmation.
String formatDateLong(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${weekdayLong(d)} ${d.day} ${_months[d.month - 1]}';
}

/// « 27 sept. » — sans l'année (chronologies, listes courtes).
String formatDayMonth(int millis) {
  final d = DateTime.fromMillisecondsSinceEpoch(millis);
  return '${d.day} ${_months[d.month - 1]}';
}

/// « Mardi 30 septembre » — en-tête du jour du calendrier (M6).
String dayTitle(DateTime d) {
  final weekday = weekdayLong(d);
  return '${weekday[0].toUpperCase()}${weekday.substring(1)} '
      '${d.day} ${_monthsFull[d.month - 1].toLowerCase()}';
}

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

/// « 2,4 M », « 31,2K », « 9,6K » — montants compacts des cartes
/// « Finances » (maquette M4).
String compactMoney(num value) {
  if (value >= 1000000) return '${formatNumber(value / 1000000, decimals: 1)} M';
  if (value >= 1000) {
    final k = (value / 1000 * 10).round() / 10;
    final text = k == k.roundToDouble() ? k.toInt().toString() : k.toStringAsFixed(1);
    return '${text.replaceAll('.', ',')}K';
  }
  return formatNumber(value);
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
