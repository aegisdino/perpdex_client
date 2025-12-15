import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '/api/netclient.dart';
import '/common/util.dart';
import '/view/common/commonview.dart';
import 'game_etcview.dart';

class LeaderboardPage extends StatefulWidget {
  final String? lbType;
  final String? tableType;
  final String? currency;

  const LeaderboardPage({
    this.lbType,
    this.tableType,
    this.currency,
    super.key,
  });

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

const countPerPage = 20;

class _LeaderboardPageState extends State<LeaderboardPage> {
  Map<String, List<Map<String, dynamic>>> _leaderBoardMap = {};

  List<Map<String, dynamic>> get _leaderBoard => _leaderBoardMap[lbType] ?? [];

  bool _isLoading = false;

  late String lbType;

  String get tableType => widget.tableType ?? 'alltime';

  final controller = ScrollController();

  @override
  void initState() {
    super.initState();

    lbType = widget.lbType ?? 'highroller';

    loadData();
  }

  Future loadData() async {
    if (!_leaderBoardMap.containsKey(lbType)) {
      _isLoading = true;
      final result = await ServerAPI().loadLeaderboard(
        lbType,
        tableType,
        widget.currency ?? 'USDT',
        start: 0,
        count: countPerPage,
      );
      if (result != null) {
        int count = result['count'] ?? 0;
        if (count > 0) {
          if (!_leaderBoardMap.containsKey(lbType))
            _leaderBoardMap[lbType] = [];
          _leaderBoardMap[lbType]!
              .addAll(List<Map<String, dynamic>>.from(result['rows']));
        }
      }
      _isLoading = false;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: MyScaffold(
        appBar: MenuAppBar(
          showbackbutton: true,
          title: 'bitgame.leaderboard'.tr(),
        ),
        body: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return Column(
              children: [
                _buildTabs(),
                _buildLeaderboardList(),
                if (_leaderBoard.isEmpty && !_isLoading)
                  Center(child: Text('bitgame.nodata'.tr())),
              ],
            );
          },
        ),
      ),
    );
  }

  Map<String, List<String>> tabs = {
    "daily": ["bitgame.dailyhighroller1".tr(), "bitgame.dailyhighroller2".tr()],
    "alltime": ["bitgame.highroller1".tr(), "bitgame.highroller2".tr()],
  };

  List<String> tabKeys = ["highroller", "highprofiter"];

  Widget _buildTabs() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<int>.generate(2, (e) => (e))
          .map(
            (e) => Padding(
              padding: const EdgeInsets.all(8.0),
              child: InkWell(
                child: Text(tabs[tableType]![e],
                    style: TextStyle(
                        color: tabKeys[e] == lbType
                            ? Colors.green
                            : AppTheme.onBackground)),
                onTap: () {
                  lbType = tabKeys[e];
                  loadData();
                },
              ),
            ),
          )
          .toList(),
    );
  }

  TableRow _buildHeader() {
    return TableRow(
      decoration: BoxDecoration(color: AppTheme.primary),
      children: [
        'bitgame.tbluser'.tr(),
        'bitgame.tbltotalroll'.tr(),
        'bitgame.tblwinroll'.tr(),
        'bitgame.tblplcount'.tr(),
        'bitgame.tblwincount'.tr(),
        if (tableType == 'alltime') 'bitgame.tblmaxstreak'.tr(),
      ]
          .map(
            (e) => TableCell(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          e,
                          style: AppTheme.textTheme.bodySmall!,
                          overflow: TextOverflow.fade,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              verticalAlignment: TableCellVerticalAlignment.middle,
            ),
          )
          .toList(),
    );
  }

  Widget _buildLeaderboardList() {
    int row = 0;

    return SingleChildScrollView(
      controller: controller,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Table(
          border: TableBorder.all(color: Colors.grey),
          columnWidths: <int, TableColumnWidth>{
            0: FractionColumnWidth(0.3),
          },
          children: [
            _buildHeader(),
            ..._leaderBoard
                .map(
                  (e) => TableRow(
                    decoration: BoxDecoration(
                        color: (row++ % 2) == 1
                            ? AppTheme.background[400]
                            : Colors.transparent),
                    children: toTableColumns(e)
                        .map((col) => TableCell(
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 10.0),
                                  child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.center,
                                      child: col),
                                ),
                              ),
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                            ))
                        .toList(),
                  ),
                )
                .toList()
          ],
        ),
      ),
    );
  }

  List<Widget> toTableColumns(Map<String, dynamic> data) {
    return [
      Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          CircleUserView(profileImage: data['profileimage'], size: 30),
          SizedBox(width: 3),
          Text('${data['address'].substring(0, 10)}...',
              style: AppTheme.labelSmall.copyWith(fontSize: 8)),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CoinNumberView(
            data['totalroll'].toString(),
            ticker: data['currency'],
          ),
        ],
      ),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CoinNumberView(
            data['totalwin'].toString(),
            ticker: data['currency'],
          ),
        ],
      ),
      Text(data['playcount'].toString(), style: AppTheme.labelSmall),
      Text(data['wincount'].toString(), style: AppTheme.labelSmall),
      if (data['maxstreak'] != null)
        Text(data['maxstreak'].toString(), style: AppTheme.labelSmall),
    ];
  }
}
