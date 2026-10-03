import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/api_service.dart';
import 'chat_screen.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});
  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  List<dynamic> _chats = [];
  bool _loading = true;
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  List<dynamic> get _filtered {
    if (_query.trim().isEmpty) return _chats;
    final q = _query.toLowerCase();
    return _chats.where((c) {
      final m = c as Map<String, dynamic>;
      final owner = ((m['owner'] as Map?)?['name'] ?? '').toString().toLowerCase();
      final plot = ((m['property'] as Map?)?['propertyName'] ?? '').toString().toLowerCase();
      final last = (m['lastMessage'] ?? '').toString().toLowerCase();
      return owner.contains(q) || plot.contains(q) || last.contains(q);
    }).toList();
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await Api.getMyChats();
      if (mounted) setState(() {
        _chats   = res['chats'] as List? ?? [];
        _loading = false;
      });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Messages', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: C.textDark)),
          Text('Your conversations with owners', style: TextStyle(fontSize: 12, color: C.textMuted)),
        ]),
        actions: [
          IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: C.primary)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: C.primary))
          : _chats.isEmpty
              ? _EmptyChats()
              : Column(children: [
                  // ── Search messages ──
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: TextField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                      decoration: InputDecoration(
                        hintText: 'Search messages…',
                        hintStyle: const TextStyle(color: C.textLight, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: C.primary, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close, size: 18, color: C.textLight),
                                onPressed: () => setState(() { _search.clear(); _query = ''; }),
                              )
                            : null,
                        filled: true,
                        fillColor: C.bg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: C.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: C.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: C.primary, width: 1.5),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: _filtered.isEmpty
                        ? const Center(
                            child: Text('No conversations match your search',
                                style: TextStyle(color: C.textMuted, fontSize: 14)))
                        : RefreshIndicator(
                            color: C.primary,
                            onRefresh: _load,
                            child: ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 8),
                              itemBuilder: (_, i) {
                                final c = _filtered[i] as Map<String, dynamic>;
                                return _ChatTile(chat: c, onTap: () async {
                                  await Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      chatId:    c['_id']  as String,
                                      ownerName: (c['owner'] as Map?)? ['name'] as String? ?? 'Owner',
                                      plotName:  (c['property'] as Map?)? ['propertyName'] as String? ?? 'Plot',
                                    ),
                                  ));
                                  _load();
                                });
                              },
                            ),
                          ),
                  ),
                ]),
    );
  }
}

class _ChatTile extends StatelessWidget {
  final Map<String, dynamic> chat;
  final VoidCallback onTap;
  const _ChatTile({required this.chat, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final owner    = chat['owner']    as Map<String, dynamic>? ?? {};
    final property = chat['property'] as Map<String, dynamic>? ?? {};
    final unread   = chat['unreadByCustomer'] as int? ?? 0;
    final lastMsg  = chat['lastMessage']  as String? ?? 'Start a conversation';
    final lastTs   = chat['lastMessageAt'] as String?;
    final name     = owner['name']             as String? ?? 'Owner';
    final plotName = property['propertyName']  as String? ?? 'Plot';
    final photos   = property['photos']        as List? ?? [];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: unread > 0 ? C.primaryLight : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: unread > 0 ? C.primary.withValues(alpha: 0.3) : C.border,
            width: unread > 0 ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          // Plot photo or owner avatar
          Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: photos.isNotEmpty
                  ? Image.network(
                      _fullUrl(photos.first as String),
                      width: 52, height: 52, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _Avatar(name),
                    )
                  : _Avatar(name),
            ),
            if (unread > 0)
              Positioned(
                top: -3, right: -3,
                child: Container(
                  width: 18, height: 18,
                  decoration: BoxDecoration(color: C.primary, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5)),
                  child: Center(child: Text('$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))),
                ),
              ),
          ]),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name,
                  style: TextStyle(fontSize: 14, fontWeight: unread > 0 ? FontWeight.w800 : FontWeight.w600,
                      color: C.textDark))),
              Text(_fmtTime(lastTs),
                  style: TextStyle(fontSize: 11,
                      color: unread > 0 ? C.primary : C.textLight,
                      fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w400)),
            ]),
            const SizedBox(height: 2),
            Text('re: $plotName',
                style: const TextStyle(fontSize: 12, color: C.primary, fontWeight: FontWeight.w600),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text(lastMsg,
                style: TextStyle(fontSize: 12,
                    color: unread > 0 ? C.textDark : C.textMuted,
                    fontWeight: unread > 0 ? FontWeight.w600 : FontWeight.w400),
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ])),
        ]),
      ),
    );
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt   = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60)  return 'now';
      if (diff.inMinutes < 60)  return '${diff.inMinutes}m';
      if (diff.inHours < 24)    return '${diff.inHours}h';
      if (diff.inDays < 7)      return '${diff.inDays}d';
      return '${dt.day}/${dt.month}';
    } catch (_) { return ''; }
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  const _Avatar(this.name);
  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(color: C.primaryLight, borderRadius: BorderRadius.circular(12)),
    child: Center(child: Text(
      name.isNotEmpty ? name[0].toUpperCase() : 'O',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: C.primary),
    )),
  );
}

class _EmptyChats extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Image.asset('assets/images/empty_messages.png',
          width: 220, fit: BoxFit.contain),
      const SizedBox(height: 12),
      const Text('No message yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.textDark)),
      const SizedBox(height: 6),
      const Text('You can start a chat anytime.',
          textAlign: TextAlign.center,
          style: TextStyle(color: C.textMuted, fontSize: 14, height: 1.5)),
    ]),
  );
}

String _fullUrl(String url) => url.startsWith('http') ? url : '${Api.mediaBase}$url';
