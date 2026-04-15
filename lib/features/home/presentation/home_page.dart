import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/app_routes.dart';
import '../../../shared/widgets/instruction_card.dart';
import '../../../shared/widgets/primary_button.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Perfume 3D',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Capture seu perfume e visualize-o em 3D.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              const InstructionCard(
                icon: Icons.photo_camera_outlined,
                title: 'Captura guiada',
                description:
                    'O app orienta você a capturar ângulos suficientes para uma boa reconstrução.',
              ),
              const SizedBox(height: 12),
              const InstructionCard(
                icon: Icons.cloud_upload_outlined,
                title: 'Processamento externo',
                description:
                    'As imagens são enviadas ao servidor local, que gera o modelo 3D.',
              ),
              const SizedBox(height: 12),
              const InstructionCard(
                icon: Icons.view_in_ar_outlined,
                title: 'Visualização 3D',
                description:
                    'Explore o modelo final com rotação e zoom direto no app.',
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Iniciar captura',
                icon: Icons.play_arrow_rounded,
                onPressed: () => context.goNamed(AppRoutes.captureIntroName),
              ),
              const SizedBox(height: 8),
              // Espaço previsto para histórico futuro
              TextButton(
                onPressed: null,
                child: Text(
                  'Histórico (em breve)',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
