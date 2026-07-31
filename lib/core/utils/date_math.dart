/// Utilitarios de data usados pelo parcelamento.
///
/// O construtor `DateTime(ano, mes + n, dia)` normaliza estouros de dia
/// (31/01 + 1 mes viraria 03/03), o que quebra o intervalo mensal das parcelas.
/// As funcoes aqui mantem o dia do vencimento e so recuam quando o mes de
/// destino e mais curto (fevereiro com 28/29 dias, meses com 30).
library;

/// Soma [months] meses a [base] preservando o dia sempre que ele existir no
/// mes de destino. Quando nao existir, usa o ultimo dia daquele mes.
///
/// 31/01/2026 + 1 mes -> 28/02/2026; 31/08/2026 + 1 mes -> 30/09/2026.
DateTime addMonthsClamped(DateTime base, int months) {
  final absoluteMonth = base.year * 12 + (base.month - 1) + months;
  final year = absoluteMonth ~/ 12;
  final month = absoluteMonth % 12 + 1;
  // Dia 0 do mes seguinte e o ultimo dia do mes corrente.
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, base.day < lastDay ? base.day : lastDay);
}

/// Compara apenas ano/mes/dia, ignorando hora.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Remove a parte de hora, mantendo a data local.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);
