class Message {
  final String content;
  final DateTime timestamp;
  final bool isSentByMe;

  Message({
    required this.content,
    required this.timestamp,
    required this.isSentByMe,
  });
}
