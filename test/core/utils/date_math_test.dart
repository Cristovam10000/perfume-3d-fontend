import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/core/utils/date_math.dart';

void main() {
  test('mantem o dia do vencimento quando o mes seguinte comporta', () {
    expect(addMonthsClamped(DateTime(2026, 8, 15), 1), DateTime(2026, 9, 15));
    expect(addMonthsClamped(DateTime(2026, 8, 15), 2), DateTime(2026, 10, 15));
  });

  test('recua para o ultimo dia em meses mais curtos', () {
    // 30 dias
    expect(addMonthsClamped(DateTime(2026, 8, 31), 1), DateTime(2026, 9, 30));
    // fevereiro comum (28 dias)
    expect(addMonthsClamped(DateTime(2026, 1, 31), 1), DateTime(2026, 2, 28));
    // fevereiro bissexto (29 dias)
    expect(addMonthsClamped(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
    // 31 dias volta a caber
    expect(addMonthsClamped(DateTime(2026, 1, 31), 2), DateTime(2026, 3, 31));
  });

  test('vira o ano corretamente', () {
    expect(addMonthsClamped(DateTime(2026, 11, 30), 2), DateTime(2027, 1, 30));
    expect(addMonthsClamped(DateTime(2026, 12, 31), 1), DateTime(2027, 1, 31));
    expect(addMonthsClamped(DateTime(2026, 3, 31), 12), DateTime(2027, 3, 31));
  });

  test('isSameDay ignora a hora e dateOnly zera o horario', () {
    expect(
      isSameDay(DateTime(2026, 8, 31, 23, 59), DateTime(2026, 8, 31)),
      isTrue,
    );
    expect(isSameDay(DateTime(2026, 8, 31), DateTime(2026, 9, 1)), isFalse);
    expect(dateOnly(DateTime(2026, 8, 31, 10, 20)), DateTime(2026, 8, 31));
  });
}
