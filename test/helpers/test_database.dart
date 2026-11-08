import 'package:daily_rhythm/shared/services/database/database_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

bool _factorySet = false;

/// Points [DatabaseService.instance] at a fresh database and returns it.
///
/// Uses the in-process FFI factory so queries also complete inside widget
/// tests' fake-async zone. Pass [path] to open a prepared database file.
Future<DatabaseService> openTestDatabase({String path = inMemoryDatabasePath}) async {
  if (!_factorySet) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfiNoIsolate;
    _factorySet = true;
  }
  await DatabaseService.instance.close();
  DatabaseService.databasePathOverride = path;
  await DatabaseService.instance.database;
  return DatabaseService.instance;
}

Future<void> closeTestDatabase() async {
  await DatabaseService.instance.close();
  DatabaseService.databasePathOverride = null;
}
