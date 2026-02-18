import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa una conversación (chat) en la aplicación.
class ChatModel {
  final String? id; // Cambiado de int? a String?
  final String userId; // Cambiado de int a String
  final String title;
  final String? createdAt;

  /// Constructor principal del modelo de chat.
  ChatModel({
    this.id,
    required this.userId,
    required this.title,
    this.createdAt,
  });

  /// Instancia de ChatModel a partir de un DocumentSnapshot de Firestore.
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return ChatModel(
      id: doc.id,
      userId: data['user_id']?.toString() ?? '',
      title: data['title'] ?? 'Sin título',
      createdAt: data['created_at']?.toString(),
    );
  }

  /// Instancia de ChatModel a partir de un mapa de datos.
  factory ChatModel.fromMap(Map<String, dynamic> map) {
    return ChatModel(
      id: map['id']?.toString(),
      userId: map['user_id']?.toString() ?? '',
      title: map['title'] ?? 'Sin título',
      createdAt: map['created_at']?.toString(),
    );
  }

  /// Convierte el modelo a un mapa de datos compatible con Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'user_id': userId,
      'title': title,
      'created_at': createdAt != null 
          ? Timestamp.fromDate(DateTime.parse(createdAt!))
          : FieldValue.serverTimestamp(),
    };
  }

  /// Convierte el modelo a un mapa de datos (para compatibilidad).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'created_at': createdAt,
    };
  }

  /// Método para crear una copia del chat con nuevos valores.
  ChatModel copyWith({
    String? id,
    String? userId,
    String? title,
    String? createdAt,
  }) {
    return ChatModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}