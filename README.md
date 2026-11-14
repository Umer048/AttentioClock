# AttentioClock

Flutter Android alarm + reading + comprehension app.

## Setup
1. Install Flutter SDK and Android Studio.
2. Open this project folder in Android Studio.
3. Keep your machine-specific `android/local.properties` file local (it is ignored by Git).
4. Run:
   ```bash
   flutter pub get
   flutter analyze
   flutter run
   ```

## Git / GitHub workflow
See `GITHUB_SETUP.md` for the first-time repository setup and regular commit/push workflow.

## Important testing note
A clean `flutter analyze` is not proof that Android alarms work while the app is terminated. Test notifications, exact-alarm permission, full-screen behavior, reboot behavior, and audio on a physical Android device before release.
