# Perfume 3D — Frontend Flutter

Aplicativo Flutter desenvolvido para um TCC sobre venda de perfumes com visualização e geração de modelos 3D. O app reúne uma operação comercial demonstrável e um fluxo guiado que envia fotografias do frasco para o backend de IA.

## Funcionalidades

- Dashboard de vendas, clientes, cobranças, produtos e notificações.
- Wizard de venda com cálculo de entrada, parcelas e atualização de estoque.
- Persistência local no navegador e sincronização HTTP *best-effort* com `/sales/*`.
- Captura das quatro vistas cardeais do frasco e até duas imagens extras.
- Upload para `POST /captures`, acompanhamento do processamento e visualização do GLB retornado.
- Visualização de modelos 3D do catálogo com `model_viewer_plus`.

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

O módulo comercial continua utilizável com dados locais/de demonstração se o backend estiver indisponível. A geração 3D exige o backend `perfume-3d-backend` em execução.

## Qualidade

```powershell
flutter analyze
flutter test
```

Estado verificado em 2026-07-22: análise estática sem problemas e 3 testes aprovados.

## Documentação

A documentação técnica completa está em [docs/README.md](docs/README.md). O contrato HTTP utilizado pelo app está em [docs/16-contrato-backend.md](docs/16-contrato-backend.md).
