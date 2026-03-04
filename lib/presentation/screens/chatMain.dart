// =============================================================================
// lib/presentation/screens/chatMain.dart
// =============================================================================
// CAMBIOS RESPECTO A LA VERSIÓN ANTERIOR:
//
//   1. _GeodesicaRichText — NUEVO widget que parsea y renderiza el texto de los
//      mensajes del asistente con jerarquía tipográfica:
//        - Líneas con ** → título en negrita, tamaño mayor, color acento
//        - Líneas con • o - → bullet con sangría y punto decorativo de color
//        - Emojis de sección (📊🕐) → renderizados en líneas propias con estilo
//        - Cuerpo general → tipografía clara, interlineado generoso
//        - Mensajes del usuario → siempre texto plano (sin parseo)
//
//   2. _ReportBubbleHeader — NUEVO widget que reemplaza el texto plano en
//      burbujas de reporte. Muestra:
//        - Ícono de gráfica + tipo de reporte (chip)
//        - Título del reporte en tipografía prominente
//        - Período y hora de generación
//        - Separador sutil
//        - Chips de métricas (Ingresos / Gastos / Utilidad)
//        - Texto del resumen con _GeodesicaRichText
//
//   3. _buildChartContainer — MODIFICADO: se añade el botón "Vista completa"
//      (ícono expand en esquina superior derecha) que abre
//      GeodesicaExpandedChartDialog con la gráfica a pantalla completa.
//
//   4. _AnimatedRichBubble — MODIFICADO: usa _ReportBubbleHeader para reportes
//      y _GeodesicaRichText para mensajes de texto, en lugar de Text() plano.
//
//   5. _buildInputBar — MODIFICADO: sugerencias rápidas de reportes como chips
//      horizontales desplazables encima del campo de texto (solo cuando está vacío).
//
// ARCHIVOS REQUERIDOS:
//   → chart_widget.dart debe incluir GeodesicaExpandedChartDialog (versión nueva)
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'package:flutter_application_4_geodesica/model/rich_message_model.dart';
import 'package:flutter_application_4_geodesica/model/report_model.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/messageProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/themeProvider.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/userProvider.dart';
import 'package:flutter_application_4_geodesica/services/chat_local_service.dart';
import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:flutter_application_4_geodesica/widgets/chart_widget.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Colores corporativos reutilizados ────────────────────────────
const _kPrimario = Color(0xFF1D413E);
const _kAcento = Color(0xFF46E0C9);
const _kSecundario = Color(0xFF59A897);
const _kRojo = Color(0xFFD32F2F);
const _kVerde = Color(0xFF388E3C);
const _kAzul = Color(0xFF1565C0);

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
  bool _showSuggestions =
      true; // Muestra chips de sugerencia cuando el campo está vacío

  late AnimationController _typingController;
  late AnimationController _appBarController;
  late AnimationController _inputController;

  // Sugerencias rápidas de reportes para mostrar como chips
  static const _suggestions = [
    '📊 Ventas por producto',
    '💰 Gastos del mes',
    '📈 Tendencia semanal',
    '🥧 Balance por categoría',
    '🏆 Productos más vendidos',
    '💳 Cuentas por cobrar',
  ];

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

    _controller.addListener(() {
      final show = _controller.text.isEmpty;
      if (show != _showSuggestions) setState(() => _showSuggestions = show);
    });

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

  // ── Carga inicial del chat ─────────────────────────────────────
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

    await chatProvider.loadMessagesFromChat(chatId);

    if (chatProvider.messages.isEmpty) {
      const bienvenida =
          '**Hola, soy Geodésica 👋**\n'
          'Soy el asistente financiero de DEMOS S.A.\n\n'
          'Puedo ayudarte con:\n'
          '• Reportes de ventas, gastos e inventario\n'
          '• Gráficas interactivas por período\n'
          '• Consultas sobre clientes y proveedores\n\n'
          'Escribe tu solicitud o usa una sugerencia rápida abajo.';

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

  // ── Enviar mensaje ─────────────────────────────────────────────
  Future<void> _sendMessage() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final chatId = userProvider.currentChatId;
    final text = _controller.text.trim();
    if (text.isEmpty || chatId == null) return;

    HapticFeedback.lightImpact();
    _controller.clear();
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
        backgroundColor: isError ? Colors.redAccent : _kSecundario,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _onViewOnline(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _showToast('URL inválida', isError: true);
      return;
    }
    try {
      final puedeAbrir = await canLaunchUrl(uri);
      if (puedeAbrir) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await Clipboard.setData(ClipboardData(text: url));
        _showToast('URL copiada al portapapeles');
      }
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: url));
      _showToast('URL copiada: $url');
    }
  }

  // ── BUILD ──────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<AppThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final chatProvider = Provider.of<ChatProvider>(context);

    final backgroundColor =
        isDark ? const Color(0xFF111F1E) : const Color(0xFFEDF4F3);
    final appBarBg = isDark ? const Color(0xFF1A3735) : const Color(0xFFE2EEEC);

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

  // ── Lista de mensajes ──────────────────────────────────────────
  Widget _buildMessageList(bool isDark, ChatProvider chatProvider) {
    final messages = chatProvider.messages;
    return ListView.builder(
      controller: _scrollController,
      itemCount: messages.length,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _AnimatedRichBubble(
          message: msg,
          isDark: isDark,
          index: index,
          onExportPdf: () => chatProvider.exportReportToPDF(msg.id),
          onExportExcel: () => chatProvider.exportReportToExcel(msg.id),
          reportPublicUrl: msg.reportPublicUrl,
          onViewOnline:
              msg.reportPublicUrl != null
                  ? () => _onViewOnline(msg.reportPublicUrl!)
                  : null,
          onExpandChart:
              msg.isReport && msg.report != null
                  ? () => _openExpandedChart(context, msg.report!, isDark)
                  : null,
        );
      },
    );
  }

  // ── Abrir gráfica en vista completa ───────────────────────────
  // NUEVO: abre GeodesicaExpandedChartDialog con la gráfica a pantalla completa.
  void _openExpandedChart(
    BuildContext context,
    ReportModel report,
    bool isDark,
  ) {
    final chartTypeStr =
        report.chartType == ChartType.pie
            ? 'pie'
            : report.chartType == ChartType.line
            ? 'line'
            : 'bar';

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.65),
      builder:
          (_) => GeodesicaExpandedChartDialog(
            titulo: report.title,
            periodo: report.periodoFormateado,
            chartType: chartTypeStr,
            data: report.chartData,
            isDark: isDark,
          ),
    );
  }

  // ── Input bar con sugerencias rápidas ─────────────────────────
  Widget _buildInputBar(bool isDark, ChatProvider chatProvider) {
    return SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 1),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(parent: _inputController, curve: Curves.easeOutCubic),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A3735) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Chips de sugerencias (solo cuando el campo está vacío) ──
              if (_showSuggestions) ...[
                const SizedBox(height: 10),
                SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder:
                        (_, i) => GestureDetector(
                          onTap: () {
                            // Eliminar el emoji del inicio para enviar texto limpio
                            final clean =
                                _suggestions[i]
                                    .replaceAll(RegExp(r'^[^\w\s]+\s*'), '')
                                    .trim();
                            _controller.text = clean;
                            _sendMessage();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  isDark
                                      ? _kAcento.withOpacity(0.12)
                                      : _kAcento.withOpacity(0.09),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _kAcento.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              _suggestions[i],
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? _kAcento : _kPrimario,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
              ],

              // ── Campo de texto + botón enviar ───────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              isDark
                                  ? Colors.white.withOpacity(0.07)
                                  : const Color(0xFFEFF5F4),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _kSecundario.withOpacity(0.25),
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          style: TextStyle(
                            color: isDark ? Colors.white : _kPrimario,
                            fontSize: 15,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Consulta o solicita un reporte...',
                            hintStyle: TextStyle(
                              color:
                                  isDark
                                      ? Colors.white38
                                      : _kPrimario.withOpacity(0.38),
                              fontSize: 14,
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
              gradient: const LinearGradient(colors: [_kSecundario, _kAcento]),
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
              color: isDark ? const Color(0xFF2A4F4B) : Colors.white,
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
                colors: [_kSecundario, _kAcento],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: _kSecundario.withOpacity(0.4),
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
            'Cargando conversación...',
            style: TextStyle(
              color: _kSecundario,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 120,
            child: LinearProgressIndicator(
              backgroundColor: _kSecundario.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(_kSecundario),
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
                color: _kSecundario.withOpacity(0.15),
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
                        colors: [_kSecundario, _kAcento],
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
                              colors: [_kSecundario, _kAcento],
                            ).createShader(bounds),
                        child: const Text(
                          'Geodésica',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            letterSpacing: -0.5,
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
                                      : _kAcento,
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
                                      : _kPrimario.withOpacity(0.6),
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
                        color: _kSecundario.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.more_vert_rounded,
                        color: isDark ? Colors.white : _kPrimario,
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
          Icon(icon, size: 18, color: color ?? _kSecundario),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: color ?? _kPrimario, fontSize: 14),
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
    final textColor = isDark ? Colors.white : _kPrimario;

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
              await dbHelper.updateChatTitle(chatId, nuevoTitulo);
              if (mounted) {
                _showToast('Título actualizado');
                Navigator.pop(ctx);
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
    );
  }
}

// =============================================================================
// BURBUJA ANIMADA — renderiza texto enriquecido y reportes con header elegante
// =============================================================================
class _AnimatedRichBubble extends StatefulWidget {
  final RichMessage message;
  final bool isDark;
  final int index;
  final VoidCallback onExportPdf;
  final VoidCallback onExportExcel;
  final VoidCallback? onViewOnline;
  final String? reportPublicUrl;
  // NUEVO: callback para abrir la gráfica en vista completa
  final VoidCallback? onExpandChart;

  const _AnimatedRichBubble({
    required this.message,
    required this.isDark,
    required this.index,
    required this.onExportPdf,
    required this.onExportExcel,
    this.onViewOnline,
    this.reportPublicUrl,
    this.onExpandChart,
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
      duration: const Duration(milliseconds: 420),
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

    final botColor = isDark ? const Color(0xFF1E3D3A) : Colors.white;

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: Column(
          crossAxisAlignment:
              isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment:
                  isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Avatar del bot
                if (!isUser)
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(right: 8, bottom: 4),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kSecundario, _kAcento],
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
                      maxWidth:
                          MediaQuery.of(context).size.width *
                          (isReport ? 0.92 : 0.78),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: isReport ? 0 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: isUser ? _kAcento : botColor,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(20),
                        topRight: const Radius.circular(20),
                        bottomLeft: Radius.circular(isUser ? 20 : 4),
                        bottomRight: Radius.circular(isUser ? 4 : 20),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (isUser ? _kAcento : Colors.black).withOpacity(
                            isReport ? 0.18 : 0.10,
                          ),
                          blurRadius: isReport ? 14 : 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      // Borde sutil solo en burbujas de reporte
                      border:
                          isReport
                              ? Border.all(
                                color: _kAcento.withOpacity(
                                  isDark ? 0.2 : 0.12,
                                ),
                              )
                              : null,
                    ),
                    child:
                        isReport
                            ? _buildReportContent(isDark)
                            : _buildTextContent(isUser, isDark),
                  ),
                ),

                // Avatar usuario
                if (isUser)
                  Container(
                    width: 30,
                    height: 30,
                    margin: const EdgeInsets.only(left: 8, bottom: 4),
                    decoration: BoxDecoration(
                      color: _kAcento.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.person_rounded,
                      color: _kAcento,
                      size: 16,
                    ),
                  ),
              ],
            ),

            // Timestamp fuera de la burbuja
            Padding(
              padding: EdgeInsets.only(
                bottom: 8,
                left: isUser ? 0 : 44,
                right: isUser ? 44 : 0,
              ),
              child: Text(
                widget.message.relativeTime,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Contenido de mensaje de texto plano ────────────────────────
  Widget _buildTextContent(bool isUser, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child:
          isUser
              // Mensajes del usuario: siempre texto plano blanco
              ? Text(
                widget.message.text,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Colors.white,
                ),
              )
              // Mensajes del bot: renderizado rico con jerarquía tipográfica
              : _GeodesicaRichText(text: widget.message.text, isDark: isDark),
    );
  }

  // ── Contenido de mensaje de reporte ────────────────────────────
  Widget _buildReportContent(bool isDark) {
    final report = widget.message.report;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header elegante del reporte
        _ReportBubbleHeader(
          message: widget.message,
          report: report,
          isDark: isDark,
        ),

        // Separador
        Divider(
          color:
              isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.black.withOpacity(0.06),
          height: 1,
        ),

        // Gráfica + botón de vista completa
        if (widget.message.chartWidget != null)
          _buildChartContainer(isDark, report),

        // Separador antes de botones
        if (widget.message.chartWidget != null)
          Divider(
            color:
                isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.black.withOpacity(0.06),
            height: 1,
          ),

        // Botones de exportación
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _ExportButton(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    color: _kRojo,
                    onPressed: widget.onExportPdf,
                  ),
                  _ExportButton(
                    icon: Icons.table_chart_rounded,
                    label: 'Excel',
                    color: _kVerde,
                    onPressed: widget.onExportExcel,
                  ),
                  if (widget.onViewOnline != null)
                    _OnlineButton(onPressed: widget.onViewOnline!),
                ],
              ),
              if (widget.reportPublicUrl != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.cloud_done_rounded,
                      size: 12,
                      color: _kAcento,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Disponible en línea',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: isDark ? _kAcento : _kSecundario,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Contenedor de gráfica con botón de vista completa ─────────
  // NUEVO: se añade el botón expand en la esquina superior derecha
  Widget _buildChartContainer(bool isDark, ReportModel? report) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      child: Stack(
        children: [
          // Gráfica compacta en su contenedor
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              color: isDark ? const Color(0xFF152E2B) : const Color(0xFFF5FFFE),
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
              child: widget.message.chartWidget!,
            ),
          ),

          // Botón "Vista completa" — esquina superior derecha
          if (widget.onExpandChart != null)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: widget.onExpandChart,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color:
                        isDark
                            ? Colors.black.withOpacity(0.45)
                            : Colors.white.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(7),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.12),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.open_in_full_rounded,
                    size: 14,
                    color: isDark ? Colors.white70 : _kPrimario,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// HEADER ELEGANTE DE BURBUJA DE REPORTE
