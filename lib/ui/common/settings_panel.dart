import 'package:flutter/material.dart';
import '../../setting/app_theme.dart';

/// 设置面板内容（非模态，嵌入 FloatingPanel / showPanelDialog 使用）
class SettingsPanel extends StatefulWidget {
  const SettingsPanel({super.key});

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel> {
  // 临时本地状态，后续接入 SettingsManager
  double _fontSize = 14.0;
  bool _cursorBlink = true;
  int _scrollbackLines = 10000;
  int _keepAliveSeconds = 30;
  bool _autoReconnect = true;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final isDark = ThemeProvider.instance.isDark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        // ── 外观 ──
        _SettingsCard(
          icon: Icons.palette_outlined,
          title: '外观',
          children: [
            _ThemeRow(isDark: isDark),
          ],
        ),
        const SizedBox(height: 10),

        // ── 终端 ──
        _SettingsCard(
          icon: Icons.terminal_rounded,
          title: '终端',
          children: [
            _SliderRow(
              label: '字号',
              value: _fontSize,
              min: 10, max: 24, divisions: 14,
              valueLabel: '${_fontSize.round()}',
              onChanged: (v) => setState(() => _fontSize = v),
            ),
            _SwitchRow(
              label: '光标闪烁',
              value: _cursorBlink,
              onChanged: (v) => setState(() => _cursorBlink = v),
            ),
            _SliderRow(
              label: '回滚行数',
              value: _scrollbackLines.toDouble(),
              min: 1000, max: 100000, divisions: 99,
              valueLabel: _formatScrollback(_scrollbackLines),
              onChanged: (v) => setState(() => _scrollbackLines = v.round()),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── 连接 ──
        _SettingsCard(
          icon: Icons.lan_outlined,
          title: '连接',
          children: [
            _SliderRow(
              label: 'KeepAlive 间隔',
              value: _keepAliveSeconds.toDouble(),
              min: 0, max: 120, divisions: 24,
              valueLabel: '${_keepAliveSeconds}s',
              onChanged: (v) => setState(() => _keepAliveSeconds = v.round()),
            ),
            _SwitchRow(
              label: '断线自动重连',
              value: _autoReconnect,
              onChanged: (v) => setState(() => _autoReconnect = v),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // ── 关于 ──
        _buildAboutCard(c),
      ],
    );
  }

  String _formatScrollback(int lines) {
    if (lines >= 1000) return '${(lines / 1000).toStringAsFixed(lines % 1000 == 0 ? 0 : 1)}K';
    return '$lines';
  }

  Widget _buildAboutCard(AppColors c) {
    return Container(
      decoration: BoxDecoration(
        color: c.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.cardBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [c.accent, c.accentSecondary],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.terminal_rounded, size: 18, color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('DeckTerm', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.text1)),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(
                              color: c.accentDimBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text('v1.0.0', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: c.accent)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text('SSH 终端 + 文件管理器', style: TextStyle(fontSize: 11, color: c.text3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: c.divider),
          _aboutRow(c, '平台', 'Flutter · Dart'),
          Container(height: 1, color: c.divider),
          _aboutRow(c, 'SSH', 'dartssh2'),
          Container(height: 1, color: c.divider),
          _aboutRow(c, '终端', 'xterm-256color'),
        ],
      ),
    );
  }

  Widget _aboutRow(AppColors c, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: c.text3)),
          const Spacer(),
          Text(value, style: TextStyle(fontSize: 12, color: c.text2)),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  主题切换行
// ═══════════════════════════════════════════════════════════════════

class _ThemeRow extends StatelessWidget {
  final bool isDark;
  const _ThemeRow({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Text('主题模式', style: TextStyle(fontSize: 13, color: c.text2)),
          const Spacer(),
          // 深色/浅色切换按钮组
          Container(
            height: 28,
            decoration: BoxDecoration(
              color: c.cardBg,
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: c.cardBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ThemeChip(
                  icon: Icons.dark_mode_rounded,
                  label: '深色',
                  isSelected: isDark,
                  onTap: () { if (!isDark) ThemeProvider.instance.toggle(); },
                ),
                _ThemeChip(
                  icon: Icons.light_mode_rounded,
                  label: '浅色',
                  isSelected: !isDark,
                  onTap: () { if (isDark) ThemeProvider.instance.toggle(); },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeChip({required this.icon, required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: isSelected ? c.accent.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 13, color: isSelected ? c.accent : c.text3),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isSelected ? c.accent : c.text3)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  分组设置卡片
// ═══════════════════════════════════════════════════════════════════

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const _SettingsCard({required this.icon, required this.title, required this.children});

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
                    fontSize: 11, fontWeight: FontWeight.w700,
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
//  开关行
// ═══════════════════════════════════════════════════════════════════

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Row(
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: c.text2)),
          const Spacer(),
          SizedBox(
            height: 20, width: 36,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: c.accent,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  滑块行
// ═══════════════════════════════════════════════════════════════════

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String valueLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.valueLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 6, 2),
      child: Column(
        children: [
          Row(
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: c.text2)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accentDimBg,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(valueLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c.accent)),
              ),
              const SizedBox(width: 8),
            ],
          ),
          SizedBox(
            height: 28,
            child: SliderTheme(
              data: SliderThemeData(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: c.accent,
                inactiveTrackColor: c.divider,
                thumbColor: c.accent,
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                overlayColor: c.accent.withOpacity(0.08),
              ),
              child: Slider(
                value: value.clamp(min, max),
                min: min,
                max: max,
                divisions: divisions,
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
