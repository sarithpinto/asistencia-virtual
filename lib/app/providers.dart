import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import 'package:asistencia_qr/providers/sesion_provider.dart';

List<SingleChildWidget> obtenerProviders() {
  return [
    ChangeNotifierProvider<SesionProvider>(create: (_) => SesionProvider()),
  ];
}
