import 'package:cloud_firestore/cloud_firestore.dart';

import 'dart:convert';
import 'chat_message_model.dart';

/// Modelo que representa un mensaje de usuario en el sistema de chat.
/// Se utiliza para intercambiar mensajes entre el cliente y el servidor.
class UserMessageModel {
  final String rol;
  final String message;
  final String id; // Cambiado de int a String

  // Constructor principal para crear instancias de mensajes de usuario.
  UserMessageModel({
    required this.rol,
    required this.message,
    required this.id,
  });

  /// Constructor factory que crea una instancia a partir de un mapa JSON.
  factory UserMessageModel.fromJson(Map<String, dynamic> json) {
    return UserMessageModel(
      rol: json['rol'] ?? '',
      message: json['message'] ?? '',
      id: json['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  /// Constructor factory que crea una instancia a partir de un DocumentSnapshot de Firestore.
  factory UserMessageModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserMessageModel(
      id: doc.id,
      rol: data['rol'] ?? '',
      message: data['message'] ?? '',
    );
  }

  /// Constructor factory que crea una instancia a partir de un ChatMessageModel.
  factory UserMessageModel.fromChatMessage(ChatMessageModel chatMessage) {
    return UserMessageModel(
      id: chatMessage.id ?? '',
      rol: chatMessage.rol,
      message: chatMessage.message,
    );
  }

  /// Convierte el modelo a un mapa compatible con JSON.
  Map<String, dynamic> toJson() {
    return {
      'rol': rol,
      'message': message,
      'id': id,
    };
  }

  /// Convierte el modelo a un String JSON.
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// Método para crear una copia del mensaje con nuevos valores.
  UserMessageModel copyWith({
    String? rol,
    String? message,
    String? id,
  }) {
    return UserMessageModel(
      rol: rol ?? this.rol,
      message: message ?? this.message,
      id: id ?? this.id,
    );
  }

  /// Método para verificar si el mensaje es del usuario.
  bool get isUserMessage => rol.toLowerCase() == 'user';

  /// Método para verificar si el mensaje es del asistente.
  bool get isAssistantMessage => rol.toLowerCase() == 'assistant';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is UserMessageModel &&
        other.id == id &&
        other.rol == rol &&
        other.message == message;
  }

  @override
  int get hashCode => id.hashCode ^ rol.hashCode ^ message.hashCode;
}