import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../data/curriculum_providers.dart';
import '../../data/models/user_profile.dart';
import '../../services/account_linker.dart';
import '../../theme/colors.dart';
import '../../theme/text.dart';
import '../../widgets/ink_icons.dart';
import '../../widgets/toy_button.dart';
import '../../widgets/toy_card.dart';

/// Parent Settings (spec §5 Me), behind the hold-to-unlock button: the
/// child's name, account linking, daily goal and sound.
class ParentScreen extends ConsumerStatefulWidget {
  const ParentScreen({super.key});

  @override
  ConsumerState<ParentScreen> createState() => _ParentScreenState();
}

class _ParentScreenState extends ConsumerState<ParentScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _busy = false;
  bool _nameLoaded = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _link(Future<String> Function() action) async {
    setState(() => _busy = true);
    final msg = await action();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = msg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider).value ?? const UserProfile();
    final repo = ref.watch(userDataProvider);
    final linker = ref.watch(accountLinkerProvider);
    final settings = profile.settings;
    if (!_nameLoaded && ref.watch(profileProvider).hasValue) {
      _nameLoaded = true;
      _name.text = profile.displayName == 'Explorer' ? '' : profile.displayName;
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            Row(
              children: [
                SizedBox.square(
                  dimension: 52,
                  child: ToyButton(
                    semanticLabel: 'Close parent settings',
                    color: YColors.white,
                    circle: true,
                    padding: EdgeInsets.zero,
                    onPressed: () => context.canPop()
                        ? context.pop()
                        : context.go(Routes.me),
                    child: const InkIcon(InkGlyph.close, size: 28),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Parent Settings', style: YText.heading(28)),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _Section(
              title: "Child's name",
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 24,
                      style: YText.text(18),
                      decoration: _input('e.g. Tenzin'),
                      onSubmitted: (v) => repo.updateName(v),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ToyButton(
                    semanticLabel: 'Save name',
                    label: 'Save',
                    onPressed: () {
                      repo.updateName(_name.text);
                      FocusScope.of(context).unfocus();
                      setState(() => _message = 'Name saved.');
                    },
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Account',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    linker.status,
                    style: YText.text(15, color: YColors.mutedStrong),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Linking keeps all progress, words and photos, and lets you '
                    'restore them on another device.',
                    style: YText.text(14, color: YColors.muted),
                  ),
                  const SizedBox(height: 12),
                  if (linker.available && !linker.linked) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        ToyButton(
                          semanticLabel: 'Link a Google account',
                          label: 'Link Google',
                          color: YColors.white,
                          onPressed: _busy
                              ? null
                              : () => _link(linker.linkGoogle),
                        ),
                        ToyButton(
                          semanticLabel: 'Link an Apple account',
                          label: 'Link Apple',
                          color: YColors.white,
                          onPressed: _busy
                              ? null
                              : () => _link(linker.linkApple),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      style: YText.text(16),
                      decoration: _input('Parent email'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: true,
                      autofillHints: const [AutofillHints.newPassword],
                      style: YText.text(16),
                      decoration: _input('Password (6+ characters)'),
                    ),
                    const SizedBox(height: 10),
                    ToyButton(
                      semanticLabel: 'Link with email',
                      label: 'Link email',
                      expand: true,
                      onPressed: _busy
                          ? null
                          : () => _link(
                              () =>
                                  linker.linkEmail(_email.text, _password.text),
                            ),
                    ),
                  ],
                ],
              ),
            ),
            _Section(
              title: 'Daily goal',
              child: Row(
                children: [
                  _Step(
                    label: 'Fewer things to find each day',
                    text: '−',
                    onTap: settings.dailyGoal > 1
                        ? () => repo.updateSettings(
                            UserSettings(
                              sound: settings.sound,
                              dailyGoal: settings.dailyGoal - 1,
                            ),
                          )
                        : null,
                  ),
                  Expanded(
                    child: Text(
                      'Find ${settings.dailyGoal} ${settings.dailyGoal == 1 ? 'thing' : 'things'} a day',
                      textAlign: TextAlign.center,
                      style: YText.label(18),
                    ),
                  ),
                  _Step(
                    label: 'More things to find each day',
                    text: '+',
                    onTap: settings.dailyGoal < 10
                        ? () => repo.updateSettings(
                            UserSettings(
                              sound: settings.sound,
                              dailyGoal: settings.dailyGoal + 1,
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),
            _Section(
              title: 'Sound',
              child: ToyButton(
                semanticLabel: settings.sound
                    ? 'Sound is on. Tap to turn off'
                    : 'Sound is off. Tap to turn on',
                label: settings.sound ? 'Sound: on' : 'Sound: off',
                color: settings.sound ? YColors.sky : YColors.white,
                expand: true,
                onPressed: () => repo.updateSettings(
                  UserSettings(
                    sound: !settings.sound,
                    dailyGoal: settings.dailyGoal,
                  ),
                ),
              ),
            ),
            if (_message != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: YText.text(16, bold: true),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static InputDecoration _input(String hint) => InputDecoration(
    hintText: hint,
    counterText: '',
    filled: true,
    fillColor: YColors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: YColors.ink, width: 2),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: YColors.ink, width: 2),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: YColors.skyDark, width: 2.5),
    ),
  );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: ToyCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: YText.heading(20)),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.label, required this.text, required this.onTap});

  final String label;
  final String text;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 52,
    child: ToyButton(
      semanticLabel: label,
      label: text,
      color: YColors.white,
      circle: true,
      padding: EdgeInsets.zero,
      onPressed: onTap,
    ),
  );
}
