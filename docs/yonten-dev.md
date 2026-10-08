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
| Security rules | `cd firebase/tests && npm install && npm test` |
| Cloud Functions unit tests | `cd functions && venv/bin/python -m pytest -q tests` |
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

| Functions | 5001 |

```sh
# macOS: these two variables stop the Python Functions emulator crashing (D44)
export OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES no_proxy='*'
firebase emulators:start --only auth,firestore,storage,functions --project tashi-learn
functions/venv/bin/python -I functions/seed_curriculum.py --emulator
functions/venv/bin/python -I functions/seed_vocab.py --emulator
```

The Functions emulator reads secrets from `functions/.secret.local`
(git-ignored):

```
GEMINI_API_KEY=...
MONLAM_API_KEY=...
```

Run the app against all emulators (real Gemini, local everything else):
`flutter run -d chrome --dart-define=USE_EMULATORS=true`. To demo scanning
with no backend at all, add `--dart-define=VISION_MOCK=true`.

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
/opt/homebrew/bin/python3.13 -m venv functions/venv && functions/venv/bin/pip install -r functions/requirements.txt pytest
functions/venv/bin/python -I functions/seed_curriculum.py --dry-run
GOOGLE_APPLICATION_CREDENTIALS=key.json functions/venv/bin/python -I functions/seed_curriculum.py --project tashi-learn
```

## Deploy functions (needs the Blaze plan)

```sh
firebase functions:secrets:set GEMINI_API_KEY --project tashi-learn
firebase functions:secrets:set MONLAM_API_KEY --project tashi-learn
firebase deploy --only functions --project tashi-learn
GOOGLE_APPLICATION_CREDENTIALS=key.json functions/venv/bin/python -I functions/seed_vocab.py --project tashi-learn
```

## Deploy rules

Only after the rules tests pass. These rules also serve the legacy app
until the Phase 10 cutover.

```sh
firebase deploy --only firestore:rules,storage --project tashi-learn
```
