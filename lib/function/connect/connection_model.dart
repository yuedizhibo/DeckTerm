enum ConnectionType {
  ssh,
  vnc,
}

enum AuthMethod {
  password,
  privateKey,
}

class Connection {
  String id;
  String name;
  ConnectionType type;
  String host;
  int port;
  String? note;
  AuthMethod authMethod;
  String? username;
  String? password;
  String? privateKeyPath;

  Connection({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    required this.port,
    this.note,
    required this.authMethod,
    this.username,
    this.password,
    this.privateKeyPath,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'host': host,
      'port': port,
      'note': note,
      'authMethod': authMethod.index,
      'username': username,
      'password': password,
      'privateKeyPath': privateKeyPath,
    };
  }

  factory Connection.fromJson(Map<String, dynamic> json) {
    return Connection(
      id: json['id'],
      name: json['name'],
      type: ConnectionType.values[json['type']],
      host: json['host'],
      port: json['port'],
      note: json['note'],
      authMethod: AuthMethod.values[json['authMethod']],
      username: json['username'],
      password: json['password'],
      privateKeyPath: json['privateKeyPath'],
    );
  }
  
  Connection copyWith({
    String? id,
    String? name,
    ConnectionType? type,
    String? host,
    int? port,
    String? note,
    AuthMethod? authMethod,
    String? username,
    String? password,
    String? privateKeyPath,
  }) {
    return Connection(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      host: host ?? this.host,
      port: port ?? this.port,
      note: note ?? this.note,
      authMethod: authMethod ?? this.authMethod,
      username: username ?? this.username,
      password: password ?? this.password,
      privateKeyPath: privateKeyPath ?? this.privateKeyPath,
    );
  }
}
