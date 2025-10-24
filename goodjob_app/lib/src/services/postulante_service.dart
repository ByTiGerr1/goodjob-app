import 'package:cloud_firestore/cloud_firestore.dart';
// ⚠️ 1. IMPORTA TU SERVICIO DE ENCRIPTACIÓN (Ajusta la ruta si es necesario)
import 'package:goodjob_app/src/services/encryption_service.dart';

class PostulanteService {
  // Instancia de Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ⚠️ 2. INSTANCIA DEL SERVICIO DE ENCRIPTACIÓN
  // Asegúrate de que EncryptionService esté configurado correctamente
  final EncryptionService _encryptionService = EncryptionService();

  // Colección de usuarios
  static const String _collectionName = 'usuarios';

  /// Obtiene los datos del perfil de un postulante por su ID.
  /// DESENCRIPTA los datos bancarios si existen.
  /// Retorna un Map<String, dynamic> si el usuario existe, o null en caso de error o no encontrado.
  Future<Map<String, dynamic>?> obtenerDatosUsuario(String usuarioId) async {
    try {
      final docSnapshot =
          await _firestore.collection(_collectionName).doc(usuarioId).get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        // Obtenemos los datos originales
        final userData = docSnapshot.data()!;

        // --- INICIO DE LA DESENCRIPTACIÓN ---
        Map<String, dynamic> datosBancariosDesencriptados = {};

        // Verificamos si existe el mapa 'datosBancarios' y lo copiamos
        // Esto incluye campos no encriptados como 'rut'
        if (userData.containsKey('datosBancarios') && userData['datosBancarios'] is Map) {
          datosBancariosDesencriptados = Map<String, dynamic>.from(userData['datosBancarios']);
        } else {
          // Si no existe 'datosBancarios', podemos crear un mapa vacío
          // o manejarlo como prefieras. Aquí creamos uno vacío.
          userData['datosBancarios'] = {}; // Asegura que el mapa exista para el siguiente paso
        }

        try {
          // Extraemos los valores encriptados (si existen)
          final bancoEncriptado = userData['datosBancarios']?['banco'] as String?;
          final numeroCuentaEncriptado = userData['datosBancarios']?['numeroCuenta'] as String?;
          final tipoCuentaEncriptado = userData['datosBancarios']?['tipoCuenta'] as String?;

          // Desencriptamos cada campo si tiene valor
          if (bancoEncriptado != null && bancoEncriptado.isNotEmpty) {
            datosBancariosDesencriptados['banco'] = await _encryptionService.decrypt(bancoEncriptado);
          }
          if (numeroCuentaEncriptado != null && numeroCuentaEncriptado.isNotEmpty) {
            datosBancariosDesencriptados['numeroCuenta'] = await _encryptionService.decrypt(numeroCuentaEncriptado);
          }
          if (tipoCuentaEncriptado != null && tipoCuentaEncriptado.isNotEmpty) {
            datosBancariosDesencriptados['tipoCuenta'] = await _encryptionService.decrypt(tipoCuentaEncriptado);
          }
          
          // NOTA: Si 'rut' también estuviera encriptado, añadirías aquí:
          // final rutEncriptado = userData['datosBancarios']?['rut'] as String?;
          // if (rutEncriptado != null && rutEncriptado.isNotEmpty) {
          //   datosBancariosDesencriptados['rut'] = await _encryptionService.decrypt(rutEncriptado);
          // }

        } catch (e) {
          print('⚠️ Error al desencriptar datos bancarios para usuario $usuarioId: $e');
          // Puedes decidir si lanzar el error, retornar null, o continuar con datos parciales.
          // Aquí continuamos, los campos que fallaron quedarán como estaban (posiblemente encriptados o null).
        }

        // Creamos una copia modificable de los datos del usuario
        final userDataModificado = Map<String, dynamic>.from(userData);
        // Reemplazamos el mapa 'datosBancarios' con el que contiene los datos desencriptados
        userDataModificado['datosBancarios'] = datosBancariosDesencriptados;
        // --- FIN DE LA DESENCRIPTACIÓN ---

        // Opcional: añadir el ID del documento a los datos
        userDataModificado['id'] = docSnapshot.id;

        return userDataModificado; // Devolvemos el mapa con los datos bancarios actualizados

      } else {
        // Documento no encontrado o sin datos
        return null;
      }

    } catch (e) {
      // Manejo de errores de Firestore/red
      print('❌ Error general en obtenerDatosUsuario $usuarioId: $e');
      return null;
    }
  }
}