import 'package:flutter/material.dart';
import 'package:flutter_application_4_geodesica/presentation/screens/chatMain.dart';
import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:flutter_application_4_geodesica/model/user_model.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/userProvider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';

class AuthScreen extends StatefulWidget {
  @override
  _AuthScreenState createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> with TickerProviderStateMixin {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool isLoading = false;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Controladores para animaciones
  late AnimationController _logoAnimationController;
  late AnimationController _welcomeAnimationController;
  late Animation<double> _rotateYAnimation;
  late Animation<double> _welcomeSlideAnimation;
  late Animation<double> _welcomeOpacityAnimation;

  // Colores de la paleta extendida
  final Color mainGreenColor = Color(0xFF59A897);
  final Color darkGreenColor = Color(0xFF1D413E);
  final Color brightGreenColor = Color(0xFF46E0C9);
  final Color lightGreenColor = Color(0xFF7DECD0);
  final Color pureWhite = Colors.white;
  final Color offWhite = Color(0xFFF8F8F8);
  final Color pearlWhite = Color(0xFFE6EEF0);
  final Color backgroundBlack = Colors.black;

  // Variables para manejar el renderizado 3D
  List<Sphere3DPoint> spherePoints = [];

  @override
  void initState() {
    super.initState();

    // Generar puntos 3D para la geodésica
    _generateGeodesicPoints();

    // Controlador para la animación del logo (continua)
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Controlador para la animación de bienvenida
    _welcomeAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    // Animación de rotación (solo en el eje Y para mantener sensación 3D)
    _rotateYAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.linear),
    );

    // Animación para el mensaje de bienvenida
    _welcomeSlideAnimation = Tween<double>(begin: 50, end: 0).animate(
      CurvedAnimation(
        parent: _welcomeAnimationController,
        curve: Curves.easeOutQuad,
      ),
    );

