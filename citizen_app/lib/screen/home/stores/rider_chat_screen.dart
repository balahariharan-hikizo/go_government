import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../utils/app_colors.dart';
import '../../../utils/responsive_helper.dart';
import '../../../bloc/rider_chat/rider_chat_bloc.dart';
import '../../../bloc/rider_chat/rider_chat_event.dart';
import '../../../bloc/rider_chat/rider_chat_state.dart';
import '../../../hive/hive_service.dart';

class RiderChatScreen extends StatefulWidget {
  final String orderId;
  final String riderName;
  final String riderPhone;

  const RiderChatScreen({
    super.key,
    this.orderId = '',
    required this.riderName,
    this.riderPhone = '',
  });

  @override
  State<RiderChatScreen> createState() => _RiderChatScreenState();
}

class _RiderChatScreenState extends State<RiderChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.orderId.isNotEmpty) {
      context.read<RiderChatBloc>().add(InitChatEvent(widget.orderId));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage(BuildContext context) {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final citizenName = HiveService.userName.isNotEmpty
        ? HiveService.userName
        : 'Citizen';

    context.read<RiderChatBloc>().add(
          SendChatMessageEvent(
            text,
            orderId: widget.orderId,
            senderName: citizenName,
          ),
        );
    _messageController.clear();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: BlocConsumer<RiderChatBloc, RiderChatState>(
        listener: (context, state) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_scrollController.hasClients) {
              _scrollController.animateTo(
                _scrollController.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        },
        builder: (context, state) {
          final messages = state.messages;

          return Scaffold(
            backgroundColor: const Color(0xFFF5EFE6), // cream/beige chat bg
            body: Column(
              children: [
                // ── ORANGE HEADER (extends behind status bar) ──────────────
                Container(
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                  ),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top + Responsive.h(8),
                    bottom: Responsive.h(12),
                    left: Responsive.w(16),
                    right: Responsive.w(16),
                  ),
                  child: Row(
                    children: [
                      // Back button
                      GestureDetector(
                        onTap: () {
                          context.read<RiderChatBloc>().add(ClearChatEvent());
                          Navigator.pop(context);
                        },
                        child: Container(
                          width: Responsive.w(38),
                          height: Responsive.w(38),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            borderRadius: BorderRadius.circular(Responsive.w(10)),
                          ),
                          child: Icon(
                            Icons.chevron_left,
                            color: AppColors.black,
                            size: Responsive.w(22),
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.w(12)),

                      // Circular avatar
                      Container(
                        width: Responsive.w(40),
                        height: Responsive.w(40),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.white,
                            width: Responsive.w(2),
                          ),
                        ),
                        child: ClipOval(
                          child: Icon(
                            Icons.person,
                            size: Responsive.w(28),
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      SizedBox(width: Responsive.w(10)),

                      // Name + subtitle
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.riderName,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: Responsive.sp(15),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: Responsive.h(2)),
                            // Text(
                            //   '20k+ orders delivered',
                            //   style: TextStyle(
                            //     color: Colors.white.withValues(alpha: 0.85),
                            //     fontSize: Responsive.sp(11),
                            //   ),
                            // ),
                          ],
                        ),
                      ),

                      // Phone call button
                      GestureDetector(
                        onTap: () async {
                          if (widget.riderPhone.isNotEmpty) {
                            final cleaned = widget.riderPhone.replaceAll(RegExp(r'[^\d+]'), '');
                            final uri = Uri.parse('tel:$cleaned');
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri);
                            }
                          }
                        },
                        child: Container(
                          width: Responsive.w(38),
                          height: Responsive.w(38),
                          decoration: BoxDecoration(
                            color: AppColors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.call,
                            color: AppColors.primary,
                            size: Responsive.w(18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── CHAT MESSAGE LIST ──────────────────────────────────────
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    physics: const BouncingScrollPhysics(),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(16),
                      vertical: Responsive.h(14),
                    ),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final bool isMe = msg['isMe'];

                      return Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: Responsive.h(10)),
                          child: Column(
                            crossAxisAlignment: isMe
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.start,
                            children: [
                              // Bubble
                              Container(
                                constraints: BoxConstraints(
                                  maxWidth:
                                      MediaQuery.of(context).size.width * 0.65,
                                ),
                                padding: EdgeInsets.symmetric(
                                  horizontal: Responsive.w(14),
                                  vertical: Responsive.h(10),
                                ),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.primary
                                      : AppColors.white,
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(Responsive.w(16)),
                                    topRight: Radius.circular(Responsive.w(16)),
                                    bottomLeft: isMe
                                        ? Radius.circular(Responsive.w(16))
                                        : Radius.zero,
                                    bottomRight: isMe
                                        ? Radius.zero
                                        : Radius.circular(Responsive.w(16)),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.05),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  msg['text'],
                                  style: TextStyle(
                                    color:
                                        isMe ? Colors.white : AppColors.black,
                                    fontSize: Responsive.sp(14),
                                  ),
                                ),
                              ),
                              SizedBox(height: Responsive.h(4)),

                              // Timestamp + double tick for sent messages
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    msg['time'],
                                    style: TextStyle(
                                      fontSize: Responsive.sp(10),
                                      color: AppColors.grayFont,
                                    ),
                                  ),
                                  if (isMe) ...[
                                    SizedBox(width: Responsive.w(4)),
                                    Icon(
                                      Icons.done_all,
                                      size: Responsive.w(14),
                                      color: AppColors.primary,
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                // ── INPUT BAR ──────────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: EdgeInsets.only(
                    left: Responsive.w(16),
                    right: Responsive.w(16),
                    top: Responsive.h(10),
                    bottom: MediaQuery.of(context).padding.bottom + Responsive.h(10),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5EFE6),
                      borderRadius: BorderRadius.circular(Responsive.w(28)),
                      border: Border.all(
                        color: const Color(0xFFE0D8CC),
                        width: 1,
                      ),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(16),
                      vertical: Responsive.h(4),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            style: TextStyle(
                              fontSize: Responsive.sp(14),
                              color: AppColors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Type here',
                              hintStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: Responsive.sp(14),
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.symmetric(
                                vertical: Responsive.h(8),
                              ),
                            ),
                            onSubmitted: (_) => _sendMessage(context),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _sendMessage(context),
                          child: Icon(
                            Icons.send,
                            color: AppColors.primary,
                            size: Responsive.w(22),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
