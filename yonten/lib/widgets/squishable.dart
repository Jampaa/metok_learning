import 'package:flutter/material.dart';

import '../theme/motion.dart';

/// Press feedback for illustration buttons (Yonten, the chest, nav items):
/// they squish to 0.94 scale instead of using the toy edge (spec §4).
class Squishable extends StatefulWidget {
  const Squishable({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<Squishable> createState() => _SquishableState();
}

class _SquishableState extends State<Squishable> {
  bool _pressed = false;

  void _set(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _set(true) : null,
          onTapUp: enabled ? (_) => _set(false) : null,
          onTapCancel: enabled ? () => _set(false) : null,
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? YMotion.squishScale : 1,
            duration: YMotion.press,
            curve: Curves.easeOut,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
