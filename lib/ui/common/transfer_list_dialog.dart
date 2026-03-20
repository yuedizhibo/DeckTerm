import 'package:flutter/material.dart';
import '../../function/transfer/transfer_manager.dart';
import '../../setting/app_theme.dart';

/// 传输列表面板内容（非模态，嵌入 FloatingPanel 使用）
class TransferListPanel extends StatefulWidget {
  const TransferListPanel({super.key});

  @override
  State<TransferListPanel> createState() => _TransferListPanelState();
}

class _TransferListPanelState extends State<TransferListPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Column(
      children: [
        // Tab 栏
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: c.divider)),
          ),
          child: TabBar(
            controller: _tabController,
            labelColor: c.accent,
            unselectedLabelColor: c.text3,
            indicatorColor: c.accent,
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            unselectedLabelStyle: const TextStyle(fontSize: 12),
            tabs: const [
              Tab(text: '全部'),
              Tab(text: '上传'),
              Tab(text: '下载'),
            ],
          ),
        ),
        // 内容
        Expanded(
          child: ListenableBuilder(
            listenable: TransferManager(),
            builder: (context, _) {
              final all = TransferManager().tasks.toList();
              final uploads = all.where((t) => t.type == TransferType.upload).toList();
              final downloads = all.where((t) => t.type == TransferType.download).toList();
              final hasFinished = all.any((t) =>
                  t.status == TransferStatus.completed || t.status == TransferStatus.failed);

              return Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTaskList(all),
                        _buildTaskList(uploads),
                        _buildTaskList(downloads),
                      ],
                    ),
                  ),
                  if (hasFinished)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
                      child: SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: TextButton(
                          onPressed: TransferManager().clearCompleted,
                          style: TextButton.styleFrom(
                            foregroundColor: c.text3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(7),
                              side: BorderSide(color: c.cardBorder),
                            ),
                          ),
                          child: const Text('清空已完成 / 失败', style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskList(List<TransferTask> tasks) {
    final c = AppColors.of(context);
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined, size: 36, color: c.divider),
            const SizedBox(height: 10),
            Text('暂无传输任务', style: TextStyle(color: c.text3, fontSize: 13)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, index) => _buildTaskItem(tasks[index]),
    );
  }

  Widget _buildTaskItem(TransferTask task) {
    final c = AppColors.of(context);
    final isUpload = task.type == TransferType.upload;
    final progress = task.progress;
    final isIndeterminate = task.totalBytes == 0 && task.status == TransferStatus.running;

    Color statusColor;
    String statusText;
    switch (task.status) {
      case TransferStatus.pending:
        statusColor = c.text3;
        statusText = '等待中';
      case TransferStatus.running:
        statusColor = c.accent;
        statusText = isIndeterminate ? _formatBytes(task.transferredBytes) : '${(progress * 100).toStringAsFixed(1)}%';
      case TransferStatus.completed:
        statusColor = c.success;
        statusText = '已完成';
      case TransferStatus.failed:
        statusColor = c.error;
        statusText = '失败';
    }

    final showProgress = task.status == TransferStatus.running || task.status == TransferStatus.pending;
    final canRemove = task.status == TransferStatus.completed || task.status == TransferStatus.failed;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isUpload ? Icons.upload_rounded : Icons.download_rounded, size: 15, color: c.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  task.name,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: c.text2),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(statusText, style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w500)),
              if (canRemove) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => TransferManager().removeTask(task.id),
                  child: Icon(Icons.close_rounded, size: 14, color: c.text3),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${task.sourcePath}  →  ${task.destPath}',
            style: TextStyle(fontSize: 10, color: c.text3),
            maxLines: 1, overflow: TextOverflow.ellipsis,
          ),
          if (showProgress) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: isIndeterminate ? null : progress,
                backgroundColor: c.divider,
                color: c.accent,
                minHeight: 3,
              ),
            ),
            if (task.totalBytes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(_formatBytes(task.transferredBytes), style: TextStyle(fontSize: 10, color: c.text3)),
                    Text(_formatBytes(task.totalBytes), style: TextStyle(fontSize: 10, color: c.text3)),
                  ],
                ),
              ),
          ],
          if (task.status == TransferStatus.failed && task.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(task.error!, style: TextStyle(fontSize: 10, color: c.error), maxLines: 2, overflow: TextOverflow.ellipsis),
            ),
        ],
      ),
    );
  }
}
