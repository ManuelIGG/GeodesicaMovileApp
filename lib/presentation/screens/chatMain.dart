// lib/presentation/screens/chatMain.dart
// Pantalla principal del chat.
// Modificado para:
//   1. Usar RichMessage en lugar de Map<String,String>
//   2. Renderizar burbujas enriquecidas con gráficas y botones de exportación
//   3. Llamar a ChatProvider.enviarMensajeConIA() (que ya detecta intención)
//   4. Mostrar timestamps relativos en cada mensaje
//
// Todo el estado del chat se maneja en ChatProvider (messageProvider.dart)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:flutter_application_4_geodesica/model/rich_message_model.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/messageProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/themeProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/userProvider.dart';
import 'package:flutter_application_4_geodesica/services/chat_local_service.dart';
import 'package:flutter_application_4_geodesica/data/database_helper.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({Key? key}) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final dbHelper = DatabaseHelper();

  bool _isLoadingChat = true;

  late AnimationController _typingController;
  late AnimationController _appBarController;
  late AnimationController _inputController;

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _appBarController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _inputController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _loadChat();
    _appBarController.forward();
  }

  @override
  void dispose() {
    _typingController.dispose();
    _appBarController.dispose();
    _inputController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────────────────────
  // CARGA INICIAL DEL CHAT
  // Obtiene o crea el chatId, carga mensajes desde Firestore
  // y agrega mensaje de bienvenida si es una conversación nueva
  // ─────────────────────────────────────────────────────────────
  Future<void> _loadChat() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final userId = userProvider.currentUserId;
    if (userId == null) return;

    String? chatId = userProvider.currentChatId;
    if (chatId == null) {
      chatId = await ChatLocalService.getOrCreateChatId(userId);
      userProvider.setCurrentChatId(chatId);
    }

    // Cargar mensajes existentes desde Firestore
    await chatProvider.loadMessagesFromChat(chatId);

    // Si no hay mensajes, agregar bienvenida
    if (chatProvider.messages.isEmpty) {
      const bienvenida =
          'Hola, soy Geodésica 👋\nSoy el asistente financiero de DEMOS S.A.\n\n'
          'Puedes preguntarme sobre los movimientos financieros, '
          'pedir reportes contables o solicitar gráficas.\n\n'
          'Ejemplos:\n'
          '• "Muéstrame las ventas de hoy en un diagrama de pastel"\n'
          '• "Genera el estado de resultados del último mes"\n'
          '• "¿Cuáles son los gastos de esta semana?"';

      await ChatLocalService.saveMessage(chatId, 'assistant', bienvenida);

      chatProvider.addMessage(
        RichMessage(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          rol: 'assistant',
          text: bienvenida,
          timestamp: DateTime.now(),
        ),
      );
    }

    setState(() => _isLoadingChat = false);
    _inputController.forward();

    await Future.delayed(const Duration(milliseconds: 300));
    _scrollToBottom(jump: true);
  }

  // ─────────────────────────────────────────────────────────────
  // ENVIAR MENSAJE
  // Delega al ChatProvider que maneja todo el flujo IA/reporte
  // ─────────────────────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final chatId = userProvider.currentChatId;
    final text = _controller.text.trim();

    if (text.isEmpty || chatId == null) return;

    HapticFeedback.lightImpact();
    _controller.clear();

    // ChatProvider detecta la intención y responde adecuadamente
    await chatProvider.enviarMensajeConIA(chatId, text);

    _scrollToBottom();
  }

  void _scrollToBottom({bool jump = false}) {
    Future.delayed(const Duration(milliseconds: 250), () {
      if (_scrollController.hasClients) {
        if (jump) {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  Future<void> _editarTituloChat() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatId = userProvider.currentChatId;
    if (chatId == null) return;

    final chats = await dbHelper.getChatsForUser(userProvider.currentUserId!);
    final currentChat = chats.firstWhere(
      (chat) => chat['id'] == chatId,
      orElse: () => {'title': 'Geodesica'},
    );

    final titleController = TextEditingController(text: currentChat['title']);

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder:
          (ctx, anim, _, child) => ScaleTransition(
            scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
            child: FadeTransition(opacity: anim, child: child),
          ),
      pageBuilder:
          (ctx, _, __) => _buildTitleDialog(ctx, chatId, titleController),
    );
  }

  void _logout() {
    Provider.of<UserProvider>(context, listen: false).logout();
    Provider.of<ChatProvider>(context, listen: false).clearMessages();
    Navigator.of(context).pushReplacementNamed('/');
  }

  void _showToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF59A897),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<AppThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final chatProvider = Provider.of<ChatProvider>(context);

    final backgroundColor =
        isDark ? const Color(0xFF1A3735) : const Color(0xFFF0F4F4);
    final appBarBg = isDark ? const Color(0xFF1D413E) : const Color(0xFFE6EEF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: _buildAppBar(isDark, appBarBg, themeProvider, chatProvider),
      body:
          _isLoadingChat
              ? _buildLoadingScreen(isDark)
              : Column(
                children: [
                  Expanded(child: _buildMessageList(isDark, chatProvider)),
                  if (chatProvider.isTyping) _buildTypingIndicator(isDark),
                  _buildInputBar(isDark, chatProvider),
                ],
              ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // LISTA DE MENSAJES
  // Itera sobre chatProvider.messages y renderiza RichMessage
  // ─────────────────────────────────────────────────────────────
  Widget _buildMessageList(bool isDark, ChatProvider chatProvider) {
    final messages = chatProvider.messages;
    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemBuilder: (context, index) {
        return _AnimatedRichBubble(
          message: messages[index],
          isDark: isDark,
          index: index,
          onExportPdf: () => chatProvider.exportReportToPDF(messages[index].id),
          onExportExcel:
              () => chatProvider.exportReportToExcel(messages[index].id),
        );
      },
    );
  }

  // ─────────────────────────────────────────────────────────────
  // INPUT BAR
  // ─────────────────────────────────────────────────────────────
  Widget _buildInputBar(bool isDark, ChatProvider chatProvider) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _inputController, curve: Curves.easeOutCubic),
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1D413E) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.white.withOpacity(0.08)
                            : const Color(0xFFEFF5F4),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: const Color(0xFF59A897).withOpacity(0.25),
                    ),
                  ),
                  child: TextField(
                    controller: _controller,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF1D413E),
                      fontSize: 15,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Escribe tu mensaje...',
                      hintStyle: TextStyle(
                        color:
                            isDark
                                ? Colors.white38
                                : const Color(0xFF1D413E).withOpacity(0.4),
                        fontSize: 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _SendButton(
                onPressed: _sendMessage,
                isLoading: chatProvider.isTyping,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _TypingDots(controller: _typingController),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF59A897).withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Cargando chat...',
            style: TextStyle(
              color: Color(0xFF59A897),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              backgroundColor: const Color(0xFF59A897).withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF59A897),
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(
    bool isDark,
    Color appBarBg,
    AppThemeProvider themeProvider,
    ChatProvider chatProvider,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(65),
      child: FadeTransition(
        opacity: _appBarController,
        child: Container(
          decoration: BoxDecoration(
            color: appBarBg,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF59A897).withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
                            ).createShader(bounds),
                        child: const Text(
                          'Geodesica',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              color:
                                  chatProvider.isTyping
                                      ? Colors.amber
                                      : const Color(0xFF46E0C9),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            chatProvider.isTyping
                                ? 'Analizando...'
                                : 'En línea',
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  isDark
                                      ? Colors.white54
                                      : const Color(
                                        0xFF1D413E,
                                      ).withOpacity(0.6),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF59A897).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white : const Color(0xFF1D413E),
                        size: 20,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    onSelected: (value) {
                      if (value == 'logout') _logout();
                      if (value == 'theme') themeProvider.toggleTheme();
                      if (value == 'history')
                        Navigator.of(context).pushNamed('/chat-list');
                      if (value == 'editTitle') _editarTituloChat();
                    },
                    itemBuilder:
                        (context) => [
                          _menuItem(
                            'theme',
                            isDark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            isDark ? 'Modo Claro' : 'Modo Oscuro',
                            null,
                          ),
                          _menuItem(
                            'editTitle',
                            Icons.edit_rounded,
                            'Editar título',
                            null,
                          ),
                          _menuItem(
                            'history',
                            Icons.history_rounded,
                            'Ver conversaciones',
                            null,
                          ),
                          const PopupMenuDivider(),
                          _menuItem(
                            'logout',
                            Icons.logout_rounded,
                            'Cerrar sesión',
                            Colors.red,
                          ),
                        ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _menuItem(
    String value,
    IconData icon,
    String label,
    Color? color,
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? const Color(0xFF59A897)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              color: color ?? const Color(0xFF1D413E),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleDialog(
    BuildContext ctx,
    String chatId,
    TextEditingController titleController,
  ) {
    final isDark = Provider.of<AppThemeProvider>(ctx, listen: false).isDarkMode;
    final bg = isDark ? const Color(0xFF1D413E) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1D413E);

    return AlertDialog(
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Text(
        'Editar título del chat',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      content: TextField(
        controller: titleController,
        autofocus: true,
        style: TextStyle(color: textColor),
        decoration: InputDecoration(
          hintText: 'Escribe un título...',
          hintStyle: TextStyle(color: textColor.withOpacity(0.4)),
          filled: true,
          fillColor: textColor.withOpacity(0.07),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF46E0C9), width: 2),
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
              await dbHelper.updateChatTitle(chatId, nuevoTitulo);
              if (mounted) {
                _showToast('Título actualizado');
                Navigator.pop(ctx);
              }
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF59A897),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// BURBUJA DE MENSAJE ANIMADA CON SOPORTE PARA REPORTES Y GRÁFICAS
// Reemplaza _AnimatedMessageBubble del chatMain original.
// Renderiza texto, gráfica interactiva y botones PDF/Excel.
// ─────────────────────────────────────────────────────────────────
class _AnimatedRichBubble extends StatefulWidget {
  final RichMessage message;
  final bool isDark;
  final int index;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;

  const _AnimatedRichBubble({
    required this.message,
    required this.isDark,
    required this.index,
    required this.onExportPdf,
    required this.onExportExcel,
  });

  @override
  State<_AnimatedRichBubble> createState() => _AnimatedRichBubbleState();
}

class _AnimatedRichBubbleState extends State<_AnimatedRichBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _slide = Tween<Offset>(
      begin: Offset(widget.message.isUser ? 0.3 : -0.3, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final delay = widget.index < 3 ? widget.index * 60 : 0;
    Future.delayed(Duration(milliseconds: delay), () {
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
    final isUser = widget.message.isUser;
    final isReport = widget.message.isReport;
    final isDark = widget.isDark;

    final userColor = const Color(0xFF46E0C9);
    final botColor = isDark ? const Color(0xFF2A4F4B) : Colors.white;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // ── Avatar + Burbuja ─────────────────────────────
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar bot
                if (!isUser)
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),

                // Burbuja principal
                Flexible(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.78,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isReport ? 14 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? userColor : botColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser
                                  ? const Color(0xFF46E0C9)
                                  : Colors.black)
                              .withOpacity(0.12),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Texto del mensaje ──────────────
                        Text(
                          widget.message.text,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.4,
                            color:
                                isUser
                                    ? Colors.white
                                    : (isDark
                                        ? Colors.white
                                        : const Color(0xFF1D413E)),
                          ),
                        ),

                        // ── Gráfica interactiva ────────────
                        if (isReport && widget.message.chartWidget != null) ...[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              color:
                                  isDark
                                      ? const Color(0xFF1D413E)
                                      : const Color(0xFFF8FFFE),
                              padding: const EdgeInsets.all(8),
                              child: widget.message.chartWidget!,
                            ),
                          ),
                        ],

                        // ── Botones de exportación ─────────
                        if (isReport) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _ExportButton(
                                icon: Icons.picture_as_pdf_rounded,
                                label: 'PDF',
                                color: const Color(0xFFD32F2F),
                                onPressed: widget.onExportPdf,
                              ),
                              const SizedBox(width: 8),
                              _ExportButton(
                                icon: Icons.table_chart_rounded,
                                label: 'Excel',
                                color: const Color(0xFF388E3C),
                                onPressed: widget.onExportExcel,
                              ),
                            ],
                          ),
                        ],

                        // ── Timestamp relativo ─────────────
                        const SizedBox(height: 6),
                        Text(
                          widget.message.relativeTime,
                          style: TextStyle(
                            fontSize: 10,
                            color:
                                isUser ? Colors.white60 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Avatar usuario
                if (isUser)
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(left: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF46E0C9).withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: Color(0xFF46E0C9),
                      size: 16,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// BOTÓN DE EXPORTACIÓN (PDF / Excel)
// ─────────────────────────────────────────────────────────────────
class _ExportButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onPressed;

  const _ExportButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label, style: TextStyle(color: color, fontSize: 12)),
      style: OutlinedButton.styleFrom(
        side: BorderSide(color: color.withOpacity(0.5)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// TYPING DOTS (sin cambios respecto al original)
// ─────────────────────────────────────────────────────────────────
class _TypingDots extends StatelessWidget {
  final AnimationController controller;
  const _TypingDots({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final offset = (controller.value - i * 0.2).clamp(0.0, 1.0);
            final bounce = (offset < 0.5 ? offset : 1.0 - offset) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: 8,
              height: 8 + (bounce * 4),
              decoration: BoxDecoration(
                color: Color.lerp(
                  const Color(0xFF59A897).withOpacity(0.4),
                  const Color(0xFF46E0C9),
                  bounce,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// SEND BUTTON (sin cambios respecto al original)
// ─────────────────────────────────────────────────────────────────
class _SendButton extends StatefulWidget {
  final VoidCallback onPressed;
  final bool isLoading;
  const _SendButton({required this.onPressed, required this.isLoading});

  @override
  State<_SendButton> createState() => _SendButtonState();
}

class _SendButtonState extends State<_SendButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) {
        setState(() => _isPressed = true);
        _controller.forward();
      },
      onTapUp: (_) {
        setState(() => _isPressed = false);
        _controller.reverse();
        widget.onPressed();
      },
      onTapCancel: () {
        setState(() => _isPressed = false);
        _controller.reverse();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(
                0xFF59A897,
              ).withOpacity(_isPressed ? 0.15 : 0.4),
              blurRadius: _isPressed ? 4 : 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        transform: Matrix4.identity()..scale(_isPressed ? 0.93 : 1.0),
        child: Center(
          child:
              widget.isLoading
                  ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                  : const Icon(
                    Icons.send_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
        ),
      ),
    );
  }
}
