import 'package:flutter_test/flutter_test.dart';
import 'package:metastrip/core/storage/shared_preferences_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('reads, writes, and removes supported values', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final storage = SharedPreferencesStorage(preferences);

    await storage.setBool('completed', value: true);
    await storage.setString('folder', value: '/output');

    expect(storage.getBool('completed'), isTrue);
    expect(storage.getString('folder'), '/output');

    await storage.remove('folder');
    await storage.remove('folder');
    expect(storage.getString('folder'), isNull);
  });
}
