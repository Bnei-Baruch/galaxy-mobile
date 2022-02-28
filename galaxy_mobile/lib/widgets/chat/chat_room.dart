
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:galaxy_mobile/models/chat_message.dart';
import 'package:galaxy_mobile/models/mainStore.dart';
import 'package:galaxy_mobile/viewmodels/chat_view_model.dart';
import 'package:galaxy_mobile/widgets/chat/chat_message_bubble.dart';
import 'package:galaxy_mobile/widgets/chat/send_chat_message_bar.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatRoom extends StatefulWidget {
  final ChatViewModel chatViewModel;

  ChatRoom({this.chatViewModel});

  @override
  _ChatRoomState createState() => _ChatRoomState();
}

class _ChatRoomState extends State<ChatRoom> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  Timer _unreadMessagesTimer;
  bool _showUnreadMessages = false;
  bool _canPublishNewMessage = false;
  int _messagesCount = 0;

  void _sendNewChatMessage(String content) {
    ChatViewModel model = widget.chatViewModel;
    if (model.canPublishNewMessage) {
      MainStore mainStore = context.read<MainStore>();
      ChatMessage message =
        ChatMessage(
            mainStore.activeUser.id,
            mainStore.activeUser.name,
            ChatMessageSender.ACTIVE_USER,
            content,
            // TODO: doesn't MQTT publish the timestamp rather than the client?
            DateTime.now().millisecondsSinceEpoch);
      model.publishNewChatMessage(message);
    }
  }

  // Returns whether there's a scroll will be made in the next frame.
  bool _updateScroll({bool forceScroll = false}) {
    bool scrollToBottomOnNextFrame = false;
    if (forceScroll == true) {
      scrollToBottomOnNextFrame = true;
    } else {
      final dummyItemIndex = widget.chatViewModel.chatMessages.length + 1;
      // Remove info item or dummy item.
      Iterable<ItemPosition> messagePositions = _itemPositionsListener.itemPositions.value
          .where((item) => item.index != 0 && item.index != dummyItemIndex);
      if (messagePositions.length == 0) {
        return false;
      }
      ItemPosition latestVisibleMessage =
      messagePositions
          .where((item) => item.index != 0 && item.index != dummyItemIndex)
          .reduce((prev, current) => prev.index > current.index ? prev : current);

      if (latestVisibleMessage.itemTrailingEdge < 1.1
          && latestVisibleMessage.index >= widget.chatViewModel.chatMessages.length - 1) {
        scrollToBottomOnNextFrame = true;
      }
    }

    if (scrollToBottomOnNextFrame) {
      WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
        if (_itemScrollController.isAttached) {
          _itemScrollController.jumpTo(
            // The dummy item is at length + 1, and we want to align its top with the bottom of the viewport.
              index: widget.chatViewModel.chatMessages.length + 1,
              alignment: 1);
        }
      });
    }

    return scrollToBottomOnNextFrame;
  }

  void _onViewModelChange({bool forceScroll = false}) {
    bool willScrollNextFrame = false;
    if (widget.chatViewModel.chatMessages.length != _messagesCount) {
      willScrollNextFrame = _updateScroll(forceScroll: forceScroll);
    }

    setState(() {
      _messagesCount = widget.chatViewModel.chatMessages.length;
      _canPublishNewMessage = widget.chatViewModel.canPublishNewMessage;
      // if we scroll we won't show the unread messages.
      _showUnreadMessages = !willScrollNextFrame;
    });
  }

  void _updateLastSeenItem() {
    final dummyItemIndex = widget.chatViewModel.chatMessages.length + 1;
    // Remove info item or dummy item.
    Iterable<ItemPosition> messagePositions = _itemPositionsListener.itemPositions.value
        .where((item) => item.index != 0 && item.index != dummyItemIndex);
    if (messagePositions.length == 0) {
      return;
    }
    int bottomVisibleMessageIndex = messagePositions
        .fold(-1, (prev, item) => max(prev, item.index));

    if (bottomVisibleMessageIndex - 1 > widget.chatViewModel.lastSeenMessageIndex) {
      widget.chatViewModel.setReadUpToMessageIndex(bottomVisibleMessageIndex - 1);
    }
  }

  @override
  void didUpdateWidget(ChatRoom oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatViewModel != widget.chatViewModel) {
      oldWidget.chatViewModel.removeListener(_onViewModelChange);
      widget.chatViewModel.addListener(_onViewModelChange);
    }
  }

  @override
  void initState() {
    super.initState();
    _onViewModelChange(forceScroll: true);
    widget.chatViewModel.addListener(_onViewModelChange);
    _itemPositionsListener.itemPositions.addListener(_updateLastSeenItem);

    _unreadMessagesTimer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (widget.chatViewModel.unreadMessagesCount > 0) {
        setState(() {
          _showUnreadMessages = true;
        });
      } else {
        setState(() {
          _showUnreadMessages = false;
        });
      }
    });
  }

  @override
  void dispose() {
    widget.chatViewModel.removeListener(_onViewModelChange);
    _itemPositionsListener.itemPositions.removeListener(_updateLastSeenItem);
    _unreadMessagesTimer.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    List<ChatMessage> _chatMessages = widget.chatViewModel.chatMessages;
    // +1 for initial info message.
    // +1 for mock element that allows to be scrolled to for workaround to https://github.com/google/flutter.widgets/issues/99
    final itemCount = _chatMessages.length + 2;


    return Container(
      color: Colors.black,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
            Expanded(
              child: Stack(children: <Widget>[
                 Container(
                    padding: EdgeInsets.fromLTRB(8, 0, 8, 4),
                    child: ScrollablePositionedList.builder(
                      itemScrollController: _itemScrollController,
                      itemPositionsListener: _itemPositionsListener,
                      itemCount: itemCount,
                      itemBuilder: (BuildContext context, int index) {
                        // Info message item.
                        if (index == 0) {
                          return Container(
                              decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.all(
                                      Radius.circular(6))
                              ),
                              padding: EdgeInsets.all(10.0),
                              margin: EdgeInsets.symmetric(horizontal: 16.0,
                                  vertical: 8.0),
                              child: Text('virtual_chat.msgRoomInfo'.tr(),
                                  style: TextStyle(color: Colors.black)
                              )
                          );
                        }
                        // Dummy last item for scroll alignment issue.
                        if (index == itemCount - 1) {
                          return Container();
                        }
                        // Message item.
                        final messageIndex = index - 1;
                        return ChatMessageBubble(
                            isFirstInThread: messageIndex == 0
                                || (_chatMessages[messageIndex].senderId != _chatMessages[messageIndex - 1].senderId),
                            chatMessage: _chatMessages[messageIndex]);
                      },
                    )

                ),
                if (_showUnreadMessages && widget.chatViewModel.unreadMessagesCount > 0) Positioned(
                    right: 10,
                    bottom: 15,
                    child: FloatingActionButton.extended(
                        backgroundColor: Color(0xFF0062B0),
                        onPressed: () => _updateScroll(forceScroll: true),
                        label: Text(widget.chatViewModel.unreadMessagesCount.toString()),
                        icon: Icon(Icons.keyboard_arrow_down),
                    )
                )
              ]
            )
          ),
          SendChatMessageBar(
              enabled: _canPublishNewMessage,
              onMessageSent: _sendNewChatMessage)
        ]
      )
    );
  }
}
