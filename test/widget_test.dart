import 'package:flutter_test/flutter_test.dart';
import 'package:asistencia_qr/app/app.dart';

void main() {
  testWidgets('La aplicación Asistencia Virtual inicia', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const AsistenciaVirtualApp());

    expect(find.byType(AsistenciaVirtualApp), findsOneWidget);
  });
}
