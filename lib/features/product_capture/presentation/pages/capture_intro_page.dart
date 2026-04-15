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
            title: 'Vários ângulos',
            description:
                'Dê a volta no perfume capturando pequenos incrementos de rotação.',
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
                'Use um fundo neutro e sem objetos que possam confundir o algoritmo.',
          ),
          SizedBox(height: 12),
          InstructionCard(
            icon: Icons.photo_library_outlined,
            title: 'Quantidade mínima',
            description:
                'Capture ao menos ${AppConstants.minImages} imagens. O ideal é ${AppConstants.recommendedImages}.',
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
