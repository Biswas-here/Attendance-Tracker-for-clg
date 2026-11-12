import 'package:flutter/material.dart';
import '../../core/theme/paper_decorations.dart';

class PaperCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;
  final bool showTape;
  final Color? tapeColor;

  const PaperCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16.0),
    this.margin,
    this.color,
    this.borderColor,
    this.borderRadius = 16.0,
    this.onTap,
    this.showTape = false,
    this.tapeColor,
  });

  @override
  Widget build(BuildContext context) {
    Widget cardContent = Container(
      padding: padding,
      decoration: PaperDecorations.paperCardDecoration(
        context: context,
        color: color,
        borderColor: borderColor,
        borderRadius: borderRadius,
      ),
      child: child,
    );

    if (onTap != null) {
      cardContent = InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(borderRadius),
        child: cardContent,
      );
    }

    if (showTape) {
      return Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Padding(
            padding: margin ?? EdgeInsets.zero,
            child: cardContent,
          ),
          Positioned(
            top: (margin != null ? (margin as EdgeInsets).top : 0) - 7,
            child: WashiTape(
              color: tapeColor ?? const Color(0xFFD49A3D),
              width: 60,
              height: 14,
            ),
          ),
        ],
      );
    }

    return Padding(
      padding: margin ?? EdgeInsets.zero,
      child: cardContent,
    );
  }
}

