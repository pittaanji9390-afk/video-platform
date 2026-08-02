import 'package:flutter/material.dart';

class PoweredByFooter extends StatelessWidget {
  final Color? textColor;
  final Color? brandColor;

  const PoweredByFooter({
    super.key,
    this.textColor,
    this.brandColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      child: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: TextStyle(
              fontSize: 12,
              color: textColor ?? Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
            children: [
              const TextSpan(text: 'Powered by '),
              TextSpan(
                text: 'ElevateIQ Softtech',
                style: TextStyle(
                  color: brandColor ?? const Color(0xFF1D4ED8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
