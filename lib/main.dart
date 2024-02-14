import 'dart:io';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'Comentsv2.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final keyApplicationId = 'uq3mIDo6JrLvcUXVIr8PUU56gTXbMFtqM2kuPPga';
  final keyClientKey = 'jcYVbSnDf2phLSJJV4RYMb3LgU2t84KUb6vOV0Ge';
  final keyParseServerUrl = 'https://parseapi.back4app.com';
  final keyLiveQueryUrl = 'https://testdatabaseimapsl.b4a.io';

  await Parse().initialize(
    keyApplicationId,
    keyParseServerUrl,
    clientKey: keyClientKey,
    autoSendSessionId: true,
    debug: true,
    liveQueryUrl: keyLiveQueryUrl,
  );

  runApp(MaterialApp(
    title: 'Naprawmy sobie miasto',
    debugShowCheckedModeBanner: false,
    home: MyApp(),
  ));
}

class Zgloszenie {
  final String objectId;
  final String kategoria;
  final String opis;
  final DateTime createdAt;
  late final String status;
  final dynamic? file;
  final String currentUser; // Nowe pole currentUser

  Zgloszenie({
    required this.objectId,
    required this.kategoria,
    required this.opis,
    required this.createdAt,
    required this.status,
    this.file,
    required this.currentUser,
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ZgloszeniaListScreen(),
    );
  }
}

class ZgloszeniaListScreen extends StatefulWidget {
  @override
  _ZgloszeniaListScreenState createState() => _ZgloszeniaListScreenState();
}

class _ZgloszeniaListScreenState extends State<ZgloszeniaListScreen> {
  late List<Zgloszenie> zgloszenia;

  @override
  void initState() {
    super.initState();
    zgloszenia = [];
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      fetchZgloszenia(context);
    });
  }

  Future<void> fetchZgloszenia(BuildContext context) async {
    final QueryBuilder<ParseObject> queryBuilder =
    QueryBuilder<ParseObject>(ParseObject('Zgloszenie'))
      ..orderByDescending('createdAt');

    final response = await queryBuilder.query();

    if (response.success && response.results != null) {
      setState(() {
        zgloszenia = response.results!.map((parseObject) {
          return Zgloszenie(
            objectId: parseObject.objectId!,
            kategoria: parseObject.get<String>('Kategoria') ?? '',
            opis: parseObject.get<String>('Opis') ?? '',
            createdAt:
            parseObject.get<DateTime>('createdAt') ?? DateTime.now(),
            status: parseObject.get<String>('Status') ?? '',
            file: parseObject.get<ParseFile>('file') ?? ParseFile('' as File?),
            currentUser: parseObject.get<String>('currentUser') ?? '',
          );
        }).toList();
      });
    } else {
      print('Błąd podczas pobierania zgłoszeń: ${response.error!.message}');
    }
  }

  void showStatusChangedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pomyślnie zmieniono status'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Zgłoszenia'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              fetchZgloszenia(context);
            },
          ),
        ],
      ),
      body: zgloszenia.isNotEmpty
          ? ListView.builder(
        itemCount: zgloszenia.length,
        itemBuilder: (context, index) {
          final zgloszenie = zgloszenia[index];
          return ListTile(
            title: Text(zgloszenie.kategoria),
            subtitle: Text('Opis: ${zgloszenie.opis}'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FutureBuilder(
                    future: fetchStatusFromDatabase(zgloszenie.objectId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return CircularProgressIndicator();
                      } else {
                        return ZgloszenieDetailsScreen(
                          zgloszenie: zgloszenie,
                          status: snapshot.data as String,
                          onStatusChanged: (newStatus) async {
                            setState(() {
                              zgloszenie.status = newStatus;
                            });

                            await fetchZgloszenia(context);
                          },
                          showStatusChangedSnackBar:
                          showStatusChangedSnackBar,
                        );
                      }
                    },
                  ),
                ),
              );
            },
          );
        },
      )
          : Center(
        child: CircularProgressIndicator(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          fetchZgloszenia(context);
        },
        tooltip: 'Przeładuj',
        child: Icon(Icons.refresh),
      ),
    );
  }

  Future<String> fetchStatusFromDatabase(String objectId) async {
    final QueryBuilder<ParseObject> queryBuilder =
    QueryBuilder<ParseObject>(ParseObject('Zgloszenie'))
      ..whereEqualTo('objectId', objectId);

    final response = await queryBuilder.query();

    if (response.success && response.results != null) {
      final ParseObject parseObject = response.results!.first;
      return parseObject.get<String>('Status') ?? '';
    } else {
      print('Błąd podczas pobierania statusu: ${response.error!.message}');
      return '';
    }
  }
}

