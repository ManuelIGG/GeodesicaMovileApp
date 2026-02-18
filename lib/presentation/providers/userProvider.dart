import 'package:flutter/foundation.dart';
import 'package:flutter_application_4_geodesica/model/user_model.dart';

class UserProvider with ChangeNotifier {
  UserModel? _currentUser;
  String? _currentChatId; // Cambiado de int? a String?

  UserModel? get currentUser => _currentUser;
  String? get currentChatId => _currentChatId;

  // Getter que devuelve el ID del usuario actual (ahora String)
  String? get currentUserId => _currentUser?.id;

  void setCurrentUser(UserModel user) {
    _currentUser = user;
    notifyListeners();
  }

  void setCurrentChatId(String chatId) { // Cambiado a String
    _currentChatId = chatId;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _currentChatId = null;
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;

  // Método para actualizar información del usuario
  void updateUserInfo({
    String? fullName,
    String? birthDate,
    String? document,
  }) {
    if (_currentUser != null) {
      _currentUser = _currentUser!.copyWith(
        fullName: fullName ?? _currentUser!.fullName,
        birthDate: birthDate ?? _currentUser!.birthDate,
        document: document ?? _currentUser!.document,
      );
      notifyListeners();
    }
  }

  // Método para verificar si el usuario está autenticado con Firebase
  Future<bool> checkFirebaseAuth() async {
    // Este método será implementado cuando integres Firebase Auth directamente
    return _currentUser != null;
  }
}