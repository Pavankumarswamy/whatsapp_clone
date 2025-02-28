import 'package:flutter/material.dart';

class AnimatedIconWidget extends StatelessWidget {
  final IconData icon;
  final bool isSelected;

  const AnimatedIconWidget({super.key, required this.icon, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 1.0, end: isSelected ? 1.4 : 1.0),
      duration: const Duration(milliseconds: 200),
      builder: (context, scale, child) {
        return Transform.scale(
          scale: scale,
          child: child,
        );
      },
      child: Icon(icon),
    );
  }
}
