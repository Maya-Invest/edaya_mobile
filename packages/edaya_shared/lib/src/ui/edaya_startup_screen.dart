import 'package:flutter/material.dart';

import '../app/edaya_colors.dart';
import 'edaya_brand_logo.dart';

/// Branded gate shown while auth/session bootstrap is still running.
class EdayaStartupScreen extends StatelessWidget {
  const EdayaStartupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: EdayaColors.background,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EdayaBrandLogo(
                variant: EdayaLogoVariant.vertical,
                width: 160,
                decorative: true,
              ),
              SizedBox(height: 32),
              CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
