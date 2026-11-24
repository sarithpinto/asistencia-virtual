import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SesionProvider extends ChangeNotifier {
  User? _usuario;
  String? _rol;
  bool _cargando = false;

  User? get usuario => _usuario;
  String? get rol => _rol;
  bool get cargando => _cargando;
  bool get autenticado => _usuario != null;

  void establecerSesion({required User usuario, required String rol}) {
    _usuario = usuario;
    _rol = rol;
    notifyListeners();
  }

  void cerrarSesionLocal() {
    _usuario = null;
    _rol = null;
    notifyListeners();
  }

  void establecerCargando(bool valor) {
    _cargando = valor;
    notifyListeners();
  }
}
