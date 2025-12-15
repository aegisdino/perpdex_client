import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';

import '../common/theme.dart';
import '../data/localization.dart';
import '../view/common/commonview.dart';

class HelpViewPage extends StatefulWidget {
  final int initialTab;

  const HelpViewPage({
    this.initialTab = 0,
    Key? key,
  }) : super(key: key);

  @override
  _HelpViewPageState createState() => _HelpViewPageState();
}

class _HelpViewPageState extends State<HelpViewPage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  List<String> _tabTitles = [
    'FAQ',
    'setting.usdt_wallet_guide'.tr(),
    'setting.webcache_remove_guide'.tr(),
  ];

  List<String> htmlContents = ['', '', ''];
  List<String> fileNames = ['faq', 'usdt-guide', 'webcache'];

  List<GlobalKey> scrollKeys = [GlobalKey(), GlobalKey(), GlobalKey()];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
        initialIndex: widget.initialTab,
        length: _tabTitles.length,
        vsync: this);

    for (var i = 0; i < fileNames.length; i++) {
      _loadHtmlFromAssets(i, fileNames[i]);
    }
  }

  // HTML 파일을 assets에서 로드하는 함수
  Future<void> _loadHtmlFromAssets(int index, String filename) async {
    try {
      String fileContent = await rootBundle
          .loadString('assets/data/${filename}.${Localization.language}.html');

      // if (index == 0) {
      //   fileContent = fileContent.replaceAll(
      //       '@@betlist@@', BitGameClient.instance.betButtonAmounts.join(', '));

      //   fileContent = fileContent.replaceAll('@@rake@@',
      //       '${(BitGameClient.instance.txRake * 100).toStringAsFixed(1)}%');

      //   fileContent = fileContent.replaceAll(
      //       '@@gameperiod@@', '${BitGameClient.instance.GAME_PERIOD}');
      // } else {}

      htmlContents[index] = fileContent;
      if (mounted) setState(() {});
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return MyScaffold(
      appBar: AppBar(
        title: Text('HELP'),
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(child: _buildTabContents()),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 500,
          child: TabBar(
              tabs: _tabTitles
                  .map((e) => Padding(
                        padding: EdgeInsets.all(4.0),
                        child: FittedBox(fit: BoxFit.scaleDown, child: Text(e)),
                      ))
                  .toList(),
              controller: _tabController,
              indicatorSize: TabBarIndicatorSize.label,
              labelColor: AppTheme.dexSecondary,
              unselectedLabelColor: AppTheme.primary,
              dividerHeight: 0,
              onTap: (index) {
                setState(() {});
              }),
        ),
      ],
    );
  }

  Widget _buildTabContents() {
    return SingleChildScrollView(
      key: scrollKeys[_tabController.index],
      padding: const EdgeInsets.all(16.0),
      child: Html(
        data: htmlContents[_tabController.index],
        style: {
          "h1": Style(
            fontSize: FontSize(24.0),
            fontWeight: FontWeight.bold,
            margin: Margins.only(bottom: 16.0),
          ),
          "h2": Style(
            fontSize: FontSize(20.0),
            fontWeight: FontWeight.bold,
            margin: Margins.only(top: 16.0, bottom: 8.0),
          ),
          "p": Style(
            fontSize: FontSize(16.0),
            margin: Margins.only(bottom: 16.0),
          ),
        },
      ),
    );
  }
}
