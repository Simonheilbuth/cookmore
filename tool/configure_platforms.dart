// Adds the native settings CookMore needs to the platform files generated
// by `flutter create`. Safe to run more than once.
//
// Run from the project folder:
//   dart run tool/configure_platforms.dart
//
// What it changes (Android):
// - AndroidManifest.xml: INTERNET and POST_NOTIFICATIONS permissions and the
//   receiver flutter_local_notifications uses for scheduled notifications.
// - app/build.gradle(.kts): core library desugaring (required by
//   flutter_local_notifications) and minSdk 23 (Android 6.0 or newer).
//
// ignore_for_file: avoid_print

import 'dart:io';

void main() {
  var ok = true;
  ok &= _patchManifest();
  ok &= _patchGradle();
  print(ok
      ? '\nDone. Platform files are configured for CookMore.'
      : '\nSome files could not be patched. See README.md for the manual steps.');
  if (!ok) exitCode = 1;
}

bool _patchManifest() {
  final file = File('android/app/src/main/AndroidManifest.xml');
  if (!file.existsSync()) {
    print('✗ ${file.path} not found. Run "flutter create ." first.');
    return false;
  }
  var text = file.readAsStringSync();
  final original = text;

  const permissions = [
    'android.permission.INTERNET',
    'android.permission.POST_NOTIFICATIONS',
  ];
  for (final permission in permissions) {
    if (text.contains('"$permission"')) continue;
    text = text.replaceFirst(
      '<application',
      '<uses-permission android:name="$permission" />\n    <application',
    );
  }

  const receiver =
      'com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver';
  if (!text.contains(receiver)) {
    text = text.replaceFirst(
      '</application>',
      '    <receiver android:exported="false" android:name="$receiver" />\n'
          '    </application>',
    );
  }

  if (text == original) {
    print('✓ AndroidManifest.xml already configured');
  } else {
    file.writeAsStringSync(text);
    print('✓ AndroidManifest.xml updated');
  }
  return true;
}

bool _patchGradle() {
  final kts = File('android/app/build.gradle.kts');
  final groovy = File('android/app/build.gradle');
  final file = kts.existsSync() ? kts : groovy;
  if (!file.existsSync()) {
    print('✗ android/app/build.gradle(.kts) not found.');
    return false;
  }
  final isKts = file.path.endsWith('.kts');
  var text = file.readAsStringSync();
  final original = text;

  // 1. Enable core library desugaring.
  final desugarFlag = isKts
      ? 'isCoreLibraryDesugaringEnabled = true'
      : 'coreLibraryDesugaringEnabled true';
  if (!text.contains(desugarFlag)) {
    if (!text.contains('compileOptions {')) {
      print('✗ Could not find "compileOptions {" in ${file.path}');
      return false;
    }
    text = text.replaceFirst(
      'compileOptions {',
      'compileOptions {\n        $desugarFlag',
    );
  }

  // 2. Add the desugaring library.
  const library = 'com.android.tools:desugar_jdk_libs:2.1.4';
  if (!text.contains(library)) {
    final line = isKts
        ? 'coreLibraryDesugaring("$library")'
        : "coreLibraryDesugaring '$library'";
    text = '${text.trimRight()}\n\ndependencies {\n    $line\n}\n';
  }

  // 3. Require at least Android 6.0 (API 23).
  final minSdkPattern = isKts
      ? RegExp(r'minSdk\s*=\s*flutter\.minSdkVersion')
      : RegExp(r'minSdk(Version)?\s+flutter\.minSdkVersion');
  final minSdkLine = isKts
      ? 'minSdk = maxOf(23, flutter.minSdkVersion)'
      : 'minSdkVersion Math.max(23, flutter.minSdkVersion)';
  if (minSdkPattern.hasMatch(text)) {
    text = text.replaceFirst(minSdkPattern, minSdkLine);
  }

  if (text == original) {
    print('✓ ${file.path} already configured');
  } else {
    file.writeAsStringSync(text);
    print('✓ ${file.path} updated');
  }
  return true;
}
