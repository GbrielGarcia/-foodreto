import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foodreto/core/firebase/emulator_config.dart';

void main() {
  test('projectId del emulador coincide con el seed (demo-foodreto)', () {
    expect(EmulatorConfig.projectId, 'demo-foodreto');
    expect(EmulatorConfig.firestorePort, 8080);
    expect(EmulatorConfig.authPort, 9099);
  });

  test('optionsFor fuerza el projectId del emulador', () {
    const base = FirebaseOptions(
      apiKey: 'x',
      appId: '1:1:android:x',
      messagingSenderId: '1',
      projectId: 'foodreto',
    );
    expect(EmulatorConfig.optionsFor(base).projectId, 'demo-foodreto');
    expect(EmulatorConfig.optionsFor(base).apiKey, 'x');
  });

  test('host por plataforma', () {
    expect(
      EmulatorConfig.host(fromEnvironment: '192.168.1.5'),
      '192.168.1.5',
    );
    expect(
      EmulatorConfig.host(
        fromEnvironment: '',
        platform: TargetPlatform.android,
        isWeb: false,
      ),
      '10.0.2.2',
    );
    expect(
      EmulatorConfig.host(
        fromEnvironment: '',
        platform: TargetPlatform.iOS,
        isWeb: false,
      ),
      'localhost',
    );
    expect(
      EmulatorConfig.host(
        fromEnvironment: '',
        platform: TargetPlatform.android,
        isWeb: true,
      ),
      'localhost',
    );
  });
}
