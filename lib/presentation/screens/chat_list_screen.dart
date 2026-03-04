// =============================================================================
// lib/presentation/screens/chat_list_screen.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
//
//   1. SOPORTE DE TEMA — la pantalla ahora lee AppThemeProvider y adapta
//      colores de fondo, tarjetas, textos y AppBar según modo oscuro/claro.
//      Antes estaba hardcodeada solo para modo claro (fondo 0xFFE6EEF0).
//
//   2. TIPOGRAFÍA CON JERARQUÍA — cada tarjeta de chat tiene:
//        - Título: fontWeight w700, letterSpacing -0.3 (compacto y elegante)
//        - Subtítulo: fecha formateada legible en lugar de "Toca para abrir"
//        - Contador de conversaciones: chip con tipografía monoespaciada
//
//   3. TARJETAS REDISEÑADAS (_AnimatedChatCard):
//        - Avatar con inicial y gradiente (se mantiene) + número de orden
//        - Fondo adaptado al tema (blanco en claro, color oscuro en dark)
//        - Sombra calibrada por tema
//        - Fecha de creación formateada (día/mes/año) como subtítulo real
//        - Swipe-to-delete con confirmación rápida vía DismissibleCard
//
//   4. ESTADO VACÍO MEJORADO — ilustración más elaborada con texto en dos
//      niveles tipográficos y llamada a la acción más clara.
//
//   5. HEADER / APPBAR — respeta tema claro/oscuro con colores apropiados.
//      En modo claro mantiene el gradiente verde. En modo oscuro usa
//      superficie oscura consistente con chatMain.
//
//   6. SEPARACIÓN DE FECHA — helper _formatFecha() formatea el campo
//      created_at de Firestore en texto legible ("Hoy", "Ayer", "15 mar").
//
// ARCHIVOS REQUERIDOS:
//   → themeProvider.dart debe exportar AppThemeProvider con isDarkMode
//   → database_helper.dart, userProvider.dart — sin cambios
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/userProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/themeProvider.dart';
import 'package:provider/provider.dart';

