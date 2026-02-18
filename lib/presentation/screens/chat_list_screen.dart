import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_4_geodesica/data/database_helper.dart';
import 'package:flutter_application_4_geodesica/presentation/providers/userProvider.dart';
import 'package:provider/provider.dart';

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
      duration: const Duration(milliseconds: 800),
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
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _headerController, curve: Curves.easeOut),
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

  Future<void> _deleteChat(String chatId) async {
    await dbHelper.deleteChat(chatId);
    await _loadChats();
  }

  Future<void> _loadChats() async {
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    if (userProvider.currentUser != null) {
      final chats = await dbHelper.getChatsForUser(userProvider.currentUserId!);
      setState(() {
        _chats = chats;
        _isLoading = false;
      });
      await Future.delayed(const Duration(milliseconds: 200));
      _fabController.forward();
    }
  }

  void _openChat(Map<String, dynamic> chat) {
    HapticFeedback.lightImpact();
    final userProvider = Provider.of<UserProvider>(context, listen: false);
    userProvider.setCurrentChatId(chat['id'] as String);
    Navigator.of(context).pushNamed('/chat');
  }

  Future<void> _renombrarChat(Map<String, dynamic> chat) async {
    HapticFeedback.mediumImpact();
    final TextEditingController titleController = TextEditingController(
      text: chat['title'],
    );

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder:
          (ctx, _, __) => AlertDialog(
            backgroundColor: const Color(0xFF1D413E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              'Renombrar chat',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: TextField(
              controller: titleController,
              autofocus: true,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Nuevo nombre del chat',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.1),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF46E0C9),
                    width: 2,
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
                      _showSuccessSnackBar('Chat renombrado: $nuevoTitulo');
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
          ),
    );
  }

  Future<void> _confirmarEliminar(Map<String, dynamic> chat) async {
    HapticFeedback.mediumImpact();
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '',
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      transitionBuilder: (ctx, anim, _, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder:
          (ctx, _, __) => AlertDialog(
            backgroundColor: const Color(0xFF1D413E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            title: const Text(
              '¿Eliminar conversación?',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'Esta acción no se puede deshacer.',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Cancelar',
                  style: TextStyle(color: Colors.white.withOpacity(0.7)),
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
      if (mounted) _showSuccessSnackBar('Conversación eliminada');
    }
  }

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

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF59A897),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE6EEF0),
      extendBodyBehindAppBar: false,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(70),
        child: SlideTransition(
          position: _headerSlideAnimation,
          child: FadeTransition(
            opacity: _headerFadeAnimation,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF1D413E), Color(0xFF2A5E59)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x3359A897),
                    blurRadius: 20,
                    offset: Offset(0, 4),
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
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF46E0C9).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.chat_bubble_outline_rounded,
                          color: Color(0xFF46E0C9),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ShaderMask(
                        shaderCallback:
                            (bounds) => const LinearGradient(
                              colors: [
                                Color(0xFF59A897),
                                Color(0xFF46E0C9),
                                Colors.white,
                              ],
                            ).createShader(bounds),
                        child: const Text(
                          'Mis Conversaciones',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (!_isLoading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF46E0C9).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_chats.length}',
                            style: const TextStyle(
                              color: Color(0xFF46E0C9),
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
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
      ),
      body:
          _isLoading
              ? _buildLoadingState()
              : _chats.isEmpty
              ? _buildEmptyState()
              : _buildChatList(),
      floatingActionButton: ScaleTransition(
        scale: _fabScaleAnimation,
        child: FloatingActionButton.extended(
          onPressed: _crearNuevoChat,
          backgroundColor: const Color(0xFF59A897),
          elevation: 8,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            'Nueva conversación',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          extendedPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 12,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF59A897),
              ),
              backgroundColor: const Color(0xFF59A897).withOpacity(0.2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Cargando conversaciones...',
            style: TextStyle(
              color: const Color(0xFF1D413E).withOpacity(0.6),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFF59A897).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: Color(0xFF59A897),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Sin conversaciones aún',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1D413E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Toca el botón para iniciar\nuna nueva conversación',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF1D413E).withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _chats.length,
      itemBuilder: (context, index) {
        final chat = _chats[index];
        return _AnimatedChatCard(
          chat: chat,
          index: index,
          onOpen: () => _openChat(chat),
          onRename: () => _renombrarChat(chat),
          onDelete: () => _confirmarEliminar(chat),
        );
      },
    );
  }
}

// ─── Card animada individual ─────────────────────────────────────────────────

class _AnimatedChatCard extends StatefulWidget {
  final Map<String, dynamic> chat;
  final int index;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  const _AnimatedChatCard({
    required this.chat,
    required this.index,
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
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    Future.delayed(Duration(milliseconds: 80 * widget.index), () {
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
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            margin: const EdgeInsets.symmetric(vertical: 8),
            transform: Matrix4.identity()..scale(_isPressed ? 0.97 : 1.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(
                      0xFF59A897,
                    ).withOpacity(_isPressed ? 0.25 : 0.10),
                    blurRadius: _isPressed ? 20 : 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF59A897), Color(0xFF46E0C9)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          widget.chat['title']
                              .toString()
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Title & subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.chat['title'],
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF1D413E),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF46E0C9),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Toca para abrir',
                                style: TextStyle(
                                  color: const Color(
                                    0xFF1D413E,
                                  ).withOpacity(0.45),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Menu
                    PopupMenuButton<String>(
                      icon: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: const Color(0xFF59A897).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.more_vert,
                          color: Color(0xFF59A897),
                          size: 20,
                        ),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      itemBuilder:
                          (context) => [
                            _buildMenuItem(
                              'open',
                              Icons.open_in_new,
                              'Abrir chat',
                              null,
                            ),
                            _buildMenuItem(
                              'rename',
                              Icons.edit_rounded,
                              'Renombrar',
                              null,
                            ),
                            _buildMenuItem(
                              'delete',
                              Icons.delete_rounded,
                              'Eliminar',
                              Colors.red,
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
  ) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color ?? const Color(0xFF1D413E)),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(color: color ?? const Color(0xFF1D413E)),
          ),
        ],
      ),
    );
  }
}
