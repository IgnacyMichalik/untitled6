import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'main.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Parse().initialize(
    'uq3mIDo6JrLvcUXVIr8PUU56gTXbMFtqM2kuPPga',
    'https://parseapi.back4app.com',
    clientKey: 'jcYVbSnDf2phLSJJV4RYMb3LgU2t84KUb6vOV0Ge',
    autoSendSessionId: true,
    liveQueryUrl: 'https://testdatabaseimapsl.b4a.io', // Updated liveQueryUrl to the correct value
    debug: true,
  );
  runApp(Comments(objectId: '',));
}

class Comments extends StatelessWidget {
  final String objectId;
  const Comments({
    required this.objectId, // Przekazanie objectId w konstruktorze
  });

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Komentarze',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      routes: {
        '/chat_screen': (context) => ChatScreen(objectId: objectId),
      },
    );
  }
}

class ChatScreen extends StatefulWidget {
  final String objectId;

  ChatScreen({required this.objectId});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late Subscription<ParseObject> subscription;
  List<ParseObject> _messages = [];
  late TextEditingController _messageController;

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController();
    initializeLiveQuery();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final currentRoute = ModalRoute.of(context)?.settings.name;

    if (currentRoute == '/chat_screen') {
      markMessagesAsRead();
    }
  }

  Future<void> initializeLiveQuery() async {
    final queryBuilder = QueryBuilder<ParseObject>(ParseObject('Message'))
      ..whereEqualTo('idZgloszenia', widget.objectId);

    try {
      final response = await queryBuilder.query();
      final results = response.results;

      if (results != null && results.isNotEmpty) {
        setState(() {
          _messages.addAll(results.cast<ParseObject>());
        });
      }

      subscription = await LiveQuery().client.subscribe(queryBuilder);
      subscription.on(LiveQueryEvent.create, (value) {
        setState(() {
          _messages.add(value);
        });
      });
    } catch (e) {
      print('Error initializing LiveQuery: $e');
    }
  }

  Future<void> sendMessage(String text) async {
    final newMessage = ParseObject('Message')
      ..set('text', text)
      ..set('senderId', 'admin_id')
      ..set('receiverId', 'user_id')
      ..set('idZgloszenia', widget.objectId)
      ..set('isRead', '1'); // Status ustawiony na '1' (nieprzeczytana)

    try {
      await newMessage.save();
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> markMessagesAsRead() async {
    for (var message in _messages) {
      if (message['isRead'] == '0') {
        message['isRead'] = '1'; // Zmiana statusu na '1' (przeczytana) w aplikacji

        try {
          final updatedMessage = ParseObject('Message')
            ..objectId = message.objectId // Ustawienie objectId dla istniejącego obiektu ParseObject
            ..set('isRead', '1'); // Ustawienie kolumny isRead na '1' (przeczytana) w bazie danych

          await updatedMessage.save();
          setState(() {
            // Odświeżenie widoku w przypadku zmiany statusu wiadomości
          });
        } catch (e) {
          print('Błąd podczas oznaczania wiadomości jako przeczytane: $e');
        }
      }
    }
  }

  Future<void> unsubscribeLiveQuery() async {
    try {
      LiveQuery().client.unSubscribe(subscription);
    } catch (e) {
      print('Error unsubscribing from LiveQuery: $e');
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    unsubscribeLiveQuery();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightGreen,
        title: Text('Komentarze do zgłoszenia'),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (BuildContext context, int index) {
                final message = _messages[index];
                final isUser = message['senderId'] == 'user_id';
                final sender = isUser ? 'Użytkownik' : 'Urzędnik'; // Zaktualizowany tekst nad wiadomością

                if (!isUser && message['isRead'] == '0') {
                  markMessagesAsRead(); // Oznacz wiadomość jako przeczytaną
                }

                return Column(
                  crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '$sender', // Aktualizacja tekstu nad wiadomością
                      style: TextStyle(fontSize: 12.0, color: Colors.grey),
                    ),
                    Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                        padding: EdgeInsets.all(8.0),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blue : Colors.grey,
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          message['text'],
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Divider(height: 1.0),
          Container(
            margin: EdgeInsets.all(8.0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: 'Napisz wiadomość',
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send),
                  onPressed: () {
                    String message = _messageController.text;
                    if (message.isNotEmpty) {
                      sendMessage(message);
                      _messageController.clear();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}