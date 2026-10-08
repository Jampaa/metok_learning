import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/text.dart';
import 'toy_surface.dart';

/// Pressable toy button (spec §4). Pass [onPressed] = null to disable it:
/// it then uses the disabled colors and ignores taps.
class ToyButton extends StatefulWidget {
  const ToyButton({
    super.key,
    required this.semanticLabel,
    required this.onPressed,
    this.child,
    this.label,
    this.color = YColors.sky,
    this.circle = false,
    this.radius = 16,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
    this.expand = false,
  }) : assert(child != null || label != null);

  /// Read by screen readers. Required: every tappable has a label (§4).
  final String semanticLabel;
  final VoidCallback? onPressed;
  final Widget? child;

  /// Convenience: a Grandstander label in ink (text on blue stays ink, §4).
  final String? label;
  final Color color;
  final bool circle;
  final double radius;
  final EdgeInsetsGeometry padding;

  /// Stretch to the full available width.
  final bool expand;

  @override
  State<ToyButton> createState() => _ToyButtonState();
}

class _ToyButtonState extends State<ToyButton> {
  bool _pressed = false;

  bool get _enabled => widget.onPressed != null;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final content = widget.child ??
        Text(
          widget.label!,
          textAlign: TextAlign.center,
          style: YText.label(
            18,
            color: enabled ? YColors.ink : YColors.disabledText,
          ),
        );

    Widget surface = ToySurface(
      color: enabled ? widget.color : YColors.disabledFill,
      edgeColor: enabled ? YColors.ink : YColors.disabledBorder,
      circle: widget.circle,
      radius: widget.radius,
      pressed: _pressed,
      padding: widget.padding,
      child: Center(widthFactor: widget.expand ? null : 1, child: content),
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.expand ? double.infinity : 44,
          minHeight: 44,
        ),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: enabled ? (_) => _setPressed(true) : null,
          onTapUp: enabled ? (_) => _setPressed(false) : null,
          onTapCancel: enabled ? () => _setPressed(false) : null,
          onTap: widget.onPressed,
          child: surface,
        ),
      ),
    );
  }
}
