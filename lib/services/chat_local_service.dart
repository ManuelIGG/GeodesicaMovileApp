import 'package:flutter_application_4_geodesica/data/database_helper.dart';

class ChatLocalService {
  static final dbHelper = DatabaseHelper();

   // Obtener o crear chat ID (debe devolver String)
  static Future<String> getOrCreateChatId(String userId) async { // Cambiado a String
    final chats = await dbHelper.getChatsForUser(userId);
    if (chats.isNotEmpty) {
      return chats.first['id'] as String; // Devuelve String
    } else {
      final newChat = {
        'user_id': userId,
        'title': 'Conversación ${DateTime.now().toIso8601String()}',
      };
      return await dbHelper.insertChat(newChat); // Ya devuelve String
    }
  }

  // Guardar mensaje (chatId es String)
  static Future<void> saveMessage(String chatId, String rol, String mensaje) async {
    final nuevoMensaje = {
      'chat_id': chatId, // String
      'rol': rol,
      'message': mensaje,
    };
    await dbHelper.insertChatMessage(nuevoMensaje);
  }

  // Obtener mensajes de un chat (chatId es String)
  static Future<List<Map<String, String>>> getMessages(String chatId) async {
    final rawMessages = await dbHelper.getMessagesForChat(chatId); // String
    return rawMessages.map((msg) {
      return {
        'role': msg['rol'] as String,
        'content': msg['message'] as String,
      };
    }).toList();
  }
  
  // Obtener Titulo del chat
/*
static Future<String> generateChatTitle(String firstMessage) async {
  // Limpia el mensaje y toma las primeras palabras relevantes
  final cleanMessage = firstMessage
      .replaceAll(RegExp(r'[^\w\sáéíóúñ]'), '') // Elimina caracteres especiales
      .split(' ')
      .where((word) => word.length > 3) // Filtra palabras muy cortas
      .take(5) // Toma hasta 5 palabras
      .join(' ');
  
  return cleanMessage.isEmpty 
      ? 'Update chat' // Fallback si no se puede generar título
      : cleanMessage.length > 30 
          ? '${cleanMessage.substring(0, 30)}...' 
          : cleanMessage;
}*/







}
