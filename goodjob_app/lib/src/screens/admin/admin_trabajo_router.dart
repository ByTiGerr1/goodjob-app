import 'package:flutter/material.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_en_curso_screen.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_finalizado.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_pendiente.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_por_confirmar_screen.dart';
import 'package:goodjob_app/src/screens/admin/estados%20de%20trabajo/trabajo_rechazado_screen.dart';
import 'trabajo_detalle_screen.dart';
import 'estados de trabajo/trabajo_por_revisar_screen.dart';
import 'estados de trabajo/trabajo_por_pagar_screen.dart';


/// Retorna la vista adecuada para el trabajo según su estado
Widget getAdminTrabajoView({
  required Map<String, dynamic> trabajoData,
  required String trabajoId,
  }){
  
  switch (trabajoData['estado']){
    case "pendiente":
      return TrabajoPendiente(trabajoId: trabajoId, trabajo: trabajoData);
    case "porConfirmar":
      return TrabajoPorConfirmarScreen(trabajoId: trabajoId, trabajo: trabajoData);
    case "porRevisar":
      return TrabajoPorRevisarScreen(trabajoId: trabajoId, trabajo: trabajoData);
    case "enCurso":
      return TrabajoEnCursoScreen(trabajoId: trabajoId, trabajo: trabajoData);
    case "porPagar":
      return TrabajoPorPagarScreen(trabajoId: trabajoId, trabajo: trabajoData);
    case "finalizado":
      return TrabajoFinalizado(trabajoId: trabajoId, trabajo: trabajoData);
    case "rechazado":
      return TrabajoRechazadoScreen(trabajoId: trabajoId, trabajo: trabajoData);
    // Agregar más vistas de estado según sea necesario
    
    default:
      return AdminTrabajoDetalleScreen(trabajoId: trabajoId, trabajo: trabajoData);
  }

}