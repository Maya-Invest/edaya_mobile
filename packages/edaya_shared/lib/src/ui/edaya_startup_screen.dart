import 'package:flutter/material.dart';

import 'edaya_brand_logo.dart';

/// Branded gate shown while auth/session bootstrap is still running.
///
/// Matches the native splash: white canvas and the EDAYA symbol.
class EdayaStartupScreen extends StatelessWidget {
  const EdayaStartupScreen({super.key});

  static const _splashBackground = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: _splashBackground,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              EdayaBrandLogo(
                variant: EdayaLogoVariant.symbol,
                width: 96,
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
