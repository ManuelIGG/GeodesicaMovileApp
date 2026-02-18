import 'package:flutter/material.dart';
import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'package:firebase_auth/firebase_auth.dart';

class RegisterScreen extends StatefulWidget {
  @override
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  // Controllers
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();
  TextEditingController birthDateController = TextEditingController();
  TextEditingController documentController = TextEditingController();

  // Animation controllers
  late AnimationController _formAnimationController;
  late AnimationController _backgroundAnimationController;
  late AnimationController _logoAnimationController;

  // Animations
  late Animation<double> _headerSlideAnimation;
  late Animation<double> _headerOpacityAnimation;
  late List<Animation<double>> _formFieldAnimations;
  late Animation<double> _rotateAnimation;

  // Background animation particles
  List<Particle> particles = [];

  // Colors matching the app theme
  final Color mainGreenColor = Color(0xFF59A897);
  final Color darkGreenColor = Color(0xFF1D413E);
  final Color brightGreenColor = Color(0xFF46E0C9);
  final Color lightGreenColor = Color(0xFF7DECD0);
  final Color pureWhite = Colors.white;
  final Color offWhite = Color(0xFFF8F8F8);
  final Color pearlWhite = Color(0xFFE6EEF0);
  final Color backgroundBlack = Colors.black;

  // Other variables
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool isLoading = false;
  DateTime? selectedDate;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  final int _numFormFields = 6;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();

    // Generate particles for background animation
    _generateParticles();

    // Form animation controller
    _formAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Background animation controller (continuous)
    _backgroundAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();

    // Logo animation controller
    _logoAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat();

