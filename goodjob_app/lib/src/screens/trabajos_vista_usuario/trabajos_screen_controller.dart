import 'package:flutter/foundation.dart';

import 'display_option.dart';

class TrabajosScreenController extends ChangeNotifier {
  DisplayOption _selectedDisplay = DisplayOption.upcoming;
  int _vistaActual = 0; // 0 -> Lista, 1 -> Mapa
  String? _ultimoTrabajoSeleccionadoId;
  bool _isCarouselInteracting = false;

  DisplayOption get selectedDisplay => _selectedDisplay;
  int get vistaActual => _vistaActual;
  String? get selectedTrabajoId => _ultimoTrabajoSeleccionadoId;
  bool get isCarouselInteracting => _isCarouselInteracting;

  void setSelectedDisplay(DisplayOption option) {
    if (_selectedDisplay == option) return;
    _selectedDisplay = option;
    notifyListeners();
  }

  void setVistaActual(int vista) {
    if (_vistaActual == vista) return;
    _vistaActual = vista;
    notifyListeners();
  }

  void setTrabajoSeleccionado(String? id) {
    if (_ultimoTrabajoSeleccionadoId == id) return;
    _ultimoTrabajoSeleccionadoId = id;
    notifyListeners();
  }

  bool registerTrabajoTap(String id) {
    if (_ultimoTrabajoSeleccionadoId == id) {
      return true;
    }
    _ultimoTrabajoSeleccionadoId = id;
    notifyListeners();
    return false;
  }

  void setCarouselInteraction(bool value) {
    if (_isCarouselInteracting == value) return;
    _isCarouselInteracting = value;
    notifyListeners();
  }
}
