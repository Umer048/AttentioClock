ATTENTIOCLOCK - UPDATED PROJECT SOURCE
=====================================

This project preserves the existing Flutter project and includes the maroon/burgundy UI update, alarm editor, learning passage library, progress page, settings page, reading/quiz session, passage rotation, four bundled sounds, and custom WAV/MP3 selection.

INSTALL INTO YOUR EXISTING PROJECT
----------------------------------
1. Close the running app and stop any active Flutter run.
2. Make a backup copy of your current E:\AttentioClock_Rebuild folder.
3. Extract this ZIP.
4. Copy the contents of the extracted zipforchatgpt folder into E:\AttentioClock_Rebuild and allow files to be replaced.
5. Keep your own android\local.properties file. It contains computer-specific Flutter and Android SDK paths and is intentionally not included in this ZIP.
6. Open PowerShell in E:\AttentioClock_Rebuild and run:

   flutter pub get
   flutter analyze
   flutter run -d emulator-5554

ANDROID PERMISSIONS
-------------------
Allow Notifications, Alarms & reminders / exact alarms, and Full-screen notifications for AttentioClock in Android settings. Android versions and manufacturers may restrict full-screen alarm launches unless the special access is enabled.

IMPORTANT TESTING NOTE
---------------------
The Dart audio player loops the selected sound after the learning session screen starts. The scheduled Android notification is responsible for waking/opening the app. This source does not add a separate native Android foreground alarm-audio service, so continuous custom ringtone playback after Android kills the app process or after the user force-stops the app is not guaranteed. Android force-stop also prevents scheduled app alarms from firing until the app is opened again. Test alarm delivery on the actual target phone; emulator success alone is not proof of production reliability.

The Flutter SDK is not installed in the file-preparation environment used to prepare this ZIP, so a fresh flutter analyze/build could not be run here. Run the commands above on your development PC and share any error output if something appears.
