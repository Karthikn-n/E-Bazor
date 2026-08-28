import 'package:Ebozor/ui/screens/location/city_selection_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('city selector preserves its source flow', () {
    const screen = CitySelectionScreen(from: 'profile');
    expect(screen.from, 'profile');
  });
}
