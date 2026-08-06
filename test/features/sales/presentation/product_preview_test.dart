// O card do produto passou a mostrar o render do modelo 3D.
//
// A coluna `caminho_imagem_preview` existia no backend desde o schema original
// e nunca era preenchida, então `previewImg` chegava sempre nulo e o card caía
// num gradiente genérico da cor do frasco. Agora o pipeline gera o PNG; estes
// testes prendem as duas pontas do comportamento no app.
//
// `Image.network` não busca nada em ambiente de teste (o HttpClient fake do
// Flutter responde 400), então o que se valida é a árvore de widgets: existe
// ou não existe a camada de imagem.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:perfume_3d_mvp/features/sales/domain/sales_models.dart';
import 'package:perfume_3d_mvp/features/sales/presentation/widgets/product_visuals.dart';

Produto _produto({String? previewImg}) => Produto(
      id: '1',
      nome: 'Camille',
      categoria: 'Feminino',
      precoBase: 380,
      custo: 180,
      estoque: 4,
      estoqueMinimo: 3,
      volumeMl: 100,
      tem3D: true,
      previewImg: previewImg,
    );

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
}

void main() {
  group('ProductBottlePreview', () {
    testWidgets('sem preview usa só o gradiente da cor do frasco',
        (tester) async {
      await _pump(tester, ProductBottlePreview(produto: _produto()));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('com preview desenha a imagem do modelo', (tester) async {
      await _pump(
        tester,
        ProductBottlePreview(
          produto: _produto(previewImg: '/files/models/abc.png'),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('preview substitui a label desenhada', (tester) async {
      // Com o render real não faz sentido sobrepor "EAU DE CAMILLE 100 ml"
      // escrito por cima — o texto de verdade já está na textura.
      await _pump(
        tester,
        ProductBottlePreview(
          produto: _produto(previewImg: '/files/models/abc.png'),
          showLabel: true,
        ),
      );
      expect(find.textContaining('EAU DE'), findsNothing);
    });

    testWidgets('sem preview a label desenhada continua aparecendo',
        (tester) async {
      await _pump(
        tester,
        ProductBottlePreview(produto: _produto(), showLabel: true),
      );
      expect(find.textContaining('EAU DE'), findsOneWidget);
    });
  });

  group('ProductStagePreview', () {
    testWidgets('sem preview mantém a ilustração vetorial', (tester) async {
      await _pump(tester, ProductStagePreview(produto: _produto()));
      expect(find.byType(Image), findsNothing);
    });

    testWidgets('com preview mostra o render em vez da ilustração',
        (tester) async {
      await _pump(
        tester,
        ProductStagePreview(
          produto: _produto(previewImg: '/files/models/abc.png'),
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });
  });
}
