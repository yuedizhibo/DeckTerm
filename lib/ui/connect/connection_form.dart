import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../function/connect/connection_model.dart';
import '../../setting/app_theme.dart';

class ConnectionForm extends StatefulWidget {
  final Connection? connection;
  final ValueChanged<Connection> onSave;

  const ConnectionForm({super.key, this.connection, required this.onSave});

  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm> {
  late TextEditingController _nameController;
  late TextEditingController _hostController;
  late TextEditingController _portController;
  late TextEditingController _usernameController;
  late TextEditingController _passwordController;
  late TextEditingController _privateKeyPathController;
  late TextEditingController _noteController;

  late ConnectionType _type;
  late AuthMethod _authMethod;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.connection?.name ?? '');
    _hostController = TextEditingController(text: widget.connection?.host ?? '');
    _portController = TextEditingController(text: widget.connection?.port.toString() ?? '22');
    _usernameController = TextEditingController(text: widget.connection?.username ?? '');
    _passwordController = TextEditingController(text: widget.connection?.password ?? '');
    _privateKeyPathController = TextEditingController(text: widget.connection?.privateKeyPath ?? '');
    _noteController = TextEditingController(text: widget.connection?.note ?? '');

    _type = widget.connection?.type ?? ConnectionType.ssh;
    _authMethod = widget.connection?.authMethod ?? AuthMethod.password;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _privateKeyPathController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _handleSave() {
    if (_nameController.text.isEmpty) {
      TDToast.showText('请输入名称', context: context);
      return;
    }
    if (_hostController.text.isEmpty) {
      TDToast.showText('请输入主机地址', context: context);
      return;
    }

    final connection = Connection(
      id: widget.connection?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameController.text,
      type: _type,
      host: _hostController.text,
      port: int.tryParse(_portController.text) ?? (_type == ConnectionType.ssh ? 22 : 5900),
      note: _noteController.text,
      authMethod: _authMethod,
      username: _usernameController.text,
      password: _passwordController.text,
      privateKeyPath: _privateKeyPathController.text,
    );

    widget.onSave(connection);
  }

