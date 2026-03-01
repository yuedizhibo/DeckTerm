import 'package:flutter/foundation.dart';

enum TransferType {
  upload,
  download,
}

enum TransferStatus {
  pending,
  running,
  completed,
  failed,
}

class TransferTask {
  final String id;
  final String name; // 文件名
  final String sourcePath;
  final String destPath;
  final TransferType type;
  final int totalBytes;
  
  int transferredBytes;
  TransferStatus status;
  String? error;

  TransferTask({
    required this.id,
    required this.name,
    required this.sourcePath,
    required this.destPath,
    required this.type,
    required this.totalBytes,
    this.transferredBytes = 0,
    this.status = TransferStatus.pending,
  });

  double get progress => totalBytes == 0 ? 0 : transferredBytes / totalBytes;
}

class TransferManager extends ChangeNotifier {
  static final TransferManager _instance = TransferManager._internal();
  factory TransferManager() => _instance;
  TransferManager._internal();

  // 任务列表
  final List<TransferTask> _tasks = [];
  
  List<TransferTask> get tasks => List.unmodifiable(_tasks);

  // 添加任务
  TransferTask addTask(String name, String source, String dest, TransferType type, int totalBytes) {
    final task = TransferTask(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      sourcePath: source,
      destPath: dest,
      type: type,
      totalBytes: totalBytes,
    );
    _tasks.add(task);
    notifyListeners();
    return task;
  }

  // 更新进度
  void updateProgress(String taskId, int transferred) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].transferredBytes = transferred;
      _tasks[index].status = TransferStatus.running;
      notifyListeners();
    }
  }

  // 完成任务
  void completeTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].transferredBytes = _tasks[index].totalBytes;
      _tasks[index].status = TransferStatus.completed;
      notifyListeners();
      
      // 延迟移除已完成任务，以便 UI 展示“完成”状态
      Future.delayed(const Duration(seconds: 3), () {
        _tasks.removeWhere((t) => t.id == taskId);
        notifyListeners();
      });
    }
  }

  // 任务失败
  void failTask(String taskId, String error) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      _tasks[index].status = TransferStatus.failed;
      _tasks[index].error = error;
      notifyListeners();
    }
  }
}
