import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/providers.dart';
import '../theme/colors.dart';

/// The picture on a word's flash card: the child's own photo of it, and
/// only that (D37). Shown from the device copy when there is one (instant,
/// works offline), otherwise from the uploaded copy. With no photo at all
/// (e.g. demo words) it's a plain paper tile, never drawn art.
class WordPhoto extends ConsumerWidget {
  const WordPhoto({
    super.key,
    this.photoId,
    this.imageUrl,
    this.bytes,
    this.size = 120,
    this.radius = 16,
    this.semanticLabel,
  });

  final String? photoId;
  final String? imageUrl;

  /// Bytes already in hand (the scanner's just-taken photo).
  final Uint8List? bytes;
  final double size;
  final double radius;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = bytes ??
        (photoId == null ? null : ref.watch(photoStoreProvider).local(photoId!));
    final Widget image;
    if (local != null) {
      image = Image.memory(local, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (imageUrl != null && imageUrl!.isNotEmpty) {
      image = Image.network(
        imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const _NoPhoto(),
      );
    } else {
      image = const _NoPhoto();
    }

    return Semantics(
      image: true,
      label: semanticLabel ?? 'Your photo',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: YColors.slateTint,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: YColors.ink, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: image,
      ),
    );
  }
}

class _NoPhoto extends StatelessWidget {
  const _NoPhoto();

  @override
  Widget build(BuildContext context) => Center(
        child: Opacity(
          opacity: 0.35,
          child: Image.asset('assets/images/nav-camera.webp',
              width: 40, height: 40, excludeFromSemantics: true),
        ),
      );
}