  void _onTypeChanged(ConnectionType? value) {
    if (value == null || value == _type) return;
    setState(() {
      _type = value;
      // 自动更新默认端口
      final currentPort = int.tryParse(_portController.text);
      if (currentPort == 22 || currentPort == 5900) {
        _portController.text = value == ConnectionType.ssh ? '22' : '5900';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        // ── 常规 ──
        _FormCard(
          icon: Icons.dns_outlined,
          title: '常规',
          children: [
            _buildDropdownRow(
              c,
              label: '类型',
              child: _TypeSelector(
                value: _type,
                onChanged: _onTypeChanged,
              ),
            ),
            _buildTextFieldRow(c, label: '名称', controller: _nameController, hintText: '请输入连接名称'),
            _buildHostPortRow(c),
            _buildTextFieldRow(c, label: '备注', controller: _noteController, hintText: '备注信息', maxLines: 2),
          ],
        ),
        const SizedBox(height: 10),

        // ── 认证 ──
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (child, animation) => SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: _FormCard(
            key: ValueKey('auth_${_type.name}'),
            icon: Icons.lock_outline_rounded,
            title: '认证',
            children: [
              _buildDropdownRow(
                c,
                label: '方法',
                child: _AuthMethodSelector(
                  value: _authMethod,
                  onChanged: (v) {
                    if (v != null) setState(() => _authMethod = v);
                  },
                ),
              ),
              // VNC 模式下隐藏用户名
              if (_type != ConnectionType.vnc)
                _buildTextFieldRow(c, label: '用户名', controller: _usernameController, hintText: '请输入用户名'),
              // 密码/私钥 切换
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) => SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: _authMethod == AuthMethod.password
                    ? _buildTextFieldRow(
                        c,
                        key: const ValueKey('password'),
                        label: '密码',
                        controller: _passwordController,
                        hintText: '请输入密码',
                        obscureText: true,
                      )
                    : _buildPrivateKeyRow(c),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── 保存按钮 ──
        GestureDetector(
          onTap: _handleSave,
          child: Container(
            width: double.infinity,
            height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [c.accent, c.accentSecondary],
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: const Text(
              '保存连接',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── 主机 + 端口 行 ──
  Widget _buildHostPortRow(AppColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('主机', style: TextStyle(fontSize: 13, color: c.text2)),
          ),
          Expanded(
            flex: 3,
            child: _StyledTextField(controller: _hostController, hintText: 'IP 地址或域名'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(':', style: TextStyle(fontSize: 13, color: c.text3)),
          ),
          SizedBox(
            width: 64,
            child: _StyledTextField(
              controller: _portController,
              hintText: _type == ConnectionType.ssh ? '22' : '5900',
              inputType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  // ── 私钥行 ──
  Widget _buildPrivateKeyRow(AppColors c) {
    return Padding(
      key: const ValueKey('privateKey'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text('私钥', style: TextStyle(fontSize: 13, color: c.text2)),
          ),
          Expanded(
            child: _StyledTextField(controller: _privateKeyPathController, hintText: '私钥文件路径'),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () {
              TDToast.showText('文件选择功能暂未实现', context: context);
            },
            child: Container(
              height: 34,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: c.hoverBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: c.cardBorder),
              ),
              alignment: Alignment.center,
              child: Text('浏览', style: TextStyle(fontSize: 12, color: c.text2)),
            ),
          ),
        ],
      ),
    );
  }

  // ── 通用文本输入行 ──
  Widget _buildTextFieldRow(
    AppColors c, {
    Key? key,
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool obscureText = false,
    int maxLines = 1,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        crossAxisAlignment: maxLines > 1 ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Padding(
            padding: EdgeInsets.only(top: maxLines > 1 ? 8 : 0),
            child: SizedBox(
              width: 52,
              child: Text(label, style: TextStyle(fontSize: 13, color: c.text2)),
            ),
          ),
          Expanded(
            child: _StyledTextField(
              controller: controller,
              hintText: hintText,
              obscureText: obscureText,
              maxLines: maxLines,
            ),
          ),
        ],
      ),
    );
  }

  // ── 通用下拉选择行 ──
  Widget _buildDropdownRow(AppColors c, {required String label, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          SizedBox(
            width: 52,
            child: Text(label, style: TextStyle(fontSize: 13, color: c.text2)),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  分组卡片（与 settings_panel 一致风格）
// ═══════════════════════════════════════════════════════════════════

class _FormCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _FormCard({super.key, required this.icon, required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: Row(
              children: [
                Icon(icon, size: 14, color: c.accent.withOpacity(0.6)),
                const SizedBox(width: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: c.text3,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0) Container(height: 1, margin: const EdgeInsets.symmetric(horizontal: 12), color: c.divider),
            children[i],
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  统一输入框样式
// ═══════════════════════════════════════════════════════════════════

class _StyledTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hintText;
  final bool obscureText;
  final int maxLines;
  final TextInputType? inputType;

  const _StyledTextField({
    required this.controller,
    this.hintText,
    this.obscureText = false,
    this.maxLines = 1,
    this.inputType,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      maxLines: maxLines,
      keyboardType: inputType,
      style: TextStyle(fontSize: 13, color: c.text1),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(fontSize: 13, color: c.text3),
        filled: true,
        fillColor: c.cardBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: c.accent, width: 1.5),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  连接类型选择器
// ═══════════════════════════════════════════════════════════════════

class _TypeSelector extends StatelessWidget {
  final ConnectionType value;
  final ValueChanged<ConnectionType?> onChanged;

  const _TypeSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<ConnectionType>(
          value: value,
          isExpanded: true,
          dropdownColor: c.menuBg,
          borderRadius: BorderRadius.circular(10),
          style: TextStyle(fontSize: 13, color: c.text1),
          icon: Icon(Icons.expand_more_rounded, size: 18, color: c.text3),
          items: [
            DropdownMenuItem(
              value: ConnectionType.ssh,
              child: Row(
                children: [
                  Icon(Icons.terminal_rounded, size: 15, color: c.accent),
                  const SizedBox(width: 8),
                  Text('SSH', style: TextStyle(fontSize: 13, color: c.text1)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: ConnectionType.vnc,
              child: Row(
                children: [
                  Icon(Icons.desktop_windows_rounded, size: 15, color: c.accentSecondary),
                  const SizedBox(width: 8),
                  Text('VNC', style: TextStyle(fontSize: 13, color: c.text1)),
                ],
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  认证方式选择器
// ═══════════════════════════════════════════════════════════════════

class _AuthMethodSelector extends StatelessWidget {
  final AuthMethod value;
  final ValueChanged<AuthMethod?> onChanged;

  const _AuthMethodSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AuthMethod>(
          value: value,
          isExpanded: true,
          dropdownColor: c.menuBg,
          borderRadius: BorderRadius.circular(10),
          style: TextStyle(fontSize: 13, color: c.text1),
          icon: Icon(Icons.expand_more_rounded, size: 18, color: c.text3),
          items: [
            DropdownMenuItem(
              value: AuthMethod.password,
              child: Row(
                children: [
                  Icon(Icons.password_rounded, size: 15, color: c.text2),
                  const SizedBox(width: 8),
                  Text('密码', style: TextStyle(fontSize: 13, color: c.text1)),
                ],
              ),
            ),
            DropdownMenuItem(
              value: AuthMethod.privateKey,
              child: Row(
                children: [
                  Icon(Icons.key_rounded, size: 15, color: c.text2),
                  const SizedBox(width: 8),
                  Text('私钥', style: TextStyle(fontSize: 13, color: c.text1)),
                ],
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}