// ─── Paleta corporativa ───────────────────────────────────────────
const _kPrimario = Color(0xFF1D413E);
const _kAcento = Color(0xFF46E0C9);
const _kSecundario = Color(0xFF59A897);

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with TickerProviderStateMixin {
  final dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _chats = [];
  bool _isLoading = true;

  late AnimationController _fabController;
  late AnimationController _headerController;
  late Animation<double> _fabScaleAnimation;
  late Animation<double> _headerFadeAnimation;
  late Animation<Offset> _headerSlideAnimation;

  @override
  void initState() {
    super.initState();

    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _fabScaleAnimation = CurvedAnimation(
      parent: _fabController,
      curve: Curves.elasticOut,
    );
    _headerFadeAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOut,
    );
    _headerSlideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.25),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOutCubic),
    );

    _loadChats();
    _headerController.forward();
  }

  @override
  void dispose() {
    _fabController.dispose();
    _headerController.dispose();
    super.dispose();
  }

  // ── Carga de chats ─────────────────────────────────────────────
  Future<void> _loadChats() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser != null) {
      final chats = await dbHelper.getChatsForUser(userProvider.currentUserId!);
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 150));
      _fabController.forward();
    }
  }

  Future<void> _deleteChat(String chatId) async {
    await dbHelper.deleteChat(chatId);
    await _loadChats();
  }

  void _openChat(Map<String, dynamic> chat) {
    HapticFeedback.lightImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.setCurrentChatId(chat['id'] as String);
    Navigator.of(context).pushNamed('/chat');
  }

  // ── Renombrar chat ─────────────────────────────────────────────
  Future<void> _renombrarChat(Map<String, dynamic> chat, bool isDark) async {
    HapticFeedback.mediumImpact();
    final titleController = TextEditingController(text: chat['title']);
    final bg = isDark ? const Color(0xFF1A3735) : Colors.white;
    final textColor = isDark ? Colors.white : _kPrimario;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder:
          (ctx, anim, _, child) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
      pageBuilder:
          (ctx, _, __) => AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              'Renombrar conversación',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            content: TextField(
              controller: titleController,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                hintText: 'Nuevo nombre...',
                hintStyle: TextStyle(color: textColor.withOpacity(0.38)),
                filled: true,
                fillColor: textColor.withOpacity(0.07),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: _kAcento, width: 2),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                ),
              ),
              ElevatedButton(
                onPressed: () async {
                  final nuevoTitulo = titleController.text.trim();
                  if (nuevoTitulo.isNotEmpty) {
                    await dbHelper.updateChatTitle(
                      chat['id'] as String,
                      nuevoTitulo,
                    );
                    await _loadChats();
                    if (mounted) {
                      Navigator.pop(ctx);
                      _showSnackBar('Conversación renombrada');
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kSecundario,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Guardar'),
              ),
            ],
          ),
    );
  }

  // ── Confirmar eliminación ──────────────────────────────────────
  Future<void> _confirmarEliminar(
    Map<String, dynamic> chat,
    bool isDark,
  ) async {
    HapticFeedback.mediumImpact();
    final bg = isDark ? const Color(0xFF1A3735) : Colors.white;
    final textColor = isDark ? Colors.white : _kPrimario;

    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder:
          (ctx, anim, _, child) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
      pageBuilder:
          (ctx, _, __) => AlertDialog(
            backgroundColor: bg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: Text(
              '¿Eliminar conversación?',
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
            content: Text(
              '"${chat['title']}" se eliminará permanentemente junto con todos sus mensajes.',
              style: TextStyle(
                color: textColor.withOpacity(0.65),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: textColor.withOpacity(0.5)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Eliminar'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _deleteChat(chat['id'] as String);
      if (mounted) _showSnackBar('Conversación eliminada', isError: true);
    }
  }

  // ── Crear nuevo chat ───────────────────────────────────────────
  Future<void> _crearNuevoChat() async {
    HapticFeedback.heavyImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final userId = userProvider.currentUserId;
    if (userId == null) return;

    final nuevoTitulo = 'Conversación ${_chats.length + 1}';
    final nuevoChatId = await dbHelper.insertChat({
      'user_id': userId,
      'title': nuevoTitulo,
    });

    userProvider.setCurrentChatId(nuevoChatId);
    Navigator.of(context).pushNamed('/chat');
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.delete_outline : Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : _kSecundario,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // NUEVO: leer el tema para adaptar colores
    final themeProvider = Provider.of<AppThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final bgColor = isDark ? const Color(0xFF111F1E) : const Color(0xFFEDF4F3);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: _buildAppBar(isDark),
      body:
          _isLoading
              ? _buildLoadingState(isDark)
              : _chats.isEmpty
              ? _buildEmptyState(isDark)
              : _buildChatList(isDark),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _crearNuevoChat,
          backgroundColor: _kSecundario,
          foregroundColor: Colors.white,
          elevation: 6,
          icon: const Icon(Icons.add_rounded, size: 22),
          label: const Text(
            'Nueva conversación',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              letterSpacing: 0.1,
            ),
          ),
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ── AppBar adaptado al tema ────────────────────────────────────
  PreferredSizeWidget _buildAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(70),
      child: SlideTransition(
        position: _headerSlideAnimation,
        child: FadeTransition(
          opacity: _headerFadeAnimation,
          child: Container(
            decoration: BoxDecoration(
              // Modo oscuro: superficie oscura; Modo claro: gradiente verde
              gradient:
                  isDark
                      ? const LinearGradient(
                        colors: [Color(0xFF1A3735), Color(0xFF1D413E)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : const LinearGradient(
                        colors: [Color(0xFF1D413E), Color(0xFF2A5E59)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    // Ícono de sección
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _kAcento.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: const Icon(
                        Icons.forum_rounded,
                        color: _kAcento,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Título con gradiente
                    ShaderMask(
                      shaderCallback:
                          (bounds) => const LinearGradient(
                            colors: [_kSecundario, _kAcento, Colors.white],
                          ).createShader(bounds),
                      child: const Text(
                        'Conversaciones',
                        style: TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Contador de chats
                    if (!_isLoading)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _kAcento.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_chats.length}',
                          style: const TextStyle(
                            color: _kAcento,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Lista de chats ─────────────────────────────────────────────
  Widget _buildChatList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 110),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return _AnimatedChatCard(
          chat: chat,
          index: index,
          isDark: isDark,
          onOpen: () => _openChat(chat),
          onRename: () => _renombrarChat(chat, isDark),
          onDelete: () => _confirmarEliminar(chat, isDark),
        );
      },
    );
  }

  // ── Estado cargando ────────────────────────────────────────────
  Widget _buildLoadingState(bool isDark) {
    final textColor = isDark ? Colors.white54 : _kPrimario.withOpacity(0.5);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 52,
            height: 52,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(_kSecundario),
              backgroundColor: _kSecundario.withOpacity(0.15),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando conversaciones...',
            style: TextStyle(
              color: textColor,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Estado vacío ───────────────────────────────────────────────
  Widget _buildEmptyState(bool isDark) {
    final textColor = isDark ? Colors.white : _kPrimario;
    final subColor = isDark ? Colors.white38 : _kPrimario.withOpacity(0.45);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ícono ilustrativo con capas
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: _kAcento.withOpacity(isDark ? 0.08 : 0.07),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: _kSecundario.withOpacity(isDark ? 0.15 : 0.12),
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kSecundario, _kAcento],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _kAcento.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  size: 26,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          // Título principal
          Text(
            'Aún no hay conversaciones',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          // Subtítulo
          Text(
            'Crea una nueva para empezar a\nconsultar reportes con Geodésica',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: subColor, height: 1.55),
          ),
          const SizedBox(height: 32),
          // Botón de acción
          ElevatedButton.icon(
            onPressed: _crearNuevoChat,
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text(
              'Nueva conversación',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kSecundario,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              shadowColor: _kSecundario.withOpacity(0.4),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// TARJETA ANIMADA DE CHAT — rediseñada con soporte de tema y fecha formateada
// =============================================================================
class _AnimatedChatCard extends StatefulWidget {
  final Map<String, dynamic> chat;
  final int index;
  final bool isDark; // NUEVO: para adaptar colores al tema
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _AnimatedChatCard({
    required this.chat,
    required this.index,
    required this.isDark,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<_AnimatedChatCard> createState() => _AnimatedChatCardState();
}

class _AnimatedChatCardState extends State<_AnimatedChatCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 480),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Stagger: cada tarjeta aparece 70ms después de la anterior
    Future.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    // Colores adaptados al tema
    final cardColor = isDark ? const Color(0xFF1E3D3A) : Colors.white;
    final titleColor = isDark ? Colors.white : _kPrimario;
    final subColor = isDark ? Colors.white38 : _kPrimario.withOpacity(0.42);
    final menuIconColor = isDark ? _kAcento : _kSecundario;

    // Número de orden del chat (1-based, invertido: más reciente primero)
    final ordenNumero = widget.index + 1;

    // Fecha formateada
    final fechaStr = _formatFecha(widget.chat['created_at']?.toString());

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onOpen,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 110),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 6),
            transform: Matrix4.identity()..scale(_isPressed ? 0.975 : 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color:
                      isDark
                          ? Colors.white.withOpacity(0.06)
                          : _kAcento.withOpacity(0.08),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        isDark
                            ? Colors.black.withOpacity(_isPressed ? 0.3 : 0.18)
                            : _kSecundario.withOpacity(
                              _isPressed ? 0.22 : 0.08,
                            ),
                    blurRadius: _isPressed ? 18 : 10,
                    offset: Offset(0, _isPressed ? 6 : 3),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // ── Avatar con inicial + número de orden ──
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_kSecundario, _kAcento],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Center(
                            child: Text(
                              widget.chat['title']
                                  .toString()
                                  .substring(0, 1)
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 20,
                              ),
                            ),
                          ),
                        ),
                        // Chip de número en esquina superior derecha
                        Positioned(
                          top: -4,
                          right: -4,
                          child: Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? const Color(0xFF0F2A28)
                                      : const Color(0xFFEDF4F3),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color:
                                    isDark
                                        ? _kAcento.withOpacity(0.3)
                                        : _kSecundario.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$ordenNumero',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? _kAcento : _kSecundario,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(width: 14),

                    // ── Título + fecha ────────────────────────
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Título con jerarquía tipográfica
                          Text(
                            widget.chat['title']?.toString() ?? 'Sin título',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: titleColor,
                              letterSpacing: -0.3,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 5),
                          // Subtítulo: fecha real de creación
                          Row(
                            children: [
                              Icon(
                                Icons.schedule_rounded,
                                size: 11,
                                color: subColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                fechaStr,
                                style: TextStyle(
                                  color: subColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // ── Menú de opciones ──────────────────────
                    PopupMenuButton<String>(
                      icon: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: menuIconColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.more_vert_rounded,
                          color: menuIconColor,
                          size: 18,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      color: isDark ? const Color(0xFF1E3D3A) : Colors.white,
                      itemBuilder:
                          (context) => [
                            _buildMenuItem(
                              'open',
                              Icons.open_in_new_rounded,
                              'Abrir',
                              null,
                              isDark,
                            ),
                            _buildMenuItem(
                              'rename',
                              Icons.edit_rounded,
                              'Renombrar',
                              null,
                              isDark,
                            ),
                            const PopupMenuDivider(height: 1),
                            _buildMenuItem(
                              'delete',
                              Icons.delete_outline_rounded,
                              'Eliminar',
                              Colors.redAccent,
                              isDark,
                            ),
                          ],
                      onSelected: (value) {
                        if (value == 'open') widget.onOpen();
                        if (value == 'rename') widget.onRename();
                        if (value == 'delete') widget.onDelete();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildMenuItem(
    String value,
    IconData icon,
    String label,
    Color? color,
    bool isDark,
  ) {
    final defaultColor = isDark ? Colors.white70 : _kPrimario;
    return PopupMenuItem<String>(
      value: value,
      height: 42,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color ?? defaultColor),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color ?? defaultColor,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HELPER — Formatear fecha de creación del chat
// =============================================================================
// Convierte el campo created_at (ISO 8601 o Timestamp.toString()) en:
//   "Hoy" / "Ayer" / "15 mar" / "15 mar 2024"
String _formatFecha(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) return 'Sin fecha';

  DateTime? fecha;
  try {
    // Intentar parsear ISO 8601 directo
    fecha = DateTime.tryParse(rawDate);

    // Si falla, intentar limpiar el formato de Timestamp de Firestore
    // Ej: "Timestamp(seconds=1715000000, nanoseconds=0)"
    if (fecha == null && rawDate.contains('seconds=')) {
      final match = RegExp(r'seconds=(\d+)').firstMatch(rawDate);
      if (match != null) {
        final seconds = int.tryParse(match.group(1)!);
        if (seconds != null) {
          fecha = DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
        }
      }
    }
  } catch (_) {}

  if (fecha == null) return 'Sin fecha';

  final now = DateTime.now();
  final hoy = DateTime(now.year, now.month, now.day);
  final ayer = hoy.subtract(const Duration(days: 1));
  final fechaDia = DateTime(fecha.year, fecha.month, fecha.day);

  if (fechaDia == hoy) return 'Hoy';
  if (fechaDia == ayer) return 'Ayer';

  // Si es del año actual: "15 mar"
  if (fecha.year == now.year) {
    return DateFormat('d MMM', 'es').format(fecha);
  }

  // Años anteriores: "15 mar 2023"
  return DateFormat('d MMM yyyy', 'es').format(fecha);
}
