import 'package:flutter/material.dart';
import 'admin_trabajo_detalle_screen.dart';
import 'admin_trabajo_por_revisar_screen.dart';
import 'admin_trabajo_por_pagar_screen.dart';


/// Retorna la vista adecuada para el trabajo según su estado
Widget getAdminTrabajoView({
  required Map<String, dynamic> trabajoData,
  required String trabajoId,
  }){
  
  switch (trabajoData['estado']){
    case "porRevisar":
      return AdminTrabajoPorRevisarScreen(trabajoId: trabajoId, trabajo: trabajoData);
    case "porPagar":
      return AdminTrabajoPorPagarScreen(trabajoId: trabajoId, trabajo: trabajoData);
    // Agregar más vistas de estado según sea necesario
    
    default:
      return AdminTrabajoDetalleScreen(trabajoId: trabajoId, trabajo: trabajoData);
  }

}