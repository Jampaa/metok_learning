/// Route paths in one place.
abstract final class Routes {
  static const map = '/map';
  static const backpack = '/backpack';
  static const quests = '/quests';
  static const me = '/me';
  static const scan = '/scan';

  /// Parent area, opened by the hold-to-unlock button on Me.
  static const parents = '/parents';

  /// Hidden developer gallery; reachable by URL only.
  static const gallery = '/gallery';
}
