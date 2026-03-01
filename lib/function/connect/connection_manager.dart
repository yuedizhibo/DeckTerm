import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'connection_model.dart';

class ConnectionManager {
  static final ConnectionManager _instance = ConnectionManager._internal();
  factory ConnectionManager() => _instance;
  ConnectionManager._internal();

  static const String _storageKey = 'saved_connections';
  List<Connection> _connections = [];

  List<Connection> get connections => _connections;

  Future<void> loadConnections() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_storageKey);
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      _connections = jsonList.map((e) => Connection.fromJson(e)).toList();
    }
  }

  Future<void> saveConnection(Connection connection) async {
    final index = _connections.indexWhere((c) => c.id == connection.id);
    if (index >= 0) {
      _connections[index] = connection;
    } else {
      _connections.add(connection);
    }
    await _persist();
  }

  Future<void> deleteConnection(String id) async {
    _connections.removeWhere((c) => c.id == id);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final String data = jsonEncode(_connections.map((c) => c.toJson()).toList());
    await prefs.setString(_storageKey, data);
  }
}
