import 'dart:async';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:moor/isolate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';

import 'bg_task.dart';
import 'demo_data.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moor Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: FutureBuilder<String>(
        future: getApplicationDocumentsDirectory()
          .then((d) => join(d.path, 'demo_db.sqlite')),
        builder: (_, snapshot) => snapshot.hasData
          ? MyHomePage(
            title: 'Moor Demo',
            databasePath: snapshot.data,
          )
          : Container(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title, this.databasePath}) : super(key: key);

  final String title;
  final String databasePath;

  @override
  State<StatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _dbCompleter = Completer<DemoDatabase>();
  DemoDatabase _db;
  Isolate _isolate;
  MoorIsolate _moorIsolate;
  // SendPort _sendPort;
  int _count;

  @override
  void initState() {
    super.initState();
    // _db = DemoDatabase(VmDatabase(File(widget.databasePath),
    //   logStatements: true,
    // ));
    _initDb();
  }

  @override
  void dispose() {
    _db?.close();
    _isolate?.kill();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            onPressed: _increaseCounter,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            onPressed: _increaseViaCompute,
            icon: const Icon(Icons.flare),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              'You have pushed the button this many times:',
            ),
            _buildCountText(),
          ],
        ),
      ),
    );
  }

  Widget _buildCountText() => FutureBuilder<DemoDatabase>(
    future: _dbCompleter.future,
    builder: (_, snapshot) => snapshot.hasData
      ? StreamBuilder<int>(
        stream: snapshot.data.watchFirstCounter(),
        builder: (context, snapshot) {
          if (snapshot.hasData) _count = snapshot.data;

          return Text(
            snapshot.data?.toString() ?? '…',
            style: Theme.of(context).textTheme.headline4,
          );
        },
      )
      : const SizedBox(),
  );

  void _initDb() async {
    final info = await createMoorIsolate();
    _isolate = info.isolate;
    _moorIsolate = info.moorIsolate;
    // _sendPort = info.sendPort;
    _db = DemoDatabase.connect(await _moorIsolate.connect(isolateDebugLog: true));
    _dbCompleter.complete(_db);
  }

  void _increaseCounter() async {
    (await _dbCompleter.future)?.updateFirstCounter((_count ?? 0) + 1);
  }

  void _increaseViaCompute() {
    if (_moorIsolate != null) countViaCompute(_moorIsolate.connectPort);
  }
}
