/// 终端会话类型
enum TerminalType {
  /// SSH 连接
  ssh,

  /// VNC 连接
  vnc,
}

/// 终端会话数据模型
class TerminalSession {
  /// 会话唯一标识
  final String id;

  /// 会话名称（标签显示）
  final String name;

  /// 会话类型
  final TerminalType type;

  /// 主机地址
  final String host;

  /// 端口
  final int port;

  /// 用户名
  final String? username;

  /// 密码
  final String? password;

  /// 私钥路径
  final String? privateKeyPath;

  /// 是否已连接
  bool isConnected;

  TerminalSession({
    required this.id,
    required this.name,
    required this.type,
    required this.host,
    this.port = 22,
    this.username,
    this.password,
    this.privateKeyPath,
    this.isConnected = false,
  });

  /// 从 JSON 创建会话
  factory TerminalSession.fromJson(Map<String, dynamic> json) {
    return TerminalSession(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: TerminalType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TerminalType.ssh,
      ),
      host: json['host'] ?? '',
      port: json['port'] ?? 22,
      username: json['username'],
      password: json['password'],
      privateKeyPath: json['privateKeyPath'],
      isConnected: json['isConnected'] ?? false,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'host': host,
      'port': port,
      'username': username,
      'password': password,
      'privateKeyPath': privateKeyPath,
      'isConnected': isConnected,
    };
  }

  /// 获取连接字符串显示
  String get connectionString => '$host:$port';

  /// 获取类型显示文本
  String get typeDisplay => type == TerminalType.ssh ? 'SSH' : 'VNC';
}