    _welcomeOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _welcomeAnimationController,
        curve: Curves.easeIn,
      ),
    );

    // Iniciar animación de bienvenida
    _welcomeAnimationController.forward();
  }

  // Método para generar puntos de la geodésica en 3D
  void _generateGeodesicPoints() {
    spherePoints = [];
    // Subdivisiones para la geodésica
    int frequency = 2;
    double radius = 100;

    // Generar icosaedro base y subdividir
    _generateIcosahedron(radius);

    // Subdividir las caras para crear la geodésica
    for (int i = 0; i < frequency - 1; i++) {
      List<Sphere3DPoint> newPoints = List.from(spherePoints);

      for (int j = 0; j < spherePoints.length; j += 3) {
        if (j + 2 < spherePoints.length) {
          Sphere3DPoint p1 = spherePoints[j];
          Sphere3DPoint p2 = spherePoints[j + 1];
          Sphere3DPoint p3 = spherePoints[j + 2];

          // Crear punto medio entre p1 y p2
          Sphere3DPoint mid1 = Sphere3DPoint(
            (p1.x + p2.x) / 2,
            (p1.y + p2.y) / 2,
            (p1.z + p2.z) / 2,
          );
          mid1.normalize(radius);

          // Crear punto medio entre p2 y p3
          Sphere3DPoint mid2 = Sphere3DPoint(
            (p2.x + p3.x) / 2,
            (p2.y + p3.y) / 2,
            (p2.z + p3.z) / 2,
          );
          mid2.normalize(radius);

          // Crear punto medio entre p3 y p1
          Sphere3DPoint mid3 = Sphere3DPoint(
            (p3.x + p1.x) / 2,
            (p3.y + p1.y) / 2,
            (p3.z + p1.z) / 2,
          );
          mid3.normalize(radius);

          // Añadir los triángulos subdivididos
          newPoints.addAll([p1, mid1, mid3]);
          newPoints.addAll([p2, mid2, mid1]);
          newPoints.addAll([p3, mid3, mid2]);
          newPoints.addAll([mid1, mid2, mid3]);
        }
      }

      spherePoints = newPoints;
    }
  }

  // Generar icosaedro base (poliedro de 20 caras triangulares)
  void _generateIcosahedron(double radius) {
    // Factor para generar los vértices del icosaedro
    double t = (1.0 + math.sqrt(5.0)) / 2.0;

    // Normalizar para que todos los puntos estén a la misma distancia (radio)
    double normalizationFactor = radius / math.sqrt(1 + t * t);

    // Los 12 vértices del icosaedro
    List<Sphere3DPoint> vertices = [
      Sphere3DPoint(-1, t, 0)..normalize(normalizationFactor),
      Sphere3DPoint(1, t, 0)..normalize(normalizationFactor),
      Sphere3DPoint(-1, -t, 0)..normalize(normalizationFactor),
      Sphere3DPoint(1, -t, 0)..normalize(normalizationFactor),

      Sphere3DPoint(0, -1, t)..normalize(normalizationFactor),
      Sphere3DPoint(0, 1, t)..normalize(normalizationFactor),
      Sphere3DPoint(0, -1, -t)..normalize(normalizationFactor),
      Sphere3DPoint(0, 1, -t)..normalize(normalizationFactor),

      Sphere3DPoint(t, 0, -1)..normalize(normalizationFactor),
      Sphere3DPoint(t, 0, 1)..normalize(normalizationFactor),
      Sphere3DPoint(-t, 0, -1)..normalize(normalizationFactor),
      Sphere3DPoint(-t, 0, 1)..normalize(normalizationFactor),
    ];

    // Las 20 caras del icosaedro (definidas por tríadas de vértices)
    List<List<int>> faces = [
      [0, 11, 5],
      [0, 5, 1],
      [0, 1, 7],
      [0, 7, 10],
      [0, 10, 11],
      [1, 5, 9],
      [5, 11, 4],
      [11, 10, 2],
      [10, 7, 6],
      [7, 1, 8],
      [3, 9, 4],
      [3, 4, 2],
      [3, 2, 6],
      [3, 6, 8],
      [3, 8, 9],
      [4, 9, 5],
      [2, 4, 11],
      [6, 2, 10],
      [8, 6, 7],
      [9, 8, 1],
    ];

    // Añadir todos los triángulos a la lista de puntos
    for (List<int> face in faces) {
      spherePoints.add(vertices[face[0]]);
      spherePoints.add(vertices[face[1]]);
      spherePoints.add(vertices[face[2]]);
    }
  }

  @override
  void dispose() {
    _logoAnimationController.dispose();
    _welcomeAnimationController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void register() async {
    final result = await Navigator.pushNamed(context, '/register');
    if (result != null && result is Map<String, String>) {
      setState(() {
        emailController.text = result['email'] ?? '';
        passwordController.text = result['password'] ?? '';
      });
    }
  }

  void login() async {
    setState(() {
      isLoading = true;
    });

    final enteredEmail = emailController.text.trim();
    final enteredPassword = passwordController.text;

    if (enteredEmail.isEmpty || enteredPassword.isEmpty) {
      _showErrorDialog('Por favor, completa todos los campos.');
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      // 1. Autenticar con Firebase Authentication
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: enteredEmail,
        password: enteredPassword,
      );

      final firebaseUser = userCredential.user;
      
      if (firebaseUser == null) {
        _showErrorDialog('Error al autenticar. Por favor, intenta nuevamente.');
        setState(() {
          isLoading = false;
        });
        return;
      }

      // 2. Obtener información del usuario desde Firestore
      final userMap = await _dbHelper.getUserByUid(firebaseUser.uid);

      if (userMap != null) {
        // 3. Crear UserModel desde Firestore
        final user = UserModel.fromMap(userMap);

        if (context.mounted) {
          // 4. Establecer usuario en el Provider
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setCurrentUser(user);

          // 5. Obtener o crear chat para el usuario
          final chats = await _dbHelper.getChatsForUser(firebaseUser.uid);
          String chatId;

          if (chats.isEmpty) {
            final chatTitle = 'Nueva conversación';
            chatId = await _dbHelper.insertChat({
              'user_id': firebaseUser.uid, // Usar UID de Firebase
              'title': chatTitle,
            });
          } else {
            chatId = chats.first['id'] as String;
          }

          // 6. Establecer chat actual en el Provider
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setCurrentChatId(chatId);

          // 7. Navegar a la pantalla de chat
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen()),
          );
        }
      } else {
        // Usuario existe en Auth pero no en Firestore (caso raro)
        // Crear documento básico en Firestore
        final newUser = UserModel(
          id: firebaseUser.uid,
          fullName: firebaseUser.displayName ?? 'Usuario',
          email: firebaseUser.email ?? enteredEmail,
          password: '', // No guardamos contraseña en Firestore
        );

        // Guardar usuario en Firestore
        await _dbHelper.updateUser(firebaseUser.uid, newUser.toFirestore());

        if (context.mounted) {
          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setCurrentUser(newUser);

          // Crear primer chat
          final chatTitle = 'Nueva conversación';
          final chatId = await _dbHelper.insertChat({
            'user_id': firebaseUser.uid,
            'title': chatTitle,
          });

          Provider.of<UserProvider>(
            context,
            listen: false,
          ).setCurrentChatId(chatId);

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => ChatScreen()),
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No existe un usuario con ese correo electrónico.';
          break;
        case 'wrong-password':
          errorMessage = 'Contraseña incorrecta.';
          break;
        case 'invalid-email':
          errorMessage = 'El correo electrónico no es válido.';
          break;
        case 'user-disabled':
          errorMessage = 'Esta cuenta ha sido deshabilitada.';
          break;
        case 'too-many-requests':
          errorMessage = 'Demasiados intentos. Por favor, intenta más tarde.';
          break;
        default:
          errorMessage = 'Error al iniciar sesión: ${e.message}';
      }
      _showErrorDialog(errorMessage);
    } catch (e) {
      _showErrorDialog('Error al iniciar sesión: $e');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Color.lerp(darkGreenColor, backgroundBlack, 0.7),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: Color.lerp(lightGreenColor, pearlWhite, 0.3)!,
              width: 2,
            ),
          ),
          title: Text(
            'Error de inicio de sesión',
            style: GoogleFonts.montserrat(
              color: pearlWhite,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(message, style: GoogleFonts.openSans(color: offWhite)),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cerrar', style: TextStyle(color: brightGreenColor)),
            ),
          ],
        );
      },
    );
  }

  // Widget para dibujar la geodésica 3D con rotación
  Widget _buildGeodesicaLogo() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: brightGreenColor.withOpacity(0.3),
                blurRadius: 25,
                spreadRadius: 5,
              ),
            ],
          ),
          child: CustomPaint(
            size: Size(200, 200),
            painter: Geodesic3DPainter(
              mainColor: mainGreenColor,
              accentColor: brightGreenColor,
              highlightColor: pureWhite,
              spherePoints: spherePoints,
              rotationY: _rotateYAnimation.value,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundBlack,
      body: SafeArea(
        child: Center(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  backgroundBlack,
                  Color.lerp(backgroundBlack, darkGreenColor, 0.3) ??
                      backgroundBlack,
                ],
              ),
            ),
            child: Column(
              children: [
                // Espacio superior
                SizedBox(height: 40),

                // Logo con animación 3D
                _buildGeodesicaLogo(),

                SizedBox(height: 15),

                // Título con animación
                ShaderMask(
                  shaderCallback:
                      (bounds) => LinearGradient(
                        colors: [
                          mainGreenColor,
                          brightGreenColor,
                          pureWhite,
                          lightGreenColor,
                        ],
                        stops: [0.0, 0.4, 0.6, 1.0],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ).createShader(bounds),
                  child: Text(
                    'Geodesica',
                    style: GoogleFonts.montserrat(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),

                SizedBox(height: 10),

                // Mensaje de bienvenida animado
                AnimatedBuilder(
                  animation: _welcomeAnimationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _welcomeOpacityAnimation.value,
                      child: Transform.translate(
                        offset: Offset(0, _welcomeSlideAnimation.value),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 30,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            gradient: LinearGradient(
                              colors: [
                                pureWhite.withOpacity(0.1),
                                pureWhite.withOpacity(0.3),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Text(
                            '¡Bienvenido/a de nuevo!',
                            style: GoogleFonts.openSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: pureWhite,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Espacio para el formulario
                SizedBox(height: 30),

                // Formulario con diseño mejorado
                Expanded(
                  child: Container(
                    width: 350,
                    margin: EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          mainGreenColor.withOpacity(0.8),
                          Color.lerp(mainGreenColor, darkGreenColor, 0.3)!,
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(50),
                        topRight: Radius.circular(50),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: pureWhite.withOpacity(0.2),
                          blurRadius: 20,
                          spreadRadius: 1,
                          offset: Offset(0, -5),
                        ),
                        BoxShadow(
                          color: brightGreenColor.withOpacity(0.3),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: Offset(0, -15),
                        ),
                      ],
                      border: Border.all(
                        color: pureWhite.withOpacity(0.2),
                        width: 1.5,
                      ),
                    ),
                    padding: EdgeInsets.fromLTRB(24, 35, 24, 24),
                    child: SingleChildScrollView(
                      physics: BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Inicio de sesión',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.montserrat(
                              fontSize: 35,
                              fontWeight: FontWeight.bold,
                              color: pureWhite,
                              shadows: [
                                Shadow(
                                  color: Colors.black.withOpacity(0.3),
                                  offset: Offset(2, 2),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Accede a tu cuenta',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.openSans(
                              fontSize: 16,
                              color: pureWhite.withOpacity(0.9),
                            ),
                          ),
                          SizedBox(height: 40),

                          // Campo de correo
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: 'CORREO',
                                labelStyle: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: pureWhite.withOpacity(0.15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: pureWhite,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Container(
                                  margin: EdgeInsets.only(left: 15, right: 10),
                                  child: Icon(
                                    Icons.email_outlined,
                                    color: pureWhite,
                                    size: 22,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 22,
                                  horizontal: 15,
                                ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                              ),
                              style: TextStyle(color: pureWhite, fontSize: 16),
                              keyboardType: TextInputType.emailAddress,
                            ),
                          ),

                          SizedBox(height: 20),

                          // Campo de contraseña
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 10,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: passwordController,
                              obscureText: true,
                              decoration: InputDecoration(
                                labelText: 'CONTRASEÑA',
                                labelStyle: TextStyle(
                                  color: pureWhite,
                                  fontWeight: FontWeight.w600,
                                ),
                                filled: true,
                                fillColor: pureWhite.withOpacity(0.15),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide.none,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: pureWhite,
                                    width: 2,
                                  ),
                                ),
                                prefixIcon: Container(
                                  margin: EdgeInsets.only(left: 15, right: 10),
                                  child: Icon(
                                    Icons.lock_outline,
                                    color: pureWhite,
                                    size: 22,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 22,
                                  horizontal: 15,
                                ),
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.never,
                              ),
                              style: TextStyle(color: pureWhite, fontSize: 16),
                            ),
                          ),

                          SizedBox(height: 35),

                          // Botón de iniciar sesión
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              gradient: LinearGradient(
                                colors: [brightGreenColor, lightGreenColor],
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: brightGreenColor.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: -5,
                                  offset: Offset(0, 8),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child:
                                  isLoading
                                      ? CircularProgressIndicator(
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              pureWhite,
                                            ),
                                      )
                                      : Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            'INICIAR SESIÓN',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: backgroundBlack,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                          SizedBox(width: 8),
                                          Icon(
                                            Icons.arrow_forward_rounded,
                                            color: backgroundBlack,
                                          ),
                                        ],
                                      ),
                            ),
                          ),

                          SizedBox(height: 20),

                          // Botón de registro
                          Container(
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: pureWhite.withOpacity(0.8),
                                width: 1.5,
                              ),
                            ),
                            child: ElevatedButton(
                              onPressed: isLoading ? null : register,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 0,
                                padding: EdgeInsets.zero,
                              ),
                              child: Text(
                                'REGISTRARSE',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: pureWhite,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Clase para puntos en 3D
class Sphere3DPoint {
  double x, y, z;

  Sphere3DPoint(this.x, this.y, this.z);

  // Normalizar el punto a una distancia específica desde el origen
  void normalize(double radius) {
    double length = math.sqrt(x * x + y * y + z * z);
    if (length > 0) {
      x = x / length * radius;
      y = y / length * radius;
      z = z / length * radius;
    }
  }

  // Proyectar punto 3D a 2D con perspectiva
  Offset project(Size size, double rotationY, {double perspective = 800}) {
    // Aplicar rotación en eje Y
    double cosY = math.cos(rotationY);
    double sinY = math.sin(rotationY);

    double rotatedX = x * cosY - z * sinY;
    double rotatedZ = z * cosY + x * sinY;

    // Aplicar perspectiva
    double scale = perspective / (perspective + rotatedZ);
    double projectX = rotatedX * scale + size.width / 2;
    double projectY = y * scale + size.height / 2;

    return Offset(projectX, projectY);
  }

  // Calcular la visibilidad basada en Z (para ocultar líneas traseras)
  double calculateVisibility(double rotationY) {
    double cosY = math.cos(rotationY);
    double sinY = math.sin(rotationY);
    double rotatedZ = z * cosY + x * sinY;

    // Normalizar z entre -1 y 1, luego mapear a visibilidad entre 0.1 y 1.0
    return (rotatedZ / 100 + 1) / 2 * 0.9 + 0.1;
  }
}

// Clase para dibujar la geodésica 3D
class Geodesic3DPainter extends CustomPainter {
  final Color mainColor;
  final Color accentColor;
  final Color highlightColor;
  final List<Sphere3DPoint> spherePoints;
  final double rotationY;

  Geodesic3DPainter({
    required this.mainColor,
    required this.accentColor,
    required this.highlightColor,
    required this.spherePoints,
    required this.rotationY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    // Dibujar esfera base (muy sutil, casi transparente)
    final spherePaint =
        Paint()
          ..color = mainColor.withOpacity(0.1)
          ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, spherePaint);

    // Dibujar las aristas (líneas) del modelo 3D
    for (int i = 0; i < spherePoints.length; i += 3) {
      if (i + 2 < spherePoints.length) {
        Sphere3DPoint p1 = spherePoints[i];
        Sphere3DPoint p2 = spherePoints[i + 1];
        Sphere3DPoint p3 = spherePoints[i + 2];

        // Proyectar puntos 3D a 2D
        Offset p1Proj = p1.project(size, rotationY);
        Offset p2Proj = p2.project(size, rotationY);
        Offset p3Proj = p3.project(size, rotationY);

        // Calcular visibilidad basada en la coordenada Z
        double visibility1 = p1.calculateVisibility(rotationY);

        // Pintar líneas con opacidad basada en la coordenada Z
        Paint linePaint =
            Paint()
              ..color = highlightColor.withOpacity(visibility1 * 0.8)
              ..strokeWidth = 1.2
              ..style = PaintingStyle.stroke
              ..strokeCap = StrokeCap.round;

        // Dibujar el triángulo
        Path trianglePath = Path();
        trianglePath.moveTo(p1Proj.dx, p1Proj.dy);
        trianglePath.lineTo(p2Proj.dx, p2Proj.dy);
        trianglePath.lineTo(p3Proj.dx, p3Proj.dy);
        trianglePath.close();

        // Dibujar líneas
        canvas.drawPath(trianglePath, linePaint);

        // Opcionalmente, pintar nodos en las intersecciones
        if (math.Random().nextDouble() < 0.3) {
          // Solo dibujar algunos nodos para un efecto más disperso
          Paint nodePaint =
              Paint()
                ..color = accentColor.withOpacity(visibility1 * 0.9)
                ..style = PaintingStyle.fill;

          double nodeSize = math.Random().nextDouble() * 2.5 + 1.0;
          canvas.drawCircle(p1Proj, nodeSize, nodePaint);
          canvas.drawCircle(p2Proj, nodeSize, nodePaint);
          canvas.drawCircle(p3Proj, nodeSize, nodePaint);
        }
      }
    }

    // Dibujar efecto de brillo en el centro
    final glowPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              highlightColor.withOpacity(0.7),
              highlightColor.withOpacity(0.1),
              highlightColor.withOpacity(0.0),
            ],
            stops: [0.0, 0.3, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: radius * 0.8));

    canvas.drawCircle(center, radius * 0.8, glowPaint);
  }

  @override
  bool shouldRepaint(Geodesic3DPainter oldDelegate) {
    return oldDelegate.rotationY != rotationY;
  }
}