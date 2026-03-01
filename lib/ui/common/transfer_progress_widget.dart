import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../../function/transfer/transfer_manager.dart';

class TransferProgressWidget extends StatefulWidget {
  final TransferType type; // 仅显示特定类型的任务 (上传/下载)

  const TransferProgressWidget({
    super.key,
    required this.type,
  });

  @override
  State<TransferProgressWidget> createState() => _TransferProgressWidgetState();
}

class _TransferProgressWidgetState extends State<TransferProgressWidget> {
  @override
  void initState() {
    super.initState();
    TransferManager().addListener(_onUpdate);
  }

  @override
  void dispose() {
    TransferManager().removeListener(_onUpdate);
    super.dispose();
  }

  void _onUpdate() {
    if (mounted) setState(() {});
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final tasks = TransferManager().tasks.where((t) => t.type == widget.type).toList();

    if (tasks.isEmpty) return const SizedBox.shrink();

    return Container(
      constraints: const BoxConstraints(maxHeight: 150),
      decoration: BoxDecoration(
        color: TDTheme.of(context).whiteColor1,
        border: Border(
          top: BorderSide(color: TDTheme.of(context).grayColor3),
        ),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.all(8),
        itemCount: tasks.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final task = tasks[index];
          final progress = task.progress;
          final isIndeterminate = task.totalBytes == 0;

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      task.type == TransferType.upload ? TDIcons.upload : TDIcons.download,
                      size: 14,
                      color: TDTheme.of(context).brandNormalColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TDText(
                        task.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: TDTheme.of(context).textColorPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TDText(
                      task.status == TransferStatus.completed
                          ? '完成'
                          : task.status == TransferStatus.failed
                              ? '失败'
                              : isIndeterminate
                                  ? _formatBytes(task.transferredBytes)
                                  : '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10,
                        color: task.status == TransferStatus.failed
                            ? TDTheme.of(context).errorNormalColor
                            : TDTheme.of(context).grayColor6,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (task.status == TransferStatus.running || task.status == TransferStatus.pending)
                  LinearProgressIndicator(
                    value: isIndeterminate ? null : progress,
                    backgroundColor: TDTheme.of(context).grayColor2,
                    color: TDTheme.of(context).brandNormalColor,
                    minHeight: 2,
                  ),
                if (task.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: TDText(
                      task.error!,
                      style: TextStyle(
                        fontSize: 10,
                        color: TDTheme.of(context).errorNormalColor,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