// =============================================================================
// Reemplaza el texto plano en burbujas de reporte.
// Muestra: tipo de reporte (chip), título prominente, período,
// métricas financieras en chips, y resumen con rich text.
class _ReportBubbleHeader extends StatelessWidget {
  final RichMessage message;
  final ReportModel? report;
  final bool isDark;

  const _ReportBubbleHeader({
    required this.message,
    required this.report,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : _kPrimario;
    final subColor = isDark ? Colors.white54 : const Color(0xFF5A7A77);

    // Separar el texto del mensaje: primera línea = título, resto = resumen
    final lines = message.text.split('\n');
    // La primera línea tiene formato "📊 **Título**"
    final tituloRaw = lines.isNotEmpty ? lines[0] : '';
    // El resumen empieza después de la línea del período (línea 2)
    final resumenLines = lines.length > 3 ? lines.sublist(3) : [];
    final resumenText = resumenLines.join('\n').trim();

    // Período en la segunda línea
    final periodoLine = lines.length > 1 ? lines[1] : '';

    // Extraer solo el período limpio (sin emoji ni "Actualizado a las")
    final periodoClean = periodoLine.replaceAll(RegExp(r'^🕐\s*'), '').trim();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Fila: ícono de tipo + chip de tipo ──────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kSecundario, _kAcento],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 10),
              // Chip con el tipo normativo
              if (report != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _kAcento.withOpacity(isDark ? 0.15 : 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kAcento.withOpacity(0.3)),
                  ),
                  child: Text(
                    report!.typeName,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? _kAcento : _kSecundario,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Título del reporte ───────────────────────────────
          Text(
            report?.title ?? tituloRaw.replaceAll(RegExp(r'\*+'), '').trim(),
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 4),

          // ── Período ──────────────────────────────────────────
          Text(
            report?.periodoFormateado ?? periodoClean,
            style: TextStyle(
              fontSize: 12,
              color: subColor,
              fontWeight: FontWeight.w400,
            ),
          ),

          // ── Chips de métricas financieras ────────────────────
          if (report != null) ...[
            const SizedBox(height: 12),
            _buildMetricChips(report!, isDark),
          ],

          const SizedBox(height: 12),

          // ── Resumen con rich text ────────────────────────────
          if (resumenText.isNotEmpty)
            _GeodesicaRichText(text: resumenText, isDark: isDark)
          else if (report?.summary.isNotEmpty == true)
            _GeodesicaRichText(text: report!.summary, isDark: isDark),
        ],
      ),
    );
  }

  // Chips compactos con las métricas financieras principales
  Widget _buildMetricChips(ReportModel report, bool isDark) {
    final fmt = NumberFormat.compactCurrency(
      locale: 'es_CO',
      symbol: '\$',
      decimalDigits: 0,
    );
    final utilidadPositiva = report.utilidad >= 0;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (report.ingresos > 0)
          _MetricChip(
            label: 'Ingresos',
            value: fmt.format(report.ingresos),
            color: const Color(0xFF2E7D32),
            isDark: isDark,
          ),
        if (report.gastos > 0)
          _MetricChip(
            label: 'Gastos',
            value: fmt.format(report.gastos),
            color: _kRojo,
            isDark: isDark,
          ),
        if (report.ingresos > 0 || report.gastos > 0)
          _MetricChip(
            label: 'Utilidad',
            value: fmt.format(report.utilidad),
            color: utilidadPositiva ? const Color(0xFF1565C0) : _kRojo,
            isDark: isDark,
            isHighlight: true,
          ),
      ],
    );
  }
}

