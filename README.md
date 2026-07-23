# Perfume 3D — Frontend Flutter

Aplicativo Flutter desenvolvido para um TCC sobre venda de perfumes com visualização e geração de modelos 3D. O app reúne uma operação comercial demonstrável e um fluxo guiado que envia fotografias do frasco para o backend de IA.

## Funcionalidades

- Dashboard de vendas, clientes, cobranças, produtos e notificações.
- Wizard de venda com cálculo de entrada, parcelas e atualização de estoque.
- Escritas comerciais confirmadas pelo backend, com bloqueio de toque duplo e erros recuperáveis.
- Cadastro/edição de cliente e produto, pagamentos parciais/totais, renegociação e notificações.
- Captura das quatro vistas cardeais do frasco e até duas imagens extras.
- Upload para `POST /captures`, acompanhamento do processamento e visualização do GLB retornado.
- Visualização de modelos 3D do catálogo com `model_viewer_plus`.
- Captura vinculada ao produto e reabertura do GLB salvo no estoque.

## Stack

- Flutter e Dart
- Riverpod para estado
- GoRouter para navegação
- Dio para integração HTTP
- Camera, sensores e OpenCV/ORB para auxiliar a captura
- `model_viewer_plus` para exibição dos modelos 3D

## Executar

```powershell
cd C:\TCC\perfume-3d-frontend
flutter pub get
flutter run --dart-define=BACKEND_BASE_URL=http://localhost:8000
```

Em um aparelho físico, substitua `localhost` pelo IP do computador na mesma rede. No Android Emulator, normalmente use `http://10.0.2.2:8000`.

Os dados fictícios foram removidos. O módulo comercial mantém um snapshot e uma fila durável em `shared_preferences`: sem conexão, clientes, produtos, vendas, estoque, pagamentos e demais alterações ficam com status pendente e são enviados automaticamente a cada 10 segundos quando o backend volta. A geração 3D continua exigindo o backend em execução.

## Qualidade

```powershell
flutter analyze
flutter test
```

Estado verificado em 2026-07-23: análise estática sem problemas e **27 testes aprovados**.

## Documentação

A documentação técnica completa está em [docs/README.md](docs/README.md). O contrato HTTP utilizado pelo app está em [docs/16-contrato-backend.md](docs/16-contrato-backend.md).
