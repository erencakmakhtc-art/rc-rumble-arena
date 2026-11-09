import 'package:flutter/material.dart';

/// Orijinal tasarimdaki "alt kenari kalin golgeli" 3B buton stilini taklit eder.
/// Basildiginda hafifce asagi cokerek geri bildirim verir.
class CandyButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;
  final Gradient gradient;
  final Color depthColor;
  final Color borderColor;
  final double depth;

  const CandyButton({
    super.key,
    required this.child,
    required this.onTap,
    required this.gradient,
    required this.depthColor,
    this.height = 56,
    this.borderRadius = 18,
    this.borderColor = Colors.white,
    this.depth = 6,
  });

  @override
  State<CandyButton> createState() => _CandyButtonState();
}

class _CandyButtonState extends State<CandyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      onTapCancel: () {
        if (_pressed) setState(() => _pressed = false);
      },
      child: SizedBox(
        height: widget.height + widget.depth,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: widget.depth,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: widget.depthColor,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                ),
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 70),
              curve: Curves.easeOut,
              left: 0,
              right: 0,
              top: _pressed ? widget.depth - 2 : 0,
              height: widget.height,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: widget.gradient,
                  borderRadius: BorderRadius.circular(widget.borderRadius),
                  border: Border.all(color: widget.borderColor, width: 2),
                ),
                child: Center(child: widget.child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