// Chip individual de métrica financiera
class _MetricChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isDark;
  final bool isHighlight;

  const _MetricChip({
    required this.label,
    required this.value,
    required this.color,
    required this.isDark,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:
            isHighlight
                ? color.withOpacity(isDark ? 0.2 : 0.1)
                : color.withOpacity(isDark ? 0.12 : 0.07),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(isHighlight ? 0.4 : 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              color: color.withOpacity(0.75),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// RICH TEXT RENDERER — jerarquía tipográfica para mensajes del bot
// =============================================================================
// Parsea el texto línea a línea y aplica estilos según el contenido:
//   **texto** o texto entre ** → título negrita, acento verde
//   • texto / - texto          → bullet con punto decorativo y sangría
//   Línea vacía                → espacio vertical entre párrafos
//   Resto                      → texto cuerpo normal
//
// No requiere dependencias externas.
class _GeodesicaRichText extends StatelessWidget {
  final String text;
  final bool isDark;

  const _GeodesicaRichText({required this.text, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? Colors.white : _kPrimario;
    final bodyColor =
        isDark ? Colors.white.withOpacity(0.88) : const Color(0xFF2C4A47);

    final lines = text.split('\n');
    final widgets = <Widget>[];

    for (final rawLine in lines) {
      final line = rawLine.trim();

      // Línea vacía → espacio entre párrafos
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        continue;
      }

      // Línea de título: empieza y/o termina con **
      final isTitulo = line.startsWith('**') && line.contains('**');
      if (isTitulo) {
        final cleanTitle = line.replaceAll('**', '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 4, top: 2),
            child: Text(
              cleanTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: isDark ? _kAcento : _kPrimario,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
          ),
        );
        continue;
      }

      // Bullet: línea que empieza con • o -
      final isBullet = line.startsWith('•') || line.startsWith('-');
      if (isBullet) {
        final bulletText = line.replaceFirst(RegExp(r'^[•\-]\s*'), '').trim();
        widgets.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Punto decorativo de color
                Padding(
                  padding: const EdgeInsets.only(top: 6, right: 8, left: 4),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: _kAcento,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Expanded(child: _buildInlineText(bulletText, bodyColor)),
              ],
            ),
          ),
        );
        continue;
      }

      // Texto de cuerpo con soporte de *énfasis* inline
      widgets.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: _buildInlineText(line, bodyColor),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: widgets,
    );
  }

  // Parsea *texto* como cursiva dentro de una línea
  Widget _buildInlineText(String text, Color baseColor) {
    // Si no hay asteriscos simples, devolver texto simple
    if (!text.contains('*')) {
      return Text(
        text,
        style: TextStyle(fontSize: 14.5, height: 1.55, color: baseColor),
      );
    }

    // Parsear segmentos normal / *cursiva*
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*([^*]+)\*');
    int lastEnd = 0;

    for (final match in regex.allMatches(text)) {
      // Segmento normal antes del match
      if (match.start > lastEnd) {
        spans.add(
          TextSpan(
            text: text.substring(lastEnd, match.start),
            style: TextStyle(color: baseColor, fontSize: 14.5, height: 1.55),
          ),
        );
      }
      // Segmento en cursiva
      spans.add(
        TextSpan(
          text: match.group(1),
          style: TextStyle(
            color: baseColor,
            fontSize: 14.5,
            height: 1.55,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
      lastEnd = match.end;
    }
    // Resto del texto después del último match
    if (lastEnd < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(lastEnd),
          style: TextStyle(color: baseColor, fontSize: 14.5, height: 1.55),
        ),
      );
    }

    return RichText(text: TextSpan(children: spans));
  }
}

// =============================================================================
// BOTONES DE EXPORTACIÓN (sin cambios)
// =============================================================================
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

class _OnlineButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _OnlineButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.open_in_browser_rounded, size: 14, color: _kAzul),
      label: const Text(
        'Ver Online',
        style: TextStyle(color: _kAzul, fontSize: 12),
      ),
      style: OutlinedButton.styleFrom(
        side: const BorderSide(color: Color(0x801565C0)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// =============================================================================
// TYPING DOTS (sin cambios)
// =============================================================================
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
                  _kSecundario.withOpacity(0.4),
                  _kAcento,
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

// =============================================================================
// SEND BUTTON (sin cambios funcionales, ajuste visual menor)
// =============================================================================
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
            colors: [_kSecundario, _kAcento],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _kSecundario.withOpacity(_isPressed ? 0.15 : 0.4),
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
