import 'package:flutter/material.dart';

class ProfilePageLayout extends StatelessWidget {
  const ProfilePageLayout({
    super.key,
    required this.introduction,
    required this.child,
  });

  final Widget introduction;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide =
              constraints.maxWidth >= 900 &&
              MediaQuery.textScalerOf(context).scale(16) <= 24;

          final horizontalPadding = constraints.maxWidth < 600 ? 16.0 : 32.0;

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              20,
              horizontalPadding,
              24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: wide
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(flex: 2, child: introduction),
                          const SizedBox(width: 40),
                          Expanded(flex: 3, child: child),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          introduction,
                          const SizedBox(height: 24),
                          child,
                        ],
                      ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ProfileIntroduction extends StatelessWidget {
  const ProfileIntroduction({
    super.key,
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colors.outline),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/images/lurk_logo.png',
                width: 112,
                height: 112,
                semanticLabel: 'Lurk logo',
              ),
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
