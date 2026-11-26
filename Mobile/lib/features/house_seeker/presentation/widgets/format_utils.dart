// Formatting helpers shared by the house seeker UI.

String formatPrice(num? value) {
  if (value == null) return 'Price on request';
  final rounded = value.round();
  final buffer = StringBuffer();
  final digits = rounded.abs().toString();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write(',');
    }
    buffer.write(digits[i]);
  }
  final sign = rounded < 0 ? '-' : '';
  return 'KES $sign$buffer';
}

String formatPriceCompact(num? value) {
  if (value == null) return '—';
  if (value >= 1000000) {
    final m = value / 1000000;
    return 'KES ${m.toStringAsFixed(m >= 10 ? 0 : 1)}M';
  }
  if (value >= 1000) {
    final k = value / 1000;
    return 'KES ${k.toStringAsFixed(k >= 100 ? 0 : 1)}K';
  }
  return formatPrice(value);
}

String formatDateLabel(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final date = DateTime.tryParse(iso);
  if (date == null) return '';
  const months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String humanizeEnum(String? value) {
  if (value == null) return '';
  return value
      .replaceAll('_', ' ')
      .split(' ')
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');
}