    // Header animations
    _headerSlideAnimation = Tween<double>(begin: -50, end: 0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Interval(0.0, 0.4, curve: Curves.easeOutQuart),
      ),
    );

    _headerOpacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _formAnimationController,
        curve: Interval(0.0, 0.4, curve: Curves.easeIn),
      ),
    );

    // Form field animations (staggered)
    _formFieldAnimations = List.generate(_numFormFields, (index) {
      double startInterval = 0.2 + (index * 0.1);
      double endInterval = startInterval + 0.2;
      return Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(
          parent: _formAnimationController,
          curve: Interval(
            startInterval.clamp(0.0, 1.0),
            endInterval.clamp(0.0, 1.0),
            curve: Curves.easeOut,
          ),
        ),
      );
    });

    // Rotation animation
    _rotateAnimation = Tween<double>(begin: 0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _logoAnimationController, curve: Curves.linear),
    );

    // Start animations
    _formAnimationController.forward();
  }

  void _generateParticles() {
    final random = math.Random();

    // Create particles for background effect
    for (int i = 0; i < 40; i++) {
      particles.add(
        Particle(
          x: random.nextDouble() * 400,
          y: random.nextDouble() * 800,
          size: random.nextDouble() * 4 + 1,
          speed: random.nextDouble() * 0.5 + 0.2,
          opacity: random.nextDouble() * 0.6 + 0.2,
        ),
      );
    }
  }

  @override
  void dispose() {
    _formAnimationController.dispose();
    _backgroundAnimationController.dispose();
    _logoAnimationController.dispose();
    fullNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    birthDateController.dispose();
    documentController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? DateTime(DateTime.now().year - 20),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: ColorScheme.dark(
              primary: brightGreenColor,
              onPrimary: backgroundBlack,
              surface: darkGreenColor,
              onSurface: pureWhite,
            ),
            dialogBackgroundColor: Color.lerp(
              backgroundBlack,
              darkGreenColor,
              0.3,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != selectedDate) {
      setState(() {
        selectedDate = picked;
        birthDateController.text =
            "${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}";
      });
    }
  }

  
  Future<void> _register() async {
  if (!_formKey.currentState!.validate()) {
    return;
  }

  setState(() {
    isLoading = true;
  });

  try {
    // 1. Preparar datos para el usuario
    Map<String, dynamic> userData = {
      'fullName': fullNameController.text.trim(),
      'email': emailController.text.trim(),
      'password': passwordController.text,
    };

    // Agregar campos opcionales si están presentes
    if (birthDateController.text.isNotEmpty) {
      userData['birthDate'] = birthDateController.text;
    }
    if (documentController.text.isNotEmpty) {
      userData['document'] = documentController.text;
    }

    // 2. Crear usuario usando DatabaseHelper (que maneja Firebase Auth + Firestore)
     await _dbHelper.insertUser(userData);

    // 3. Animate out before popping
    await _formAnimationController.reverse();

    // 4. Return data for auto-login
    Navigator.pop(context, {
      'email': emailController.text.trim(),
      'password': passwordController.text,
    });
  } on FirebaseAuthException catch (e) {
    String errorMessage;
    switch (e.code) {
      case 'email-already-in-use':
        errorMessage = 'Este correo electrónico ya está registrado.';
        break;
      case 'invalid-email':
        errorMessage = 'El correo electrónico no es válido.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'El registro con email/contraseña no está habilitado.';
        break;
      case 'weak-password':
        errorMessage = 'La contraseña es demasiado débil.';
        break;
      default:
        errorMessage = 'Error al registrar: ${e.message}';
    }
    _showErrorDialog(errorMessage);
  } catch (e) {
    _showErrorDialog('Error al registrar: $e');
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
            'Error de registro',
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

  // Custom logo widget
  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoAnimationController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                brightGreenColor.withOpacity(0.8),
                mainGreenColor.withOpacity(0.6),
                darkGreenColor.withOpacity(0.4),
              ],
              stops: [0.2, 0.6, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: brightGreenColor.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CustomPaint(
            size: Size(80, 80),
            painter: LogoPainter(
              mainColor: pureWhite,
              accentColor: brightGreenColor,
              rotation: _rotateAnimation.value,
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
      body: Stack(
        children: [
          // Animated background
          AnimatedBuilder(
            animation: _backgroundAnimationController,
            builder: (context, child) {
              return CustomPaint(
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                ),
                painter: ParticlePainter(
                  particles: particles,
                  animation: _backgroundAnimationController,
                  mainColor: mainGreenColor,
                  accentColor: brightGreenColor,
                ),
              );
            },
          ),

          // Gradient overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  backgroundBlack.withOpacity(0.9),
                  Color.lerp(
                    backgroundBlack,
                    darkGreenColor,
                    0.15,
                  )!.withOpacity(0.9),
                  Color.lerp(
                    backgroundBlack,
                    darkGreenColor,
                    0.3,
                  )!.withOpacity(0.9),
                ],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: BouncingScrollPhysics(),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Column(
                    children: [
                      // Header with animations
                      AnimatedBuilder(
                        animation: _formAnimationController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _headerSlideAnimation.value),
                            child: Opacity(
                              opacity: _headerOpacityAnimation.value,
                              child: Column(
                                children: [
                                  _buildLogo(),
                                  SizedBox(height: 20),
                                  // Title with gradient
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
                                      'Crear Cuenta',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 30,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                  // Subtitle
                                  Text(
                                    'Únete a la comunidad Geodesica',
                                    style: GoogleFonts.openSans(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                      color: offWhite.withOpacity(0.9),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),

                      SizedBox(height: 30),

                      // Registration form
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              mainGreenColor.withOpacity(0.8),
                              Color.lerp(mainGreenColor, darkGreenColor, 0.3)!,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: pureWhite.withOpacity(0.1),
                              blurRadius: 20,
                              spreadRadius: 1,
                              offset: Offset(0, -5),
                            ),
                            BoxShadow(
                              color: brightGreenColor.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: -5,
                              offset: Offset(0, 10),
                            ),
                          ],
                          border: Border.all(
                            color: pureWhite.withOpacity(0.2),
                            width: 1.5,
                          ),
                        ),
                        padding: EdgeInsets.all(25),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Full Name Field
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _formFieldAnimations[0].value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        20 *
                                            (1 - _formFieldAnimations[0].value),
                                      ),
                                      child: _buildTextField(
                                        controller: fullNameController,
                                        label: 'NOMBRE COMPLETO',
                                        icon: Icons.person_outline,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Ingresa tu nombre completo';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20),

                              // Email Field
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _formFieldAnimations[1].value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        20 *
                                            (1 - _formFieldAnimations[1].value),
                                      ),
                                      child: _buildTextField(
                                        controller: emailController,
                                        label: 'CORREO ELECTRÓNICO',
                                        icon: Icons.email_outlined,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Ingresa tu correo electrónico';
                                          }
                                          if (!RegExp(
                                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                                          ).hasMatch(value)) {
                                            return 'Ingresa un correo válido';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20),

                              // Password Field
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _formFieldAnimations[2].value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        20 *
                                            (1 - _formFieldAnimations[2].value),
                                      ),
                                      child: _buildTextField(
                                        controller: passwordController,
                                        label: 'CONTRASEÑA',
                                        icon: Icons.lock_outline,
                                        obscureText: _obscurePassword,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Ingresa una contraseña';
                                          }
                                          if (value.length < 6) {
                                            return 'La contraseña debe tener al menos 6 caracteres';
                                          }
                                          return null;
                                        },
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: pureWhite.withOpacity(0.7),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword =
                                                  !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20),

                              // Confirm Password Field
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _formFieldAnimations[3].value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        20 *
                                            (1 - _formFieldAnimations[3].value),
                                      ),
                                      child: _buildTextField(
                                        controller: confirmPasswordController,
                                        label: 'CONFIRMAR CONTRASEÑA',
                                        icon: Icons.lock_outline,
                                        obscureText: _obscureConfirmPassword,
                                        validator: (value) {
                                          if (value == null || value.isEmpty) {
                                            return 'Confirma tu contraseña';
                                          }
                                          if (value !=
                                              passwordController.text) {
                                            return 'Las contraseñas no coinciden';
                                          }
                                          return null;
                                        },
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: pureWhite.withOpacity(0.7),
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscureConfirmPassword =
                                                  !_obscureConfirmPassword;
                                            });
                                          },
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20),

                              // Birth Date Field
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _formFieldAnimations[4].value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        20 *
                                            (1 - _formFieldAnimations[4].value),
                                      ),
                                      child: GestureDetector(
                                        onTap: () => _selectDate(context),
                                        child: AbsorbPointer(
                                          child: TextFormField(
                                            controller: birthDateController,
                                            decoration: InputDecoration(
                                              labelText:
                                                  'FECHA DE NACIMIENTO (opcional)',
                                              labelStyle: TextStyle(
                                                color: pureWhite.withOpacity(
                                                  0.9,
                                                ),
                                                fontWeight: FontWeight.w500,
                                                fontSize: 12,
                                              ),
                                              filled: true,
                                              fillColor: pureWhite.withOpacity(
                                                0.08,
                                              ),
                                              enabledBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: BorderSide(
                                                  color: pureWhite.withOpacity(
                                                    0.3,
                                                  ),
                                                  width: 1,
                                                ),
                                              ),
                                              focusedBorder: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(15),
                                                borderSide: BorderSide(
                                                  color: pureWhite,
                                                  width: 1.5,
                                                ),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 20,
                                                    vertical: 16,
                                                  ),
                                              prefixIcon: Icon(
                                                Icons.calendar_today_outlined,
                                                color: pureWhite.withOpacity(
                                                  0.9,
                                                ),
                                              ),
                                            ),
                                            style: GoogleFonts.openSans(
                                              color: pureWhite,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20),

                              // Document Field
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  return Opacity(
                                    opacity: _formFieldAnimations[5].value,
                                    child: Transform.translate(
                                      offset: Offset(
                                        0,
                                        20 *
                                            (1 - _formFieldAnimations[5].value),
                                      ),
                                      child: _buildTextField(
                                        controller: documentController,
                                        label: 'DOCUMENTO (opcional)',
                                        icon: Icons.credit_card_outlined,
                                        keyboardType: TextInputType.number,
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 35),

                              // Register Button
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  double opacity = 0;
                                  double translateY = 20;

                                  // Ensure the button appears after all fields
                                  if (_formFieldAnimations.last.value > 0.5) {
                                    opacity =
                                        (_formFieldAnimations.last.value -
                                            0.5) *
                                        2;
                                    translateY = 20 * (1 - opacity);
                                  }

                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
                                      child: Container(
                                        height: 60,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              brightGreenColor,
                                              lightGreenColor,
                                            ],
                                            begin: Alignment.centerLeft,
                                            end: Alignment.centerRight,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: brightGreenColor
                                                  .withOpacity(0.5),
                                              blurRadius: 15,
                                              spreadRadius: -5,
                                              offset: Offset(0, 8),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed:
                                              isLoading ? null : _register,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(20),
                                            ),
                                            elevation: 0,
                                            padding: EdgeInsets.zero,
                                          ),
                                          child:
                                              isLoading
                                                  ? CircularProgressIndicator(
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(pureWhite),
                                                  )
                                                  : Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment
                                                            .center,
                                                    children: [
                                                      Text(
                                                        'REGISTRARSE',
                                                        style:
                                                            GoogleFonts.montserrat(
                                                              fontSize: 16,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              color:
                                                                  backgroundBlack,
                                                              letterSpacing:
                                                                  1.2,
                                                            ),
                                                      ),
                                                      SizedBox(width: 8),
                                                      Icon(
                                                        Icons
                                                            .arrow_forward_rounded,
                                                        color: backgroundBlack,
                                                      ),
                                                    ],
                                                  ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                              SizedBox(height: 20),

                              // Login Link
                              AnimatedBuilder(
                                animation: _formAnimationController,
                                builder: (context, child) {
                                  double opacity = 0;
                                  double translateY = 20;

                                  // Ensure the link appears after the button
                                  if (_formFieldAnimations.last.value > 0.7) {
                                    opacity =
                                        (_formFieldAnimations.last.value -
                                            0.7) *
                                        3.3;
                                    translateY = 20 * (1 - opacity);
                                  }

                                  return Opacity(
                                    opacity: opacity,
                                    child: Transform.translate(
                                      offset: Offset(0, translateY),
                                      child: GestureDetector(
                                        onTap: () async {
                                          await _formAnimationController
                                              .reverse();
                                          Navigator.pop(context);
                                        },
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.arrow_back_ios,
                                              size: 14,
                                              color: pureWhite.withOpacity(0.9),
                                            ),
                                            SizedBox(width: 5),
                                            Text(
                                              '¿Ya tienes cuenta? Inicia sesión',
                                              style: GoogleFonts.openSans(
                                                fontSize: 14,
                                                color: pureWhite.withOpacity(
                                                  0.9,
                                                ),
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build consistent text fields
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: GoogleFonts.openSans(color: pureWhite, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: pureWhite.withOpacity(0.9),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        filled: true,
        fillColor: pureWhite.withOpacity(0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: pureWhite.withOpacity(0.3), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: pureWhite, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
        ),
        prefixIcon: Icon(icon, color: pureWhite.withOpacity(0.9)),
        suffixIcon: suffixIcon,
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }
}

// Particle class for background animation
class Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}

// Background particle painter - Complete implementation
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final Animation<double> animation;
  final Color mainColor;
  final Color accentColor;

  ParticlePainter({
    required this.particles,
    required this.animation,
    required this.mainColor,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      // Update particle position based on animation
      double yPos =
          (particle.y + (animation.value * 100 * particle.speed)) % size.height;

      // Create gradient for particles
      final paint =
          Paint()
            ..shader = RadialGradient(
              colors: [
                accentColor.withOpacity(particle.opacity),
                mainColor.withOpacity(particle.opacity * 0.6),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(particle.x, yPos),
                radius: particle.size * 2,
              ),
            );

      // Draw particle
      canvas.drawCircle(Offset(particle.x, yPos), particle.size, paint);

      // Connect nearby particles with lines
      _connectParticles(canvas, particle, Offset(particle.x, yPos), size);
    }
  }

  void _connectParticles(
    Canvas canvas,
    Particle mainParticle,
    Offset mainPos,
    Size size,
  ) {
    final maxDistance = size.width * 0.15; // Max distance for connection

    for (var otherParticle in particles) {
      if (mainParticle == otherParticle) continue;

      double otherYPos =
          (otherParticle.y + (animation.value * 100 * otherParticle.speed)) %
          size.height;
      Offset otherPos = Offset(otherParticle.x, otherYPos);

      double distance = (mainPos - otherPos).distance;

      if (distance < maxDistance) {
        // Create opacity based on distance
        double lineOpacity =
            (1 - (distance / maxDistance)) *
            0.3 *
            mainParticle.opacity *
            otherParticle.opacity;

        // Draw connection line
        canvas.drawLine(
          mainPos,
          otherPos,
          Paint()
            ..color = accentColor.withOpacity(lineOpacity)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

// Custom logo painter for the app
class LogoPainter extends CustomPainter {
  final Color mainColor;
  final Color accentColor;
  final double rotation;

  LogoPainter({
    required this.mainColor,
    required this.accentColor,
    required this.rotation,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Save canvas state to apply rotation
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotation);
    canvas.translate(-center.dx, -center.dy);

    // Create paints
    final outlinePaint =
        Paint()
          ..color = mainColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round;

    final fillPaint =
        Paint()
          ..shader = RadialGradient(
            colors: [
              accentColor.withOpacity(0.9),
              accentColor.withOpacity(0.3),
            ],
          ).createShader(Rect.fromCircle(center: center, radius: radius));

    // Draw outer ring
    canvas.drawCircle(center, radius * 0.9, outlinePaint);

    // Draw inner elements - simplified geodesic dome shape
    final path = Path();

    // Create a pentagon shape
    for (int i = 0; i < 5; i++) {
      double angle = math.pi * 2 * i / 5 - math.pi / 2;
      double x = center.dx + math.cos(angle) * radius * 0.6;
      double y = center.dy + math.sin(angle) * radius * 0.6;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();

    // Draw inner pentagon
    canvas.drawPath(path, outlinePaint);

    // Draw connecting lines for geodesic effect
    final innerCenter = center;
    final innerRadius = radius * 0.3;

    for (int i = 0; i < 5; i++) {
      double angle = math.pi * 2 * i / 5 - math.pi / 2;
      double outerX = center.dx + math.cos(angle) * radius * 0.6;
      double outerY = center.dy + math.sin(angle) * radius * 0.6;

      canvas.drawLine(
        Offset(outerX, outerY),
        innerCenter,
        outlinePaint..strokeWidth = 1.5,
      );
    }

    // Draw inner circle
    canvas.drawCircle(innerCenter, innerRadius, fillPaint);
    canvas.drawCircle(
      innerCenter,
      innerRadius,
      outlinePaint..strokeWidth = 1.5,
    );

    // Restore canvas to original state
    canvas.restore();
  }

  @override
  bool shouldRepaint(LogoPainter oldDelegate) =>
      oldDelegate.rotation != rotation ||
      oldDelegate.mainColor != mainColor ||
      oldDelegate.accentColor != accentColor;
}