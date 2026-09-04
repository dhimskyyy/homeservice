import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../agreement/price_agreement_widgets.dart';
import '../auth/auth_provider.dart';
import '../core/theme.dart';
import '../jobs/job_providers.dart';
import '../shared/models/job_models.dart';
import 'chat_provider.dart';

class ChatPage extends ConsumerStatefulWidget {
  final String jobId;

  const ChatPage({super.key, required this.jobId});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = ref.read(authProvider).user;
    if (user == null) return;

    _messageController.clear();
    setState(() => _isSending = true);

    try {
      await ref.read(chatRoomProvider(widget.jobId).notifier).sendMessage(
            senderId: user.id,
            body: text,
          );
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengirim pesan: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  final _picker = ImagePicker();

  Future<void> _handlePickAndSendImage() async {
    final user = ref.read(authProvider).user;
    if (user == null) return;

    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() => _isSending = true);

      await ref.read(chatRoomProvider(widget.jobId).notifier).sendMediaMessage(
            senderId: user.id,
            fileName: picked.name,
            bytes: bytes,
            caption: _messageController.text.trim().isNotEmpty
                ? _messageController.text.trim()
                : null,
          );

      _messageController.clear();
      _scrollToBottom();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengirim foto: $e'), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showCreateAgreementDialog(Job job, String providerId) {
    showDialog(
      context: context,
      builder: (ctx) => CreateAgreementDialog(
        jobId: job.id,
        customerId: job.customerId,
        providerId: providerId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final chatState = ref.watch(chatRoomProvider(widget.jobId));
    final jobAsync = ref.watch(jobDetailProvider(widget.jobId));
    final theme = Theme.of(context);

    // Auto scroll & mark as read saat pesan baru masuk
    ref.listen(chatRoomProvider(widget.jobId), (previous, next) {
      _scrollToBottom();
      if (user != null) {
        ref.read(chatRoomProvider(widget.jobId).notifier).markAsRead(user.id);
      }
    });

    // Mark as read saat pertama kali membuka halaman
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (user != null) {
        ref.read(chatRoomProvider(widget.jobId).notifier).markAsRead(user.id);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: jobAsync.when(
          loading: () => const Text('Memuat obrolan...'),
          error: (err, stack) => const Text('Ruang Obrolan'),
          data: (job) {
            if (job == null) return const Text('Ruang Obrolan');
            final isTukang = user?.id != job.customerId;

            if (isTukang) {
              // Versi Tukang: Atas Nama Customer, Bawah Layanan yang dipilih
              final custName = job.customerName?.isNotEmpty == true
                  ? job.customerName!
                  : 'Customer';
              final serviceLabel = '${job.categoryName ?? "Layanan"} • ${job.title}';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    custName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    serviceLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, color: Colors.white70),
                  ),
                ],
              );
            } else {
              // Versi Customer: Atas Nama Tukang, Bawah Rating Tukang
              final tukangName = job.selectedProviderName?.isNotEmpty == true
                  ? job.selectedProviderName!
                  : 'Mitra Tukang';
              final ratingText = job.selectedProviderRating != null
                  ? '★ ${job.selectedProviderRating!.toStringAsFixed(1)} • Mitra Tukang'
                  : '★ 5.0 • Mitra Tukang';

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tukangName,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    ratingText,
                    style: const TextStyle(fontSize: 11, color: Colors.amberAccent),
                  ),
                ],
              );
            }
          },
        ),
        actions: [
          jobAsync.maybeWhen(
            data: (job) {
              if (job == null || user == null) return const SizedBox.shrink();
              final isProvider = user.id != job.customerId;

              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (job.status == JobStatus.inProgress)
                    IconButton(
                      icon: const Icon(Icons.map, color: Colors.white),
                      tooltip: 'Lacak Posisi Live',
                      onPressed: () => context.push('/tracking?jobId=${job.id}'),
                    ),
                  // Tombol Buat Nota muncul saat status open ATAU locked untuk tukang
                  if (isProvider &&
                      (job.status == JobStatus.open || job.status == JobStatus.locked))
                    TextButton.icon(
                      icon: const Icon(Icons.receipt, color: Colors.white, size: 18),
                      label: const Text(
                        'Buat Nota',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => _showCreateAgreementDialog(job, user.id),
                    ),
                ],
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Banner Status Pekerjaan di Chat
            jobAsync.maybeWhen(
              data: (job) {
                if (job == null) return const SizedBox.shrink();
                Color bg;
                Color fg;
                IconData icon;
                String msg;

                switch (job.status) {
                  case JobStatus.locked:
                    bg = Colors.amber.shade50;
                    fg = Colors.amber.shade900;
                    icon = Icons.lock_outline;
                    msg = 'Status: Tukang Terpilih • Sepakati harga via nota lalu tukang akan mulai bekerja.';
                    break;
                  case JobStatus.inProgress:
                    bg = Colors.purple.shade50;
                    fg = Colors.purple.shade800;
                    icon = Icons.two_wheeler;
                    msg = 'Status: Sedang Dikerjakan • Pelacakan GPS posisi tukang aktif.';
                    break;
                  case JobStatus.done:
                    bg = Colors.green.shade50;
                    fg = Colors.green.shade800;
                    icon = Icons.check_circle_outline;
                    msg = 'Status: Selesai • Menunggu penyelesaian pembayaran langsung (P2P).';
                    break;
                  case JobStatus.paid:
                    bg = Colors.teal.shade50;
                    fg = Colors.teal.shade800;
                    icon = Icons.verified;
                    msg = 'Status: Lunas Disetujui • Transaksi pekerjaan telah tuntas.';
                    break;
                  case JobStatus.cancelled:
                    bg = Colors.red.shade50;
                    fg = Colors.red.shade800;
                    icon = Icons.cancel_outlined;
                    msg = 'Status: Dibatalkan.';
                    break;
                  case JobStatus.open:
                    return const SizedBox.shrink();
                }

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  color: bg,
                  child: Row(
                    children: [
                      Icon(icon, color: fg, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          msg,
                          style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),

            // Section Nota / Price Agreement jika ada
            if (chatState.agreements.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.surfaceVariant,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: chatState.agreements.map((a) {
                    return PriceAgreementCard(agreement: a);
                  }).toList(),
                ),
              )
            else
              jobAsync.maybeWhen(
                data: (job) {
                  if (job == null || user == null) return const SizedBox.shrink();
                  final isProvider = user.id != job.customerId;
                  if (isProvider &&
                      (job.status == JobStatus.open || job.status == JobStatus.locked)) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.amber.shade50,
                      child: Row(
                        children: [
                          const Icon(Icons.receipt_long, color: AppColors.secondary, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Belum ada nota harga. Buat nota untuk mengunci harga dengan customer.',
                              style: TextStyle(fontSize: 12, color: AppColors.textPrimary),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              minimumSize: const Size(80, 32),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () => _showCreateAgreementDialog(job, user.id),
                            child: const Text('Buat Nota', style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                orElse: () => const SizedBox.shrink(),
              ),

            // Chat Messages List
            Expanded(
              child: chatState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : chatState.messages.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.chat_bubble_outline,
                                  size: 48,
                                  color: AppColors.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Mulai Negosiasi',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Diskusikan detail kerusakan, jadwal, dan kesepakatan harga di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(16.0),
                          itemCount: chatState.messages.length,
                          itemBuilder: (ctx, i) {
                            final msg = chatState.messages[i];
                            final isMe = msg.senderId == user?.id;
                            return _MessageBubble(
                              message: msg,
                              isMe: isMe,
                            );
                          },
                        ),
            ),

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: AppColors.border)),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo_camera_outlined, color: AppColors.primary),
                    tooltip: 'Kirim Foto',
                    onPressed: _isSending ? null : _handlePickAndSendImage,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Ketik pesan...',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    icon: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, size: 20),
                    onPressed: _isSending ? null : _handleSendMessage,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMe;

  const _MessageBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  message.senderName!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),

            // Foto Media (Jika Ada)
            if (message.mediaUrl != null && message.mediaUrl!.isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  message.mediaUrl!,
                  width: 220,
                  height: 180,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, err, stack) => Container(
                    width: 220,
                    height: 120,
                    color: Colors.black12,
                    child: const Center(
                      child: Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                  loadingBuilder: (ctx, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 220,
                      height: 180,
                      color: Colors.black12,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                ),
              ),
              if (message.body.isNotEmpty) const SizedBox(height: 6),
            ],

            // Teks Pesan (Jika Ada)
            if (message.body.isNotEmpty)
              Text(
                message.body,
                style: TextStyle(
                  color: isMe ? Colors.white : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),

            const SizedBox(height: 4),

            // Status Ceklis Pesan
            if (isMe)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.done_all,
                    size: 15,
                    color: message.isRead
                        ? Colors.lightBlueAccent.shade100
                        : Colors.white70,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
