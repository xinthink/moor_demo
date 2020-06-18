import 'package:moor/moor.dart';

// assuming that your file is called filename.dart. This will give an error at first,
// but it's needed for moor to know about the generated code
part 'demo_data.g.dart';

// this will generate a table called "todos" for us. The rows of that table will
// be represented by a class called "Todo".
class Todos extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text().withLength(min: 6, max: 32)();
  TextColumn get content => text().named('body')();
  IntColumn get category => integer().nullable()();
}

// This will make moor generate a class called "Category" to represent a row in this table.
// By default, "Categorie" would have been used because it only strips away the trailing "s"
// in the table name.
@DataClassName("Category")
class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get description => text()();
}

class Counters extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get count => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

// this annotation tells moor to prepare a database class that uses both of the
// tables we just defined. We'll see how to use that database class in a moment.
@UseMoor(tables: [Counters, Todos, Categories])
class DemoDatabase extends _$DemoDatabase {
  DemoDatabase(QueryExecutor e) : super(e);

  DemoDatabase.connect(DatabaseConnection connection) : super.connect(connection);

  @override
  int get schemaVersion => 1;

  Stream<int> watchFirstCounter() =>
    (select(counters)..limit(1)).map((c) => c.count).watchSingle();

  Future<void> updateFirstCounter(int count) async {
    await into(counters).insertOnConflictUpdate(Counter(id: 1, count: count));
  }
}
