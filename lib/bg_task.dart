import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:moor/isolate.dart';
import 'package:moor/moor.dart';
import 'package:moor_ffi/moor_ffi.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'demo_data.dart';

Future<void> countViaCompute(SendPort sendPort) async {
  // final dir = await getApplicationDocumentsDirectory();
  // final dbPath = join(dir.path, 'demo_db.sqlite');
  try {
    await compute(_updateCounterInBackground, [sendPort, 100], debugLabel: 'counter');
  } catch (e, s) {
    debugPrint('update counter in background failed: $e $s');
  }
}

Future<void> _updateCounterInBackground(dynamic args) async {
  final sendPort = args[0] as SendPort;
  int count = args[1] ?? 100;
  DemoDatabase db;
  try {
    db = DemoDatabase.connect(await MoorIsolate.fromConnectPort(sendPort).connect(isolateDebugLog: true));
    // db = DemoDatabase(VmDatabase(File(dbPath), logStatements: true));
    await db.updateFirstCounter(count);
  } finally {
    db?.close();
  }
}

Future<BgIsolate> createMoorIsolate() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbPath = join(dir.path, 'demo_db.sqlite');
  final receivePort = ReceivePort();
  final isolate = await Isolate.spawn(_initBg, _BgOptions(receivePort.sendPort, dbPath));
  final info = await receivePort.first as List;
  return BgIsolate(isolate, info[0], info[1]);
}

void _initBg(_BgOptions opts) async {
  final receivePort = ReceivePort();
  final sendPort = opts.sendPort;
  final executor = VmDatabase(File(opts.dbPath), logStatements: true);
  final moorIsolate = MoorIsolate.inCurrent(() => DatabaseConnection.fromExecutor(executor));
  sendPort.send([moorIsolate, receivePort.sendPort]);

  // final db = DemoDatabase.connect(await MoorIsolate.fromConnectPort(moorIsolate.connectPort).connect(isolateDebugLog: true));
  // receivePort.listen((message) {
  //   if (message is String && message == 'updateCounter') {
  //     db.updateFirstCounter(200);
  //   }
  // });
}

class _BgOptions {
  final SendPort sendPort;
  final String dbPath;

  const _BgOptions(this.sendPort, this.dbPath);
}

class BgIsolate {
  final Isolate isolate;
  final MoorIsolate moorIsolate;
  final SendPort sendPort;

  const BgIsolate(this.isolate, this.moorIsolate, this.sendPort);
}
