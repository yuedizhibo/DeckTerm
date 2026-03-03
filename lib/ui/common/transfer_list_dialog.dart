import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../function/transfer/transfer_manager.dart';

/// 传输列表对话框
/// 显示所有上传/下载任务的进度，替代原先分散在各面板中的内嵌进度条。
class TransferListDialog extends StatefulWidget {
  const TransferListDialog({super.key});

  @override
  State<TransferListDialog> createState() => _TransferListDialogState();
}

class _TransferListDialogState extends State<TransferListDialog>
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
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)} GB';
  }

  Widget _buildEmptyState() {
    return const Center(
      child: TDEmpty(
        type: TDEmptyType.plain,
        emptyText: '暂无传输任务',
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, TransferTask task) {
    final theme = TDTheme.of(context);
    final isUpload = task.type == TransferType.upload;
    final progress = task.progress;
    // totalBytes==0 且正在运行时视为大小未知，显示不确定进度条
    final isIndeterminate = task.totalBytes == 0 && task.status == TransferStatus.running;

    Color statusColor;
    String statusText;
    switch (task.status) {
      case TransferStatus.pending:
        statusColor = theme.grayColor6;
        statusText = '等待中';
      case TransferStatus.running:
        statusColor = theme.brandNormalColor;
        statusText = isIndeterminate
            ? _formatBytes(task.transferredBytes)
            : '${(progress * 100).toStringAsFixed(1)}%';
      case TransferStatus.completed:
        statusColor = theme.successNormalColor;
        statusText = '已完成';
      case TransferStatus.failed:
        statusColor = theme.errorNormalColor;
        statusText = '失败';
    }

    final showProgress =
        task.status == TransferStatus.running || task.status == TransferStatus.pending;
    final canRemove =
        task.status == TransferStatus.completed || task.status == TransferStatus.failed;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.grayColor1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.grayColor3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 首行：图标 + 文件名 + 状态 + 关闭按钮
          Row(
            children: [
              Icon(
                isUpload ? TDIcons.upload : TDIcons.download,
                size: 16,
                color: theme.brandNormalColor,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TDText(
                  task.name,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: theme.textColorPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              TDText(
                statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (canRemove) ...[
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => TransferManager().removeTask(task.id),
                  child: Icon(TDIcons.close_circle, size: 16, color: theme.grayColor5),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          // 路径：源 → 目标
          TDText(
            '${task.sourcePath}  →  ${task.destPath}',
            style: TextStyle(fontSize: 10, color: theme.grayColor5),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          // 进度条（运行中或等待中）
          if (showProgress) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: isIndeterminate ? null : progress,
                backgroundColor: theme.grayColor3,
                color: theme.brandNormalColor,
                minHeight: 4,
              ),
            ),
            if (task.totalBytes > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TDText(
                      _formatBytes(task.transferredBytes),
                      style: TextStyle(fontSize: 10, color: theme.grayColor5),
                    ),
                    TDText(
                      _formatBytes(task.totalBytes),
                      style: TextStyle(fontSize: 10, color: theme.grayColor5),
                    ),
                  ],
                ),
              ),
          ],
          // 错误信息（失败时）
          if (task.status == TransferStatus.failed && task.error != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: TDText(
                task.error!,
                style: TextStyle(fontSize: 10, color: theme.errorNormalColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTaskList(BuildContext context, List<TransferTask> tasks) {
    if (tasks.isEmpty) return _buildEmptyState();
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _buildTaskItem(context, tasks[index]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmallScreen = size.width < 600;
    final width = isSmallScreen ? size.width * 0.95 : 600.0;
    final height = isSmallScreen ? size.height * 0.85 : 560.0;

    return Center(
      child: Container(
        width: width,
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: TDTheme.of(context).whiteColor1,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Scaffold(
          backgroundColor: TDTheme.of(context).whiteColor1,
          appBar: AppBar(
            title: const TDText('传输列表'),
            backgroundColor: TDTheme.of(context).whiteColor1,
            foregroundColor: TDTheme.of(context).fontGyColor1,
            elevation: 0,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(TDIcons.close),
                onPressed: () => Navigator.of(context, rootNavigator: true).pop(),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              labelColor: TDTheme.of(context).brandNormalColor,
              unselectedLabelColor: TDTheme.of(context).grayColor6,
              indicatorColor: TDTheme.of(context).brandNormalColor,
              tabs: const [
                Tab(text: '全部'),
                Tab(text: '上传'),
                Tab(text: '下载'),
              ],
            ),
          ),
          body: ListenableBuilder(
            listenable: TransferManager(),
            builder: (context, _) {
              final all = TransferManager().tasks.toList();
              final uploads = all.where((t) => t.type == TransferType.upload).toList();
              final downloads = all.where((t) => t.type == TransferType.download).toList();
              final hasFinished = all.any((t) =>
                  t.status == TransferStatus.completed ||
                  t.status == TransferStatus.failed);

              return Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildTaskList(context, all),
                        _buildTaskList(context, uploads),
                        _buildTaskList(context, downloads),
                      ],
                    ),
                  ),
                  if (hasFinished)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: TDButton(
                          text: '清空已完成 / 失败',
                          type: TDButtonType.outline,
                          theme: TDButtonTheme.defaultTheme,
                          onTap: TransferManager().clearCompleted,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
