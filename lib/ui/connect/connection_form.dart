import 'package:flutter/material.dart';
import 'package:tdesign_flutter/tdesign_flutter.dart';
import '../../function/connect/connection_model.dart';

class ConnectionForm extends StatefulWidget {
  final Connection? connection;
  final ValueChanged<Connection> onSave;

  const ConnectionForm({super.key, this.connection, required this.onSave});

  @override
  State<ConnectionForm> createState() => _ConnectionFormState();
}

class _ConnectionFormState extends State<ConnectionForm> {
  final _formKey = GlobalKey<FormState>();
  
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
      port: int.tryParse(_portController.text) ?? 22,
      note: _noteController.text,
      authMethod: _authMethod,
      username: _usernameController.text,
      password: _passwordController.text,
      privateKeyPath: _privateKeyPathController.text,
    );

    widget.onSave(connection);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(context, '常规'),
          const SizedBox(height: 12),
          _buildTypeSelect(context),
          const SizedBox(height: 12),
          _buildInput(
            context, 
            label: '名称', 
            controller: _nameController,
            hintText: '请输入连接名称',
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInput(
                  context, 
                  label: '主机', 
                  controller: _hostController,
                  hintText: 'IP 地址或域名',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 1,
                child: _buildInput(
                  context, 
                  label: '端口', 
                  controller: _portController,
                  hintText: '22',
                  inputType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInput(
            context, 
            label: '备注', 
            controller: _noteController,
            hintText: '备注信息',
            maxLines: 3,
          ),
          
          const SizedBox(height: 24),
          _buildSectionTitle(context, '认证'),
          const SizedBox(height: 12),
          
          // 认证方式选择
          _buildAuthMethodSelect(context),
          
          const SizedBox(height: 12),
          _buildInput(
            context, 
            label: '用户名', 
            controller: _usernameController,
            hintText: '请输入用户名',
          ),
          const SizedBox(height: 12),
          
          if (_authMethod == AuthMethod.password)
            _buildInput(
              context, 
              label: '密码', 
              controller: _passwordController,
              hintText: '请输入密码',
              obscureText: true,
            )
          else
            Row(
              children: [
                Expanded(
                  child: _buildInput(
                    context, 
                    label: '私钥', 
                    controller: _privateKeyPathController,
                    hintText: '私钥文件路径',
                  ),
                ),
                const SizedBox(width: 8),
                TDButton(
                  text: '浏览...',
                  type: TDButtonType.outline,
                  theme: TDButtonTheme.defaultTheme,
                  onTap: () {
                    // TODO: 实现文件选择
                    TDToast.showText('文件选择功能暂未实现', context: context);
                  },
                ),
              ],
            ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: TDButton(
              text: '保存连接',
              theme: TDButtonTheme.primary,
              size: TDButtonSize.large,
              onTap: _handleSave,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return TDText(
      title,
      style: TextStyle(
        fontSize: TDTheme.of(context).fontTitleMedium?.size,
        fontWeight: FontWeight.bold,
        color: TDTheme.of(context).fontGyColor1,
      ),
    );
  }

  Widget _buildTypeSelect(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TDText(
          '类型',
          style: TextStyle(
            fontSize: TDTheme.of(context).fontBodyMedium?.size,
            color: TDTheme.of(context).fontGyColor1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TDTheme.of(context).grayColor1,
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<ConnectionType>(
              value: _type,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: ConnectionType.ssh,
                  child: Text('SSH 连接'),
                ),
                DropdownMenuItem(
                  value: ConnectionType.vnc,
                  child: Text('VNC 连接'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _type = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInput(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool obscureText = false,
    int maxLines = 1,
    TextInputType? inputType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TDText(
          label,
          style: TextStyle(
            fontSize: TDTheme.of(context).fontBodyMedium?.size,
            color: TDTheme.of(context).fontGyColor1,
          ),
        ),
        const SizedBox(height: 8),
        TDInput(
          controller: controller,
          hintText: hintText,
          obscureText: obscureText,
          maxLines: maxLines,
          backgroundColor: TDTheme.of(context).grayColor1,
          inputType: inputType,
          type: TDInputType.normal,
        ),
      ],
    );
  }

  Widget _buildAuthMethodSelect(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TDText(
          '方法',
          style: TextStyle(
            fontSize: TDTheme.of(context).fontBodyMedium?.size,
            color: TDTheme.of(context).fontGyColor1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: TDTheme.of(context).grayColor1,
            borderRadius: BorderRadius.circular(4),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AuthMethod>(
              value: _authMethod,
              isExpanded: true,
              items: const [
                DropdownMenuItem(
                  value: AuthMethod.password,
                  child: Text('密码'),
                ),
                DropdownMenuItem(
                  value: AuthMethod.privateKey,
                  child: Text('私钥'),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _authMethod = value);
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}
