import 'dart:async';
import 'dart:math';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../network/rider_api_service.dart';
import '../../service/socket_service.dart';
import 'customer_chat_event.dart';
import 'customer_chat_state.dart';

class CustomerChatBloc extends Bloc<CustomerChatEvent, CustomerChatState> {
  StreamSubscription? _chatSub;

  CustomerChatBloc() : super(CustomerChatState.initial()) {
    on<InitCustomerChatEvent>((event, emit) async {
      _chatSub?.cancel();
      // 1. Immediately reset state so previous order messages never leak
      emit(CustomerChatState.initial());

      if (event.orderId.isNotEmpty) {
        // 2. Fetch persistent chat history for this specific order from DB
        try {
          final history = await RiderApiService.fetchOrderChat(event.orderId);
          final formatted = history.map((m) {
            final senderRole = m['senderRole']?.toString() ?? 'rider';
            return {
              'id': m['id']?.toString() ?? '',
              'text': m['text']?.toString() ?? '',
              'time': m['time']?.toString() ?? '',
              'isMe': (senderRole == 'rider'),
              'senderRole': senderRole,
            };
          }).toList();
          emit(state.copyWith(messages: formatted));
        } catch (_) {}

        // 3. Subscribe to live WebSocket relay for this order
        RiderSocketService().subscribeToChat(event.orderId);
        _chatSub = RiderSocketService().onChatMessage.listen((data) {
          final incomingOrderId = data['orderId']?.toString();
          if (incomingOrderId == event.orderId) {
            add(ReceiveCustomerChatMessageEvent(data));
          }
        });
      }
    });

    on<SendCustomerChatMessageEvent>((event, emit) {
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
        'senderRole': 'rider',
        'senderName': event.senderName,
        'time': timeStr,
      };

      // 1. Emit live chat packet via WebSocket
      if (event.orderId.isNotEmpty) {
        RiderSocketService().sendChatMessage(messagePayload);
      }

      // 2. Add to local UI messages as 'isMe: true'
      final updatedList = List<Map<String, dynamic>>.from(state.messages);
      updatedList.add({
        'id': msgId,
        'text': event.text,
        'time': timeStr,
        'isMe': true,
        'senderRole': 'rider',
      });
      emit(state.copyWith(messages: updatedList));
    });

    on<ReceiveCustomerChatMessageEvent>((event, emit) {
      final msg = event.message;
      final senderRole = msg['senderRole']?.toString() ?? '';
      final msgId = msg['id']?.toString() ?? '';

      // Only append if it's from citizen (ignore own rider echo)
      if (senderRole == 'citizen') {
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
          'senderRole': 'citizen',
        });
        emit(state.copyWith(messages: updatedList));
      }
    });

    on<ClearCustomerChatEvent>((event, emit) {
      _chatSub?.cancel();
      emit(CustomerChatState.initial());
    });
  }

  @override
  Future<void> close() {
    _chatSub?.cancel();
    return super.close();
  }
}
