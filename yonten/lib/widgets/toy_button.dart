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
    this.border = 2,
    this.muted = false,
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

  /// Outline width (the shutter and Scan button use 2.5–3 px).
  final double border;

  /// Uses the disabled colors but still takes taps, e.g. a locked map
  /// node that answers with a gentle "opens soon" message.
  final bool muted;

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
    final looksEnabled = enabled && !widget.muted;
    final content = widget.child ??
        Text(
          widget.label!,
          textAlign: TextAlign.center,
          style: YText.label(
            18,
            color: looksEnabled ? YColors.ink : YColors.disabledText,
          ),
        );

    Widget surface = ToySurface(
      color: looksEnabled ? widget.color : YColors.disabledFill,
      edgeColor: looksEnabled ? YColors.ink : YColors.disabledBorder,
      circle: widget.circle,
      radius: widget.radius,
      pressed: _pressed,
      border: widget.border,
      padding: widget.padding,
      child: Center(widthFactor: widget.expand ? null : 1, child: content),
    );

    return Semantics(
      container: true,
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
