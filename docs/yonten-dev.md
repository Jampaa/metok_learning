# Yonten: developer commands

## Run the app

```sh
cd yonten
flutter run -d chrome --web-port 8080                    # production Firebase (tashi-learn)
flutter run -d chrome --web-port 8080 --dart-define=USE_EMULATORS=true   # local emulators
```

The developer gallery is at `http://localhost:8080/#/gallery`. It shows
where data comes from (Firestore or local) and has buttons to complete the
current lesson, load the spec's demo state, or start over.

## Checks

| What | Command |
|---|---|
| Lint, unit and widget tests | `cd yonten && flutter analyze && flutter test` |
| Web build | `cd yonten && flutter build web` |
| Security rules (15 tests) | `cd firebase/tests && npm install && npm test` |
| Real Firestore code against the emulators | see "Emulator smoke check" below |

The emulators need **Java 21** (`brew install openjdk@21`). Before any
`firebase emulators:*` command, run
`export PATH="/opt/homebrew/opt/openjdk@21/bin:$PATH"`.

## Emulators

Ports are in `firebase.json`:

| Service | Port |
|---|---|
| Auth | 9099 |
| Firestore | 8085 (8080 is Flutter's web port) |
| Storage | 9199 |
| Emulator UI | 4000 |

```sh
firebase emulators:start --only auth,firestore,storage --project tashi-learn
functions/.venv/bin/python -I functions/seed_curriculum.py --emulator
```

### Emulator smoke check

`yonten/integration/emulator_check.dart` runs the real repositories in
Chrome against the emulators. It checks sign-in, curriculum read,
lessons, chest sticker, scans, XP and streak, plus server rule rejections
and the offline fallback. Every line should say PASS.

```sh
cd yonten && flutter run -d chrome --web-port 8081 -t integration/emulator_check.dart
```

## Seed data

`yonten/assets/data/curriculum.json` and `vocab_seed.json` are the single
source of truth. The app bundles them as its offline fallback, and the
seed scripts upload them.

```sh
python3 -m venv functions/.venv && functions/.venv/bin/pip install -r functions/requirements.txt
functions/.venv/bin/python -I functions/seed_curriculum.py --dry-run
GOOGLE_APPLICATION_CREDENTIALS=key.json functions/.venv/bin/python -I functions/seed_curriculum.py --project tashi-learn
```

## Deploy rules

Only after the rules tests pass. These rules also serve the legacy app
until the Phase 10 cutover.

```sh
firebase deploy --only firestore:rules,storage --project tashi-learn
```
