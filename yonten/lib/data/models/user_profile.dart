import 'progress.dart';

/// `users/{uid}` (spec §7).
class UserProfile {
  const UserProfile({
    this.displayName = 'Explorer',
    this.level = 1,
    this.xp = 0,
    this.streak = const Streak(),
    this.stats = const Stats(),
    this.progress = MapProgress.start,
    this.settings = const UserSettings(),
    this.activeDates = const [],
  });

  final String displayName;
  final int level;
  final int xp;
  final Streak streak;
  final Stats stats;
  final MapProgress progress;
  final UserSettings settings;

  /// Recent days (local `yyyy-mm-dd`, oldest first) with at least one scan
  /// or finished lesson. Drives the "This week" butter lamps.
  final List<String> activeDates;

  static const keepActiveDates = 14;

  static const xpPerLevel = 100;
  static int levelFor(int xp) => 1 + xp ~/ xpPerLevel;

  UserProfile copyWith({
    String? displayName,
    int? xp,
    Streak? streak,
    Stats? stats,
    MapProgress? progress,
    UserSettings? settings,
    List<String>? activeDates,
  }) {
    final newXp = xp ?? this.xp;
    return UserProfile(
      displayName: displayName ?? this.displayName,
      level: levelFor(newXp),
      xp: newXp,
      streak: streak ?? this.streak,
      stats: stats ?? this.stats,
      progress: progress ?? this.progress,
      settings: settings ?? this.settings,
      activeDates: activeDates ?? this.activeDates,
    );
  }

  Map<String, dynamic> toMap() => {
        'displayName': displayName,
        'level': level,
        'xp': xp,
        'streak': streak.toMap(),
        'stats': stats.toMap(),
        'progress': progress.toMap(),
        'settings': settings.toMap(),
        'activeDates': activeDates,
      };

  /// Tolerant of missing fields (old docs, legacy `users/{uid}` docs).
  factory UserProfile.fromMap(Map<String, dynamic>? m) {
    if (m == null) return const UserProfile();
    Map<String, dynamic>? sub(String k) =>
        m[k] is Map ? Map<String, dynamic>.from(m[k] as Map) : null;
    final xp = (m['xp'] as num?)?.toInt() ?? 0;
    return UserProfile(
      displayName: (m['displayName'] as String?)?.trim().isNotEmpty == true
          ? m['displayName'] as String
          : 'Explorer',
      level: levelFor(xp),
      xp: xp,
      streak: Streak.fromMap(sub('streak')),
      stats: Stats.fromMap(sub('stats')),
      progress: sub('progress') == null
          ? MapProgress.start
          : MapProgress.fromMap(sub('progress')!),
      settings: UserSettings.fromMap(sub('settings')),
      activeDates: [
        for (final d in (m['activeDates'] as List?) ?? const []) d as String,
      ],
    );
  }
}

class Streak {
  const Streak({this.count = 0, this.lastActiveDate});

  final int count;

  /// Child's local date, `yyyy-mm-dd`.
  final String? lastActiveDate;

  Map<String, dynamic> toMap() =>
      {'count': count, 'lastActiveDate': lastActiveDate};

  factory Streak.fromMap(Map<String, dynamic>? m) => Streak(
        count: (m?['count'] as num?)?.toInt() ?? 0,
        lastActiveDate: m?['lastActiveDate'] as String?,
      );
}

class Stats {
  const Stats({this.words = 0, this.hunts = 0, this.lessons = 0});

  final int words;
  final int hunts;
  final int lessons;

  Stats copyWith({int? words, int? hunts, int? lessons}) => Stats(
        words: words ?? this.words,
        hunts: hunts ?? this.hunts,
        lessons: lessons ?? this.lessons,
      );

  Map<String, dynamic> toMap() =>
      {'words': words, 'hunts': hunts, 'lessons': lessons};

  factory Stats.fromMap(Map<String, dynamic>? m) => Stats(
        words: (m?['words'] as num?)?.toInt() ?? 0,
        hunts: (m?['hunts'] as num?)?.toInt() ?? 0,
        lessons: (m?['lessons'] as num?)?.toInt() ?? 0,
      );
}

class UserSettings {
  const UserSettings({
    this.sound = true,
    this.dailyGoal = 3,
  });

  final bool sound;

  /// Words to find per day.
  final int dailyGoal;

  Map<String, dynamic> toMap() =>
      {'sound': sound, 'dailyGoal': dailyGoal};

  factory UserSettings.fromMap(Map<String, dynamic>? m) => UserSettings(
        sound: m?['sound'] as bool? ?? true,
        dailyGoal: (m?['dailyGoal'] as num?)?.toInt() ?? 3,
      );
}