class ZgloszenieDetailsScreen extends StatelessWidget {
  final Zgloszenie zgloszenie;
  final String status;
  final void Function(String) onStatusChanged;
  final VoidCallback showStatusChangedSnackBar;

  ZgloszenieDetailsScreen({
    required this.zgloszenie,
    required this.status,
    required this.onStatusChanged,
    required this.showStatusChangedSnackBar,
  });

  String getStatusText() {
    String statusText = 'Brak statusu';

    if (status == '0') {
      statusText = 'Zgłoszenie rozpatrywane';
    } else if (status == '1') {
      statusText = 'Zgłoszenie przyjęte';
    } else if (status == '2') {
      statusText = 'Zgłoszenie odrzucone';
    } else if (status == '3') {
      statusText = 'Zgłoszenie zostało przekazane do wycofania';
    }

    return statusText;
  }

  void changeStatus(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        String selectedStatus = zgloszenie.status;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return AlertDialog(
              title: Text('Zmiana statusu'),
              content: Column(
                children: [
                  ListTile(
                    title: Text('Zgłoszenie rozpatrywane'),
                    leading: Radio(
                      value: '0',
                      groupValue: selectedStatus,
                      onChanged: (String? value) {
                        setState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('Zgłoszenie przyjęte'),
                    leading: Radio(
                      value: '1',
                      groupValue: selectedStatus,
                      onChanged: (String? value) {
                        setState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('Zgłoszenie odrzucone'),
                    leading: Radio(
                      value: '2',
                      groupValue: selectedStatus,
                      onChanged: (String? value) {
                        setState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                  ),
                  ListTile(
                    title: Text('Zgłoszenie zostało przekazane do wycofania'),
                    leading: Radio(
                      value: '3',
                      groupValue: selectedStatus,
                      onChanged: (String? value) {
                        setState(() {
                          selectedStatus = value!;
                        });
                      },
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: Text('Anuluj'),
                ),
                TextButton(
                  onPressed: () async {
                    await saveStatusInDatabase(
                        zgloszenie.objectId, selectedStatus);

                    onStatusChanged(selectedStatus);
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => ZgloszeniaListScreen(),
                      ),
                          (route) => false,
                    );
                    showStatusChangedSnackBar();
                  },
                  child: Text('Zapisz'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> saveStatusInDatabase(
      String objectId, String selectedStatus) async {
    final ParseObject updatedObject = ParseObject('Zgloszenie')
      ..set('objectId', objectId)
      ..set('Status', selectedStatus);

    final response = await updatedObject.save();

    if (!response.success) {
      print('Błąd podczas zapisywania statusu: ${response.error!.message}');
    }
  }

  void askQuestion(BuildContext context) {
    // Add logic to ask a question
    // For example, you can navigate to a new screen
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Szczegóły zgłoszenia'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategoria: ${zgloszenie.kategoria}'),
            Text('Opis: ${zgloszenie.opis}'),
            Text('Data zgłoszenia: ${zgloszenie.createdAt}'),
            Text('Status: ${getStatusText()}'),
            if (zgloszenie.file != null)
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImageFullScreenPage(
                        imageUrl: zgloszenie.file!.url,
                      ),
                    ),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: zgloszenie.file!.url,
                  placeholder: (context, url) => CircularProgressIndicator(),
                  errorWidget: (context, url, error) => Icon(Icons.error),
                ),
              ),
            SizedBox(height: 16),
            Text('Status: $status'),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                ElevatedButton(
                  onPressed: () {
                    changeStatus(context);
                  },
                  child: Text('Zmień status'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(objectId: zgloszenie.objectId),
                      ),
                    );
                  },
                  child: Text('Zadaj pytanie'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ImageFullScreenPage extends StatelessWidget {
  final String imageUrl;

  ImageFullScreenPage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Image.network(
          imageUrl,
          loadingBuilder: (BuildContext context, Widget child,
              ImageChunkEvent? loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                    (loadingProgress.expectedTotalBytes ?? 1)
                    : null,
              ),
            );
          },
        ),
      ),
    );
  }
}
