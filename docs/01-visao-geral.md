# 01 — Visão geral

## O que é o Perfume 3D MVP

O **Perfume 3D MVP** é um aplicativo móvel escrito em Flutter cujo objetivo é transformar um objeto físico (especificamente um frasco de perfume) em um **modelo 3D interativo** que pode ser rotacionado e inspecionado na tela. O aplicativo não faz a reconstrução 3D por conta própria — ele **orienta a captura de fotos** com qualidade suficiente, **envia o lote de imagens** para um serviço backend que executa o trabalho pesado (*photogrammetry* / *3D reconstruction*), e então **baixa e exibe o resultado** dentro do próprio app.

É um projeto acadêmico desenvolvido como Trabalho de Conclusão de Curso (TCC), logo o escopo é intencionalmente enxuto: prioriza a jornada completa fim-a-fim funcionando, em detrimento de polimento de produção.

## Problema que resolve

Gerar um modelo 3D fotorrealista de um objeto pequeno exige tipicamente **várias fotos tiradas de diferentes ângulos**, com iluminação consistente, pouco reflexo, foco nítido e fundo limpo. Um usuário comum não tem essa intuição — tira cinco fotos de frente com pouca variação e fica frustrado quando a reconstrução falha.

O app resolve esse gap com um **assistente de captura em tempo real**: conforme a câmera está aberta, o app mede brilho, nitidez e saturação do frame, monitora a inclinação do celular via acelerômetro, e compara visualmente cada frame contra as fotos já tiradas (usando *feature matching* ORB do OpenCV) para avisar se aquele ângulo já foi capturado ou se é realmente um ângulo novo. O resultado é um conjunto de imagens diverso o bastante para o backend extrair um modelo 3D de qualidade.

## Jornada do usuário

A navegação completa é linear, composta por 6 telas:

1. **Home** ([lib/features/home/](../lib/features/home/)): tela de abertura com branding, três cards de "como funciona" e um botão grande de "Iniciar captura".
2. **Intro de captura** ([lib/features/product_capture/presentation/pages/capture_intro_page.dart](../lib/features/product_capture/presentation/pages/capture_intro_page.dart)): cinco cards explicando requisitos (iluminação, ângulos, enquadramento, fundo limpo, quantidade mínima). Existe para alinhar expectativas antes de abrir a câmera.
3. **Câmera** ([lib/features/product_capture/presentation/pages/capture_camera_page.dart](../lib/features/product_capture/presentation/pages/capture_camera_page.dart)): o coração do app. Abre a câmera traseira com um guia de enquadramento, exibe o *live feedback* (banners coloridos de qualidade) em tempo real e permite tirar foto a foto ou escolher da galeria.
4. **Revisão** ([lib/features/product_capture/presentation/pages/capture_review_page.dart](../lib/features/product_capture/presentation/pages/capture_review_page.dart)): grid 3×N das imagens capturadas, com botão de remover cada uma. Aqui o usuário pressiona "Enviar para processamento" — o app faz o upload multipart e recebe um `jobId`.
5. **Processamento** ([lib/features/processing/presentation/pages/processing_status_page.dart](../lib/features/processing/presentation/pages/processing_status_page.dart)): tela com ícone, status textual, barra de progresso e mensagem. A cada 3 segundos o app consulta o backend e atualiza o status até chegar em `completed` ou `error`.
6. **Visualizador 3D** ([lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart)): carrega o `.glb`/`.gltf` retornado via `ModelViewer` do pacote `model_viewer_plus`, com auto-rotate, controles de câmera e zoom habilitados. Botão "Concluir" volta para a home.

Um guard de rota em [app_router.dart](../lib/app/router/app_router.dart) impede pular passos (por exemplo, abrir `/capture/review` sem imagens capturadas redireciona para `/capture/camera`; abrir `/viewer` sem um modelo pronto redireciona para `/processing`).

## Público-alvo

- **Usuário final**: um cliente leigo em um contexto de e-commerce de perfumaria que queira gerar uma visualização 3D do seu próprio frasco. No MVP, o app está em português pt-BR e supõe um aparelho Android razoavelmente recente (testado em **Samsung Galaxy A15 / SM-A155M**).
- **Banca e orientador do TCC**: pessoas que avaliarão o projeto — por isso a documentação é exaustiva.
- **Desenvolvedor(a) continuando o projeto**: alguém que pegue o código depois do TCC para evoluir. Toda a doc é escrita pensando em facilitar esse onboarding.

## Escopo do MVP — o que **está** dentro

- Captura guiada com *live feedback* de qualidade e diversidade de ângulos.
- Upload multipart para backend local.
- *Polling* de status com *auto-stop* em terminal.
- Visualização 3D interativa do modelo retornado.
- Tema Material 3 com modo claro e escuro.
- Todas as 6 plataformas Flutter configuradas (Android, iOS, Web, Windows, Linux, macOS), embora o alvo real seja **Android físico**.

## Escopo do MVP — o que está **fora**

Itens conscientemente deixados para depois:

- **Histórico de capturas**: o botão "Histórico (em breve)" em [home_page.dart:61-67](../lib/features/home/presentation/home_page.dart) está desabilitado.
- **Autenticação / contas de usuário**: não há login. O backend presume cliente anônimo.
- **AR (realidade aumentada)**: o `ModelViewer` é inicializado com `ar: false` — ver [product_3d_viewer_page.dart:44](../lib/features/product_viewer/presentation/pages/product_3d_viewer_page.dart).
- **Cache offline de modelos**: o `.glb` é carregado por streaming do backend a cada abertura; nada fica salvo no aparelho.
- **Compartilhamento / export**: não há botão de enviar o modelo para outro app.
- **Internacionalização**: strings estão fixas em pt-BR dentro do código.
- **Análise pixel-a-pixel do modelo retornado**: se o backend entregar um `.glb` corrompido, o app apenas mostra erro do WebView.
- **Métricas / telemetria**: nada de Firebase, Sentry, Mixpanel etc.

## Por que Flutter

Escolha pragmática para um TCC:

- **Uma base, múltiplas plataformas**: permite demonstrar rodando em Android e, se necessário, em Windows/Web para a banca, sem reescrever nada.
- **Material Design 3 pronto**: evita gastar tempo em estilo visual.
- **Ecossistema rico de packages**: `camera`, `sensors_plus`, `opencv_dart`, `model_viewer_plus` resolvem todo o lado "tecnologicamente arriscado" sem reinventar nada.
- **Riverpod**: injeção de dependências e *state management* em um pacote só, com DX excelente para código testável.

## Para onde ir agora

- Entender o porquê da **arquitetura** em camadas: [05 — Arquitetura](05-arquitetura.md).
- Ver o **mapa completo de arquivos**: [04 — Estrutura de pastas](04-estrutura-de-pastas.md).
- Ler sobre o **coração do app** (a captura guiada com ORB): [09 — Feature de captura](09-feature-product-capture.md).
