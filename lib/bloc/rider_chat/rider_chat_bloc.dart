import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/order_api_service.dart';
import '../../service/socket_service.dart';
import 'rider_chat_event.dart';
import 'rider_chat_state.dart';

class RiderChatBloc extends Bloc<RiderChatEvent, RiderChatState> {
  StreamSubscription? _chatSub;

  RiderChatBloc() : super(RiderChatState.initial()) {
    on<InitChatEvent>((event, emit) async {
      _chatSub?.cancel();
      // 1. Immediately reset state so previous order messages never leak
      emit(RiderChatState.initial());

      if (event.orderId.isNotEmpty) {
        // 2. Fetch persistent chat history for this specific order from DB
        try {
          final history = await OrderApiService.fetchOrderChat(event.orderId);
          final formatted = history.map((m) {
            final senderRole = m['senderRole']?.toString() ?? 'citizen';
            return {
              'id': m['id']?.toString() ?? '',
              'text': m['text']?.toString() ?? '',
              'time': m['time']?.toString() ?? '',
              'isMe': (senderRole == 'citizen'),
              'senderRole': senderRole,
            };
          }).toList();
          emit(state.copyWith(messages: formatted));
        } catch (_) {}

        // 3. Subscribe to live WebSocket relay for this order
        SocketService().subscribeToOrder(event.orderId);
        _chatSub = SocketService().onChatMessage.listen((data) {
          final incomingOrderId = data['orderId']?.toString();
          if (incomingOrderId == event.orderId) {
            add(ReceiveChatMessageEvent(data));
          }
        });
      }
    });

    on<SendChatMessageEvent>((event, emit) {
      final now = DateTime.now();
      final hour = now.hour > 12 ? now.hour - 12 : (now.hour == 0 ? 12 : now.hour);
      final minute = now.minute.toString().padLeft(2, '0');
      final period = now.hour >= 12 ? 'pm' : 'am';
      final timeStr = '$hour:$minute $period';
      final msgId = 'msg_${now.millisecondsSinceEpoch}_${Random().nextInt(99999)}';

      final messagePayload = {
        'id': msgId,
        'orderId': event.orderId,
        'text': event.text,
        'senderRole': 'citizen',
        'senderName': event.senderName,
        'time': timeStr,
      };

      // 1. Emit live chat packet via WebSocket
      if (event.orderId.isNotEmpty) {
        SocketService().sendChatMessage(messagePayload);
      }

      // 2. Append to local state
      final updatedList = List<Map<String, dynamic>>.from(state.messages);
      updatedList.add({
        'id': msgId,
        'text': event.text,
        'time': timeStr,
        'isMe': true,
        'senderRole': 'citizen',
      });
      emit(state.copyWith(messages: updatedList));
    });

    on<ReceiveChatMessageEvent>((event, emit) {
      final msg = event.message;
      final senderRole = msg['senderRole']?.toString() ?? '';
      final msgId = msg['id']?.toString() ?? '';

      // Only append if it's from rider (ignore own echo)
      if (senderRole == 'rider') {
        // Prevent duplicate bubbles if received multiple times
        if (msgId.isNotEmpty && state.messages.any((m) => m['id'] == msgId)) {
          return;
        }

        final updatedList = List<Map<String, dynamic>>.from(state.messages);
        updatedList.add({
          'id': msgId,
          'text': msg['text']?.toString() ?? '',
          'time': msg['time']?.toString() ?? '',
          'isMe': false,
          'senderRole': 'rider',
        });
        emit(state.copyWith(messages: updatedList));
      }
    });

    on<ClearChatEvent>((event, emit) {
      _chatSub?.cancel();
      emit(RiderChatState.initial());
    });
  }

  @override
  Future<void> close() {
    _chatSub?.cancel();
    return super.close();
  }
}
