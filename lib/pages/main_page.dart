import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../common/util.dart';

import '/data/init.dart';
import '/data/account.dart';

import '/auth/authmanager.dart';
import '/view/common/commonview.dart' hide MenuPosition;
import '/wallet/providers/ethereum_wallet_provider.dart';

import 'dex/layout/customizable_layout.dart';
import 'dex/widgets/trading_header.dart';
import 'dex/widgets/global_menu.dart';

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => MainScreenState();
}

class MainScreenState extends ConsumerState<MainScreen> {
  double get screenWidth => MediaQuery.of(context).size.width;
  bool get isNarrowView => screenWidth < 1000;
  DateTime? serviceStartTime;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      startService();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future startService() async {
    if (serviceStartTime != null) {
      print(
          'startService: already called before [${DateTime.now().difference(serviceStartTime!).inMilliseconds}ms]');
      return;
    }

    serviceStartTime = DateTime.now();

    showLoading(animName: 'nova');

    // 실제 로딩은 마무리는 아래의 InitManager.initCompleter.future를 기다려야 함
    await InitManager.startCheckApp(context);
    if (mounted) setState(() {});

    // 서버에서 configuration loading과
    // 자동 로그인 (토큰이 있으면) 진행
    await Future.wait([
      InitManager.configLoadFuture!,
      AuthManager().autoLogin(),
    ]);

    if (mounted) setState(() {});

    // 자동 로그인 성공 시 지갑 자동 재연결
    final accountManager = AccountManager();
    if (AuthManager().isLoginOK &&
        accountManager.acct.walletAddress != null &&
        accountManager.acct.walletAddress!.isNotEmpty) {
      debugPrint('[MainScreen] Auto-reconnecting wallet after token login...');
      debugPrint(
          '[MainScreen] Saved wallet address: ${accountManager.acct.walletAddress}');
      debugPrint('[MainScreen] Wallet type: ${accountManager.acct.walletType}');
      debugPrint('[MainScreen] Namespace: ${accountManager.acct.namespace}');
      debugPrint(
          '[MainScreen] Account type: ${accountManager.acct.accountType}');

      final walletNotifier = ref.read(ethereumWalletProvider.notifier);
      final success = await walletNotifier.autoReconnect(
        expectedAddress: accountManager.acct.walletAddress!,
        walletType:
            accountManager.acct.walletType, // 'metamask', 'phantom', etc.
      );

      if (success) {
        debugPrint('[MainScreen] ✅ Wallet auto-reconnected successfully');
      } else {
        debugPrint('[MainScreen] ⚠️ Wallet auto-reconnect failed');
        // 실패해도 앱 진행은 계속함 (사용자가 수동으로 연결 가능)
      }
    } else {
      debugPrint(
          '[MainScreen] No saved wallet address, skipping auto-reconnect');
    }

    if (mounted) setState(() {});

    // 로딩이 마무리 되길 기다림
    await InitManager.initCompleter.future;
    if (mounted) setState(() {});

    // 최대 2초 정도는 로딩 창을 보여주자
    int elapsed = DateTime.now().millisecondsSinceEpoch -
        serviceStartTime!.millisecondsSinceEpoch;
    int remainMs = 1500 - elapsed;
    if (remainMs > 0) await Future.delayed(Duration(milliseconds: remainMs));

    hideLoading();

    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MyScaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // 상단 헤더 (거래쌍, 가격, 통계)
          _buildHeader(),
          SizedBox(height: 4),

          // 커스터마이징 가능한 레이아웃 (스크롤 가능)
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isMobile = constraints.maxWidth <= 800;

                double topHeight;
                double bottomHeight;
                double totalHeight;

                if (isMobile) {
                  // 좁은 화면: 차트 400px + 호가+주문 300px + 계정정보 300px = 1000px
                  // 화면에는 약 700px만 보여서 계정정보는 100px 정도만 보임
                  double topRegion = constraints.maxHeight - 60;
                  topHeight = topRegion * 0.6;
                  bottomHeight = topRegion * 0.4;
                  totalHeight = topRegion + 300; // 스크롤 필요
                } else {
                  // 넓은 화면: 상단 600px + 하단 400px = 1000px (최소)
                  topHeight = 600.0;
                  bottomHeight = 400.0;
                  // 화면 높이가 1000px보다 크면 화면 전체를 채움
                  final minTotalHeight = 1000.0;
                  totalHeight = constraints.maxHeight > minTotalHeight
                      ? constraints.maxHeight
                      : minTotalHeight;
                }

                return SingleChildScrollView(
                  child: SizedBox(
                    height: totalHeight,
                    child: CustomizableLayout(
                      topHeight: topHeight,
                      bottomHeight: bottomHeight,
                      allowResize: !isMobile,
                      allowMove: !isMobile,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.background,
        border: Border(
          bottom: BorderSide(
            color: Colors.grey.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // 기본 헤더
          const Expanded(child: TradingHeader()),

          // 전역 메뉴 버튼
          const GlobalMenuButton(),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
