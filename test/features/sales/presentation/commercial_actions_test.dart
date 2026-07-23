import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/presentation/widgets/commercial_actions.dart';

void main() {
  test('monta URI do discador somente com o telefone', () {
    final uri = phoneDialUri('(85) 99999-8888');

    expect(uri.scheme, 'tel');
    expect(uri.path, '85999998888');
  });

  test('monta URI do WhatsApp com DDI brasileiro e mensagem', () {
    final uri = whatsappUri('(85) 99999-8888', 'Olá!');

    expect(uri.host, 'wa.me');
    expect(uri.path, '/5585999998888');
    expect(uri.queryParameters['text'], 'Olá!');
  });
}
