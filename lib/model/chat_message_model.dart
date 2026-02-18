
import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa un mensaje de chat.
/// Almacena la información de cada mensaje enviado en una conversación.
class ChatMessageModel {
  final String? id; // Cambiado de int? a String?
  final String chatId; // Cambiado de int a String
  final String rol;
  final String message;
  final String? timestamp;

  /// Constructor principal del modelo de los mensajes.
  ChatMessageModel({
    this.id,
    required this.chatId,
    required this.rol,
    required this.message,
    this.timestamp,
  });

  /// Crea una instancia del modelo a partir de un DocumentSnapshot de Firestore.
  factory ChatMessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ChatMessageModel(
      id: doc.id,
      chatId: data['chat_id']?.toString() ?? '',
      rol: data['rol'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp']?.toString(),
    );
  }

  /// Crea una instancia del modelo a partir de un Map (para compatibilidad).
  factory ChatMessageModel.fromMap(Map<String, dynamic> map) {
    return ChatMessageModel(
      id: map['id']?.toString(),
      chatId: map['chat_id']?.toString() ?? '',
      rol: map['rol'] ?? '',
      message: map['message'] ?? '',
      timestamp: map['timestamp']?.toString(),
    );
  }

  /// Convierte el modelo a un Map compatible con Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'chat_id': chatId,
      'rol': rol,
      'message': message,
      'timestamp': timestamp != null 
          ? Timestamp.fromDate(DateTime.parse(timestamp!))
          : FieldValue.serverTimestamp(),
    };
  }

  /// Convierte el modelo a un Map (para compatibilidad).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'rol': rol,
      'message': message,
      'timestamp': timestamp,
    };
  }

  /// Método para crear una copia del mensaje con nuevos valores.
  ChatMessageModel copyWith({
    String? id,
    String? chatId,
    String? rol,
    String? message,
    String? timestamp,
  }) {
    return ChatMessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      rol: rol ?? this.rol,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  /// Método para verificar si el mensaje es del usuario.
  bool get isUserMessage => rol.toLowerCase() == 'user';

  /// Método para verificar si el mensaje es del asistente.
  bool get isAssistantMessage => rol.toLowerCase() == 'assistant';
}