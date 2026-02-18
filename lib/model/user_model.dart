import 'package:cloud_firestore/cloud_firestore.dart';

/// Modelo que representa un usuario.
class UserModel {
  // Propiedades que almacenan la información del usuario
  final String? id;
  final String fullName;
  final String email;
  final String password;
  final String? birthDate;
  final String? document;
  final String? createdAt;

  UserModel({
    this.id,
    required this.fullName,
    required this.email,
    required this.password,
    this.birthDate,
    this.document,
    this.createdAt,
  });

  // Constructor factory que convierte un DocumentSnapshot de Firestore a un objeto UserModel
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    
    return UserModel(
      id: doc.id,
      fullName: data['fullName'] ?? '',
      email: data['email'] ?? '',
      password: '', // La contraseña no se almacena en Firestore por seguridad
      birthDate: data['birthDate'],
      document: data['document'],
      createdAt: data['created_at']?.toString(),
    );
  }

  // Constructor factory que convierte un Map a un objeto UserModel
  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      id: map['id']?.toString(),
      fullName: map['fullName'] ?? '',
      email: map['email'] ?? '',
      password: map['password'] ?? '',
      birthDate: map['birthDate'],
      document: map['document'],
      createdAt: map['created_at']?.toString(),
    );
  }

  // Método que convierte el objeto UserModel a un Map para Firestore
  Map<String, dynamic> toFirestore() {
    final Map<String, dynamic> data = {
      'fullName': fullName,
      'email': email,
    };

    // Agregar campos opcionales solo si no son null
    if (birthDate != null && birthDate!.isNotEmpty) {
      data['birthDate'] = birthDate;
    }
    
    if (document != null && document!.isNotEmpty) {
      data['document'] = document;
    }

    // Manejar createdAt - si no existe, Firestore agregará serverTimestamp
    if (createdAt != null && createdAt!.isNotEmpty) {
      try {
        data['created_at'] = Timestamp.fromDate(DateTime.parse(createdAt!));
      } catch (e) {
        // Si hay error al parsear, usar serverTimestamp
        data['created_at'] = FieldValue.serverTimestamp();
      }
    } else {
      data['created_at'] = FieldValue.serverTimestamp();
    }

    return data;
  }

  // Método que convierte el objeto UserModel a un Map (para compatibilidad)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fullName': fullName,
      'email': email,
      'password': password,
      'birthDate': birthDate,
      'document': document,
      'created_at': createdAt,
    };
  }

  // Método para crear una copia del usuario con nuevos valores
  UserModel copyWith({
    String? id,
    String? fullName,
    String? email,
    String? password,
    String? birthDate,
    String? document,
    String? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      password: password ?? this.password,
      birthDate: birthDate ?? this.birthDate,
      document: document ?? this.document,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}