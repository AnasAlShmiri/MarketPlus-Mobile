import 'package:flutter_test/flutter_test.dart';
import 'package:marketplus_mobile/core/onboarding_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('onboarding is incomplete by default and persists completion', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final onboarding = OnboardingPreferences(preferences);

    expect(onboarding.isCompleted, isFalse);

    final saved = await onboarding.markCompleted();

    expect(saved, isTrue);
    expect(onboarding.isCompleted, isTrue);
    expect(
      preferences.getBool(OnboardingPreferences.completedKey),
      isTrue,
    );
  });
}
