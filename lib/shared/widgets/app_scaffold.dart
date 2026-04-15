import 'package:flutter/material.dart';

class AppScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final List<Widget>? actions;
  final bool showBack;

  const AppScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottomBar,
    this.actions,
    this.showBack = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        automaticallyImplyLeading: showBack,
        actions: actions,
      ),
      body: SafeArea(child: body),
      bottomNavigationBar: bottomBar == null
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: bottomBar,
              ),
            ),
    );
  }
}
