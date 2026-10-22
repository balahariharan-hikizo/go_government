import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/customer_chat/customer_chat_bloc.dart';
import '../../bloc/customer_chat/customer_chat_event.dart';
import '../../bloc/customer_chat/customer_chat_state.dart';
import '../../hive/hive_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/navigation_launcher.dart';
import '../../utils/responsive_helper.dart';
import '../../widget/custom_text.dart';

class CustomerChatScreen extends StatefulWidget {
  final String orderId;
  final String customerName;
  final String customerPhone;

  const CustomerChatScreen({
    super.key,
    required this.orderId,
    required this.customerName,
    this.customerPhone = '',
  });

  @override
  State<CustomerChatScreen> createState() => _CustomerChatScreenState();
}

class _CustomerChatScreenState extends State<CustomerChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.orderId.isNotEmpty) {
      context.read<CustomerChatBloc>().add(InitCustomerChatEvent(widget.orderId));
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final riderName = HiveService.userName.isNotEmpty
        ? HiveService.userName
        : 'Delivery Partner';

    context.read<CustomerChatBloc>().add(
          SendCustomerChatMessageEvent(
            text,
            orderId: widget.orderId,
            senderName: riderName,
          ),
        );

    _messageController.clear();
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
      child: BlocConsumer<CustomerChatBloc, CustomerChatState>(
        listener: (context, state) {
          _scrollToBottom();
        },
        builder: (context, state) {
          final messages = state.messages;

          return Scaffold(
            backgroundColor: const Color(0xFFF5EFE6), // Warm beige chat background
            appBar: AppBar(
              backgroundColor: AppColors.primary,
              elevation: 1,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                onPressed: () {
                  context.read<CustomerChatBloc>().add(ClearCustomerChatEvent());
                  Navigator.pop(context);
                },
              ),
              title: Row(
                children: [
                  Container(
                    width: Responsive.w(38),
                    height: Responsive.w(38),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person, color: AppColors.primary, size: 22),
                  ),
                  SizedBox(width: Responsive.w(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CustomText.title(
                          widget.customerName.isNotEmpty ? widget.customerName : 'Customer',
                          fontSize: Responsive.sp(14),
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        CustomText.caption(
                          'Order #${widget.orderId}',
                          fontSize: Responsive.sp(11),
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                if (widget.customerPhone.isNotEmpty)
                  Padding(
                    padding: EdgeInsets.only(right: Responsive.w(12)),
                    child: IconButton(
                      onPressed: () {
                        NavigationLauncher.callPhoneNumber(widget.customerPhone);
                      },
                      icon: const Icon(Icons.call_rounded, color: Colors.white),
                      tooltip: 'Call Customer',
                    ),
                  ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Quick preset chips for rapid rider texting on the road
                  Container(
                    height: Responsive.h(42),
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(4)),
                    color: Colors.white,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                      children: [
                        _quickChip("I'm on the way! 🛵"),
                        _quickChip('Arrived at your location 📍'),
                        _quickChip('Please come down to gate 🚪'),
                        _quickChip('Please confirm OTP / cash 💵'),
                      ],
                    ),
                  ),

                  // Messages List (Powered by CustomerChatBloc)
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded,
                                    size: 48, color: Colors.grey.shade400),
                                SizedBox(height: Responsive.h(10)),
                                CustomText.body(
                                  'No messages yet.\nSend a message to ${widget.customerName}!',
                                  textAlign: TextAlign.center,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.symmetric(
                              horizontal: Responsive.w(14),
                              vertical: Responsive.h(14),
                            ),
                            itemCount: messages.length,
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final bool isMe = msg['isMe'] == true;

                              return Align(
                                alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                                child: Container(
                                  margin: EdgeInsets.only(bottom: Responsive.h(10)),
                                  constraints: BoxConstraints(
                                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: Responsive.w(14),
                                    vertical: Responsive.h(10),
                                  ),
                                  decoration: BoxDecoration(
                                    color: isMe ? AppColors.primary : Colors.white,
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(Responsive.w(14)),
                                      topRight: Radius.circular(Responsive.w(14)),
                                      bottomLeft: isMe
                                          ? Radius.circular(Responsive.w(14))
                                          : Radius.circular(Responsive.w(2)),
                                      bottomRight: isMe
                                          ? Radius.circular(Responsive.w(2))
                                          : Radius.circular(Responsive.w(14)),
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.05),
                                        blurRadius: 3,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: isMe
                                        ? CrossAxisAlignment.end
                                        : CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        msg['text'] ?? '',
                                        style: TextStyle(
                                          fontSize: Responsive.sp(13.5),
                                          color: isMe ? Colors.white : Colors.black87,
                                        ),
                                      ),
                                      SizedBox(height: Responsive.h(4)),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            msg['time'] ?? '',
                                            style: TextStyle(
                                              fontSize: Responsive.sp(10),
                                              color: isMe
                                                  ? Colors.white.withValues(alpha: 0.75)
                                                  : Colors.grey.shade600,
                                            ),
                                          ),
                                          if (isMe) ...[
                                            SizedBox(width: Responsive.w(4)),
                                            Icon(
                                              Icons.done_all_rounded,
                                              size: Responsive.w(13),
                                              color: Colors.white.withValues(alpha: 0.9),
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

                  // Bottom Message Input Bar
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: Responsive.w(12),
                      vertical: Responsive.h(10),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, -2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: Responsive.w(14)),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F3F4),
                              borderRadius: BorderRadius.circular(Responsive.w(24)),
                            ),
                            child: TextField(
                              controller: _messageController,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: const InputDecoration(
                                hintText: 'Type a message to customer...',
                                hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        GestureDetector(
                          onTap: _sendMessage,
                          child: Container(
                            width: Responsive.w(44),
                            height: Responsive.w(44),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _quickChip(String text) {
    return Padding(
      padding: EdgeInsets.only(right: Responsive.w(6)),
      child: ActionChip(
        label: Text(text, style: TextStyle(fontSize: Responsive.sp(11.5))),
        backgroundColor: const Color(0xFFF1F3F4),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        onPressed: () {
          _messageController.text = text;
          _sendMessage();
        },
      ),
    );
  }
}
