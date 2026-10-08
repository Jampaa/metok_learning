import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The longest side we keep and send (spec §8.1: at most 1024 px).
const maxPhotoSide = 1024;

/// Returns a JPEG no larger than [maxSide] on its long side. Small enough
/// for the 2 MB Storage limit and quick to send to `identify_object`.
/// If the bytes can't be decoded, they're returned unchanged.
Uint8List shrinkJpeg(Uint8List bytes, {int maxSide = maxPhotoSide, int quality = 82}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  final oriented = img.bakeOrientation(decoded);
  final long = oriented.width > oriented.height ? oriented.width : oriented.height;
  final resized = long <= maxSide
      ? oriented
      : img.copyResize(
          oriented,
          width: oriented.width >= oriented.height ? maxSide : null,
          height: oriented.height > oriented.width ? maxSide : null,
          interpolation: img.Interpolation.average,
        );
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}
