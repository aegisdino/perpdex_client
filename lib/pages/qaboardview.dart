import 'dart:math' as math;

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '/view/common/circle_icon_button.dart';
import '/common/all.dart';
import '/api/netclient.dart';

class QABoardView extends StatefulWidget {
  const QABoardView({super.key});

  @override
  State<QABoardView> createState() => _QABoardViewState();
}

class _QABoardViewState extends State<QABoardView>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> qamessages = [];

  final scrollController = ScrollController();
  bool _hasmore = true;
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  late TabController _tabController;
  List<String> _tabTitles = [
    'bitgame.new_qa'.tr(),
    'bitgame.qa_list'.tr(),
  ];

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabTitles.length, vsync: this);

    _loadData();
  }

  Future _loadData() async {
    if (!_hasmore) return;
    final result = await ServerAPI().loadQAMessages({
      'start': qamessages.length,
      'count': 30,
    });
    if (result != null && result['result'] == 0) {
      if (result['rows'].length > 0) {
        final newData = List<Map<String, dynamic>>.from(result['rows']);
        qamessages.addAll(newData);
        if (mounted) setState(() {});
      } else {
        _hasmore = false;
      }
    }

    _refreshController.loadComplete();
  }

  final inputTagQAMessage = 'inputTagQAMessage';

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 10,
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTabBar(),
        Expanded(child: _buildTabContents()),
      ],
    );
  }

  Widget _buildTabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: TabBar(
              tabs: _tabTitles
                  .map((e) => Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Text(e),
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
    switch (_tabController.index) {
      case 0:
        return GestureDetector(
          onTap: () {
            Util.killFocus(context);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: InputManager().inputBuilder(
                  inputTagQAMessage,
                  maxLines: 5,
                  maxLength: 400,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleIconButton(
                    icon: Icon(
                      Icons.send,
                      size: 30,
                    ),
                    onTap: () async {
                      sendMessage();
                    },
                  )
                ],
              ),
            ],
          ),
        );

      case 1:
        return _buildQaMessages();

      default:
        return Container();
    }
  }

  Future sendMessage() async {
    final message = InputManager().getText(inputTagQAMessage);
    if (message.isNotNullEmptyOrWhitespace) {
      final result = await ServerAPI().sendQAMessage({'message': message});
      if (result != null && result['result'] == 0) {
        qamessages.insert(0, {'id': result['id'], 'message': message});
        if (mounted) setState(() {});

        Util.showAlert('bitgame.msg_sent'.tr());
      }
    }
  }

  String getMessageText(Map<String, dynamic> e) {
    String message = e['message'];

    if (e['replymsg'] != null) {
      message += '┗ <o5>${e['replymsg']}</o5>\n';
      message += '  ${e['replydate']}';
    }

    return message;
  }

  Widget _buildQaMessages() {
    return Stack(
      children: [
        SmartRefresher(
          controller: _refreshController,
          enablePullUp: true,
          onLoading: () async {
            _loadData();
          },
          child: SingleChildScrollView(
            controller: scrollController,
            child: Table(
              columnWidths: <int, TableColumnWidth>{
                0: FixedColumnWidth(40),
                1: IntrinsicColumnWidth(),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(
                      color: HexColor.fromHex("1F232A"),
                      borderRadius: BorderRadius.circular(10)),
                  children: [
                    'bitgame.date'.tr(),
                    'Q&A',
                  ]
                      .map(
                        (e) => TableCell(
                          child: Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                e,
                                style: AppTheme.textTheme.bodySmall!,
                              ),
                            ),
                          ),
                          verticalAlignment: TableCellVerticalAlignment.middle,
                        ),
                      )
                      .toList(),
                ),
                ...qamessages
                    .map(
                      (e) => TableRow(
                        children: [e['regdate'], getMessageText(e)]
                            .map((col) => TableCell(
                                  verticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  child: Padding(
                                    padding: const EdgeInsets.all(4.0),
                                    child: MyStyledText(
                                      col ?? '',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                    )
                    .toList()
              ],
            ),
          ),
        ),
        if (qamessages.isEmpty) Center(child: Text('bitgame.nodata'.tr())),
      ],
    );
  }
}

Future openQADialog(BuildContext context) async {
  await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          contentPadding: EdgeInsets.all(20),
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 8.0, vertical: 24.0),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.9,
            height: math.min(400, MediaQuery.of(context).size.width * 0.9),
            child: QABoardView(),
          ),
          actions: [
            InkWell(
              onTap: () {
                navigationPop(context);
              },
              child: Text('common.close'.tr()),
            ),
          ],
        );
      });
}
