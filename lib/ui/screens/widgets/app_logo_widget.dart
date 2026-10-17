import 'package:flutter/material.dart';
import 'package:Ebozor/ui/theme/theme.dart';
import 'package:Ebozor/utils/extensions/extensions.dart';

/// Clean, scalable brand logo widget for eBozor
/// Matches the reference design mockup with the royal blue canopy icon and "eBozor" wordmark.
class AppLogoWidget extends StatelessWidget {
  final double height;
  final bool isWhite;
  final bool showText;

  const AppLogoWidget({
    super.key,
    this.height = 32,
    this.isWhite = false,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    if (showText) {
      return Image.asset(
        isWhite
            ? "assets/svg/Logo/ebozor_logo_master.png"
            : "assets/svg/Logo/ebozor_logo.png",
        height: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildFallbackLogo(context),
      );
    } else {
      return Image.asset(
        "assets/svg/Logo/splashlogo.png",
        height: height,
        width: height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildStoreCanopyIcon(height),
      );
    }
  }

  Widget _buildFallbackLogo(BuildContext context) {
    final double iconSize = height;
    final double fontSize = height * 0.72;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Brand canopy icon
        _buildStoreCanopyIcon(iconSize),
        SizedBox(width: height * 0.22),
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: "e",
                style: TextStyle(
                  fontFamily: "Manrope",
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF168BFF),
                  letterSpacing: -0.5,
                ),
              ),
              TextSpan(
                text: "Bozor",
                style: TextStyle(
                  fontFamily: "Manrope",
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  color: isWhite
                      ? Colors.white
                      : (context.color.textColorDark),
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStoreCanopyIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF168BFF),
        borderRadius: BorderRadius.circular(size * 0.30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF168BFF).withValues(alpha: 0.28),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Canopy scalloped top accent
          Positioned(
            top: size * 0.12,
            left: size * 0.12,
            right: size * 0.12,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(
                3,
                (_) => Container(
                  width: size * 0.20,
                  height: size * 0.12,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(size * 0.06),
                  ),
                ),
              ),
            ),
          ),
          // Center "e" emblem
          Positioned(
            bottom: size * 0.12,
            child: Text(
              "e",
              style: TextStyle(
                fontFamily: "Manrope",
                fontSize: size * 0.58,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                height: 1.0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
