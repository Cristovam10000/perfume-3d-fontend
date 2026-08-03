import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router/app_routes.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../shared/widgets/app_scaffold.dart';
import '../../../../shared/widgets/instruction_card.dart';
import '../../../../shared/widgets/primary_button.dart';

class CaptureIntroPage extends StatelessWidget {
  const CaptureIntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AppScaffold(
      title: 'Antes de começar',
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: const [
          InstructionCard(
            icon: Icons.wb_sunny_outlined,
            title: 'Boa iluminação',
            description:
                'Prefira luz natural difusa. Evite sombras fortes e reflexos no vidro.',
          ),
          SizedBox(height: 12),
          InstructionCard(
            icon: Icons.threed_rotation,
            title: '4 vistas cardeais',
            description:
                'Capture frente, esquerda, trás e direita. Mantenha a mesma altura e distância nas 4 fotos.',
          ),
          SizedBox(height: 12),
          InstructionCard(
            icon: Icons.vertical_align_top,
            title: 'Topo opcional',
            description:
                'Fotografe a tampa de cima, com a câmera perpendicular. Mantenha a frente do frasco virada para a base do enquadramento e use luz difusa.',
          ),
          SizedBox(height: 12),
          InstructionCard(
            icon: Icons.filter_center_focus,
            title: 'Centralize o objeto',
            description:
                'Mantenha o perfume dentro do guia de enquadramento, sem cortes.',
          ),
          SizedBox(height: 12),
          InstructionCard(
            icon: Icons.auto_awesome_outlined,
            title: 'Fundo limpo',
            description:
                'Use um fundo neutro (folha A4 branca é ótimo) e sem decorações no frasco.',
          ),
          SizedBox(height: 12),
          InstructionCard(
            icon: Icons.photo_library_outlined,
            title: 'Quantidade',
            description:
                '${AppConstants.requiredImages} vistas obrigatórias + topo opcional + até '
                '${AppConstants.maxExtras} fotos extras opcionais.',
          ),
        ],
      ),
      bottomBar: PrimaryButton(
        label: 'Começar captura',
        icon: Icons.photo_camera_outlined,
        onPressed: () => context.goNamed(AppRoutes.captureCameraName),
      ),
    );
  }
}
