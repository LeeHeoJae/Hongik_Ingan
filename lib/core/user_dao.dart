import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UserDao {
  final storage = FlutterSecureStorage();
  void save(String id, String pw) async{
    await storage.write(key: 'id', value: id.toUpperCase());
    await storage.write(key: 'pw', value: pw);
  }
  Future<(String?, String?)> load() async{
    String? id = await storage.read(key: 'id');
    String? pw = await storage.read(key: 'pw');
    return (id,pw);
  }
}