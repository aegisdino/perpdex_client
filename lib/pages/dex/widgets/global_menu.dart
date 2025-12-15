import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '/common/theme.dart';
import '/auth/authmanager.dart';
import '/data/localization.dart';
import '../layout/customizable_layout.dart';
import '../providers/account_settings_provider.dart';
import '../providers/account_config_provider.dart';
import 'trading_mode_dialogs.dart';

/// 전역 메뉴 오버레이
class GlobalMenuButton extends ConsumerStatefulWidget {
  const GlobalMenuButton({super.key});

  @override
  ConsumerState<GlobalMenuButton> createState() => _GlobalMenuButtonState();
}

class _GlobalMenuButtonState extends ConsumerState<GlobalMenuButton> {
  OverlayEntry? _overlayEntry;

  void _showMenuOverlay() {
    // 이미 열려있으면 닫기
    if (_overlayEntry != null) {
      _removeOverlay();
      return;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => GlobalMenuOverlay(
        onClose: _removeOverlay,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.menu, color: Colors.white),
      tooltip: '메뉴',
      onPressed: _showMenuOverlay,
    );
  }
}

/// 전역 메뉴 오버레이 패널
class GlobalMenuOverlay extends ConsumerWidget {
  final VoidCallback onClose;

  const GlobalMenuOverlay({
    super.key,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = AuthManager().isLoginOK;

    return Stack(
      children: [
        // 배경 (클릭하면 닫기)
        Positioned.fill(
          child: GestureDetector(
            onTap: onClose,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        // 메뉴 패널
        Positioned(
          top: 60,
          right: 8,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(0),
                border: Border.all(color: AppTheme.onBackground.withAlpha(100)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 헤더
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AppTheme.dexSecondary),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          '설정',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.grey),
                          onPressed: onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  if (isLoggedIn) _buildLoginUserMenus(context, ref),
                  // 메뉴 항목들
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '인터페이스',
                          style:
                              AppTheme.bodySmall.copyWith(color: Colors.grey),
                        ),
                      ),
                      _buildMenuItem(
                        context: context,
                        ref: ref,
                        icon: Icons.brightness_6,
                        title: '테마 선택',
                        onTap: () => _showThemeDialog(context),
                      ),
                      _buildMenuItem(
                        context: context,
                        ref: ref,
                        icon: Icons.dashboard,
                        title: '거래 패널',
                        trailing: TextButton(
                          onPressed: () {
                            ref.read(layoutProvider.notifier).resetToDefault();
                            onClose();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('거래 패널이 초기화되었습니다')),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.amber,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            '초기화',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ),
                      Divider(),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          '기타',
                          style:
                              AppTheme.bodySmall.copyWith(color: Colors.grey),
                        ),
                      ),
                      _buildMenuItem(
                        context: context,
                        ref: ref,
                        icon: Icons.language,
                        title: '언어 선택',
                        trailing: LanguageListView(
                          useWrap: false,
                          iconSize: 20,
                        ),
                      ),
                      _buildMenuItem(
                        context: context,
                        ref: ref,
                        icon: Icons.notifications,
                        title: '알림 설정',
                        onTap: () {
                          onClose();
                          // TODO: 알림 설정 페이지로 이동
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('알림 설정 페이지는 준비 중입니다')),
                          );
                        },
                      ),
                      if (isLoggedIn)
                        _buildMenuItem(
                          context: context,
                          ref: ref,
                          icon: Icons.logout,
                          title: '로그아웃',
                          textColor: Colors.red,
                          onTap: () => _showLogoutDialog(context),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginUserMenus(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text(
            '거래',
            style: AppTheme.bodySmall.copyWith(color: Colors.grey),
          ),
        ),
        Builder(builder: (context) {
          final accountSettings = ref.watch(accountSettingsProvider);
          final modeText = accountSettings.assetMode == AssetMode.single
              ? '단일 자산'
              : '다중 자산';
          return _buildMenuItem(
            context: context,
            ref: ref,
            icon: Icons.circle,
            title: '자산 모드',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  modeText,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
            onTap: () {
              onClose();
              showAssetModeDialog(context, ref);
            },
          );
        }),
        Builder(builder: (context) {
          final accountConfig = ref.watch(accountConfigProvider);
          final modeText = accountConfig.defaultPositionMode == PositionMode.oneWay
              ? '일방향'
              : '헤지';
          return _buildMenuItem(
            context: context,
            ref: ref,
            icon: Icons.rectangle_outlined,
            title: '포지션 모드',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  modeText,
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
              ],
            ),
            onTap: () {
              onClose();
              showPositionModeDialog(context, ref);
            },
          );
        }),
        Divider(),
      ],
    );
  }

  Widget _buildMenuItem({
    required BuildContext context,
    required WidgetRef ref,
    required IconData icon,
    required String title,
    VoidCallback? onTap,
    Color? textColor,
    Widget? trailing,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(icon, color: textColor ?? Colors.grey, size: 22),
            const SizedBox(width: 12),
            Text(
              title,
              style: TextStyle(
                color: textColor ?? Colors.white,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            trailing ?? Icon(Icons.chevron_right, color: Colors.grey, size: 20),
          ],
        ),
      ),
    );
  }

  void _showThemeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.dexSurface,
        title: const Text(
          '테마 선택',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(context, '라이트 모드', false),
            const SizedBox(height: 12),
            _buildThemeOption(context, '다크 모드', true),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, bool isDark) {
    // TODO: 실제 테마 상태 연결
    final isSelected = isDark; // 현재는 항상 다크 모드

    return ListTile(
      title: Text(label, style: const TextStyle(color: Colors.white)),
      leading: Icon(
        isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: isSelected ? AppTheme.dexPrimary : Colors.grey,
      ),
      onTap: () {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label가 적용되었습니다')),
        );
        // TODO: 테마 변경 로직 구현
      },
    );
  }

  void _showLanguageDialog(BuildContext context) {
    final languages = [
      {'code': 'ko', 'name': '한국어', 'icon': '🇰🇷'},
      {'code': 'en', 'name': 'English', 'icon': '🇺🇸'},
      {'code': 'ja', 'name': '日本語', 'icon': '🇯🇵'},
      {'code': 'zh-CN', 'name': '简体中文', 'icon': '🇨🇳'},
      {'code': 'zh-TW', 'name': '繁體中文', 'icon': '🇹🇼'},
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.dexSurface,
        title: const Text(
          '언어 선택',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: languages.map((lang) {
              final isSelected = Localization.language == lang['code'];
              return ListTile(
                title: Row(
                  children: [
                    Text(lang['icon']!, style: const TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Text(
                      lang['name']!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
                leading: Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: isSelected ? AppTheme.dexPrimary : Colors.grey,
                ),
                onTap: () {
                  Localization.language = lang['code']!;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${lang['name']} 언어로 변경되었습니다')),
                  );
                },
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.dexSurface,
        title: const Text(
          '로그아웃',
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
        content: Text(
          '로그아웃 하시겠습니까?',
          style: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await AuthManager().logout();
              Navigator.pop(context);
              Navigator.pop(context); // 메뉴도 닫기
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('로그아웃되었습니다')),
              );
            },
            child: const Text(
              '로그아웃',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}
