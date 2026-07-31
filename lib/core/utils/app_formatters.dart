import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final NumberFormat money = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  static final DateFormat shortDate = DateFormat('dd MMM yyyy', 'pt_BR');
  static final DateFormat dayMonth = DateFormat('dd MMM', 'pt_BR');
  static final DateFormat weekday = DateFormat('EEEE', 'pt_BR');
  static final DateFormat fullDate = DateFormat('dd/MM/yyyy', 'pt_BR');

  static String brl(num value) => money.format(value);

  static String compactDate(DateTime value) => dayMonth.format(value);

  static String date(DateTime value) => shortDate.format(value);

  static String numericDate(DateTime value) => fullDate.format(value);
}
