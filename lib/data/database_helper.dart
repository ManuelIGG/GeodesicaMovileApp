import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  
  // Firestore instance
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  // Nombres de colecciones (equivalentes a tablas)
  final String tableUsers = 'users';
  final String tableChats = 'chats';
  final String tableChatMessages = 'chat_messages';

  // Factory constructor
  factory DatabaseHelper() {
    return _instance;
  }

  // Constructor interno privado
  DatabaseHelper._internal();

  // Helper method para convertir Timestamp a String
  String? _timestampToString(dynamic timestamp) {
    if (timestamp == null) return null;
    if (timestamp is Timestamp) {
      return timestamp.toDate().toIso8601String();
    }
    return timestamp.toString();
  }

 
    // CRUD para Usuarios
  Future<String> insertUser(Map<String, dynamic> row) async {
    try {
      // Verificar que los campos requeridos estén presentes
      if (!row.containsKey('email') || !row.containsKey('password')) {
        throw Exception('Email y contraseña son requeridos para crear usuario');
      }
      
      // Primero creamos el usuario en Firebase Authentication
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: row['email'].toString(),
        password: row['password'].toString(),
      );
      
      // Luego guardamos la información adicional en Firestore
      final userData = Map<String, dynamic>.from(row);
      userData.remove('password'); // No guardamos la contraseña en Firestore
      
      // Asegurar que los campos existan antes de guardar
      userData['created_at'] = FieldValue.serverTimestamp();
      
      // Asegurarse de que los campos opcionales no sean null
      if (!userData.containsKey('fullName') || userData['fullName'] == null) {
        userData['fullName'] = 'Usuario';
      }
      
      await _firestore
          .collection(tableUsers)
          .doc(userCredential.user!.uid)
          .set(userData);
      
      return userCredential.user!.uid;
    } catch (e) {
      print('Error al insertar usuario: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection(tableUsers)
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        data['id'] = doc.id; // Agregamos el ID del documento
        data['created_at'] = _timestampToString(data['created_at']);
        return data;
      }
      return null;
    } catch (e) {
      print('Error al obtener usuario por email: $e');
      rethrow;
    }
  }

  // Método adicional para obtener usuario por UID
  Future<Map<String, dynamic>?> getUserByUid(String uid) async {
    try {
      final doc = await _firestore
          .collection(tableUsers)
          .doc(uid)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        data['id'] = doc.id;
        data['created_at'] = _timestampToString(data['created_at']);
        return data;
      }
      return null;
    } catch (e) {
      print('Error al obtener usuario por UID: $e');
      rethrow;
    }
  }

  // CRUD para Chats
  Future<String> insertChat(Map<String, dynamic> row) async {
    try {
      final docRef = await _firestore.collection(tableChats).add({
        ...row,
        'created_at': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error al insertar chat: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getChatsForUser(String userId) async {
    try {
      final querySnapshot = await _firestore
          .collection(tableChats)
          .where('user_id', isEqualTo: userId)
          .orderBy('created_at', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['created_at'] = _timestampToString(data['created_at']);
        return data;
      }).toList();
    } catch (e) {
      print('Error al obtener chats para usuario: $e');
      rethrow;
    }
  }

  // CRUD para Mensajes de Chat
  Future<String> insertChatMessage(Map<String, dynamic> row) async {
    try {
      final docRef = await _firestore.collection(tableChatMessages).add({
        ...row,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    } catch (e) {
      print('Error al insertar mensaje de chat: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMessagesForChat(String chatId) async {
    try {
      final querySnapshot = await _firestore
          .collection(tableChatMessages)
          .where('chat_id', isEqualTo: chatId)
          .orderBy('timestamp', descending: false)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        data['timestamp'] = _timestampToString(data['timestamp']);
        return data;
      }).toList();
    } catch (e) {
      print('Error al obtener mensajes para chat: $e');
      rethrow;
    }
  }

  Future<void> deleteChat(String chatId) async {
    try {
      // Primero eliminamos todos los mensajes asociados al chat
      final messagesSnapshot = await _firestore
          .collection(tableChatMessages)
          .where('chat_id', isEqualTo: chatId)
          .get();

      // Eliminar cada mensaje individualmente
      final batch = _firestore.batch();
      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      // Luego eliminamos el chat
      await _firestore.collection(tableChats).doc(chatId).delete();
    } catch (e) {
      print('Error al eliminar chat: $e');
      rethrow;
    }
  }

  Future<void> updateChatTitle(String chatId, String newTitle) async {
    try {
      // Verificar si el chat existe
      final doc = await _firestore.collection(tableChats).doc(chatId).get();
      
      if (!doc.exists) {
        throw Exception('Chat no encontrado con ID: $chatId');
      }

      await _firestore
          .collection(tableChats)
          .doc(chatId)
          .update({'title': newTitle});
    } catch (e) {
      print('Error al actualizar título del chat: $e');
      rethrow;
    }
  }

  // Método adicional para actualizar información de usuario
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(tableUsers)
          .doc(userId)
          .update(updates);
    } catch (e) {
      print('Error al actualizar usuario: $e');
      rethrow;
    }
  }

  // Método adicional para eliminar usuario
  Future<void> deleteUser(String userId) async {
    try {
      // Primero eliminamos todos los chats del usuario
      final chatsSnapshot = await _firestore
          .collection(tableChats)
          .where('user_id', isEqualTo: userId)
          .get();

      final batch = _firestore.batch();
      
      // Para cada chat, eliminamos sus mensajes primero
      for (final chatDoc in chatsSnapshot.docs) {
        final messagesSnapshot = await _firestore
            .collection(tableChatMessages)
            .where('chat_id', isEqualTo: chatDoc.id)
            .get();
            
        for (final msgDoc in messagesSnapshot.docs) {
          batch.delete(msgDoc.reference);
        }
        batch.delete(chatDoc.reference);
      }
      
      await batch.commit();
      
      // Finalmente eliminamos el usuario
      await _firestore.collection(tableUsers).doc(userId).delete();
      
      // También eliminamos la cuenta de Authentication
      await _auth.currentUser?.delete();
    } catch (e) {
      print('Error al eliminar usuario: $e');
      rethrow;
    }
  }

  // Método para obtener el usuario actualmente autenticado
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        return await getUserByUid(user.uid);
      }
      return null;
    } catch (e) {
      print('Error al obtener usuario actual: $e');
      rethrow;
    }
  }



// Stream para obtener mensajes de chat en tiempo real
Stream<List<Map<String, dynamic>>> getMessagesForChatStream(String chatId) {
  return _firestore
      .collection(tableChatMessages)
      .where('chat_id', isEqualTo: chatId)
      .orderBy('timestamp', descending: false)
      .snapshots()
      .map((querySnapshot) {
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['timestamp'] = _timestampToString(data['timestamp']);
      return data;
    }).toList();
  });
}

// Stream para obtener chats de usuario en tiempo real
Stream<List<Map<String, dynamic>>> getChatsForUserStream(String userId) {
  return _firestore
      .collection(tableChats)
      .where('user_id', isEqualTo: userId)
      .orderBy('created_at', descending: true)
      .snapshots()
      .map((querySnapshot) {
    return querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['created_at'] = _timestampToString(data['created_at']);
      return data;
    }).toList();
  });
}

}
