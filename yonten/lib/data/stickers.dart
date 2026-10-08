/// Stickers a child can earn from map chests (spec §5 Backpack).
abstract final class StickerCatalog {
  /// Slots shown in the Backpack ("N of 3").
  static const slots = 3;

  static const _art = {
    'chorten': 'assets/images/chorten.webp',
  };

  /// Image for a sticker; unknown ids fall back to the chorten.
  static String asset(String stickerId) => _art[stickerId] ?? _art['chorten']!;
}
