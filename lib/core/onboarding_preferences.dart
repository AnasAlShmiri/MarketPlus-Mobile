import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  OnboardingPreferences(this._preferences);

  static const completedKey = 'marketplus.onboarding.completed.v1';

  final SharedPreferences _preferences;

  bool get isCompleted => _preferences.getBool(completedKey) ?? false;

  Future<bool> markCompleted() => _preferences.setBool(completedKey, true);
}
