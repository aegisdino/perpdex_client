import 'dart:convert';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '../api/netclient.dart';
import '../common/styles.dart';
import '../common/util.dart';
import '../data/localization.dart';

String? getLangText(String text) {
  final jsonText = jsonDecode(text);

  if ((jsonText[Localization.language] as String?).isNotNullEmptyOrWhitespace)
    return jsonText[Localization.language];

  for (var lang in Localization.supportedLangs) {
    if ((jsonText[lang] as String?).isNotNullEmptyOrWhitespace)
      return jsonText[lang];
  }
  return null;
}

class NoticeView extends StatefulWidget {
  const NoticeView({super.key});

  @override
  State<NoticeView> createState() => _NoticeViewState();
}

class _NoticeViewState extends State<NoticeView> {
  List<Map<String, dynamic>> notices = [];

  final scrollController = ScrollController();
  bool _hasmore = true;
  RefreshController _refreshController =
      RefreshController(initialRefresh: false);

  Map<String, dynamic>? _selectedNotice;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future _loadData({bool recentData = false}) async {
    if (!recentData && !_hasmore) return;

    final result = await ServerAPI().loadNotice(recentData
        ? {
            'lastid': notices.isNotEmpty ? notices.first['id'] : 0,
          }
        : {
            'start': notices.length,
            'count': 30,
          });
    if (result != null && result['result'] == 0) {
      if (result['rows'].length > 0) {
        final newData = List<Map<String, dynamic>>.from(result['rows']);
        if (recentData)
          notices.insertAll(0, newData);
        else
          notices.addAll(newData);
        if (mounted) setState(() {});
      } else if (recentData) {
        _hasmore = false;
      }
    }

    _refreshController.refreshCompleted();
  }

  @override
  Widget build(BuildContext context) {
    return _selectedNotice != null
        ? _buildSelectedNotice()
        : _buildNoticeList();
  }

  Widget _buildSelectedNotice() {
    return ListView(children: [
      Row(
        children: [
          IconButton(
              onPressed: () {
                _selectedNotice = null;
                setState(() {});
              },
              icon: Icon(Icons.arrow_back)),
        ],
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text('notice.regdate'.tr())),
            Text(
              _selectedNotice!['regdate'],
              style: AppTheme.bodySmall,
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            SizedBox(width: 80, child: Text('notice.title'.tr())),
            Text(getLangText(_selectedNotice!['title']) ?? ''),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 80, child: Text('notice.message'.tr())),
            Text(getLangText(_selectedNotice!['message']) ?? ''),
          ],
        ),
      ),
    ]);
  }

  String getLocalizedText(String text) =>
      text.startsWith('{') ? (getLangText(text) ?? '') : text;

  Widget _buildNoticeList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Text('notice.notice'.tr(), style: AppTheme.bodyLargeBold),
        ),
        Expanded(
          child: SmartRefresher(
            controller: _refreshController,
            enablePullDown: true,
            enablePullUp: true,
            onRefresh: () async {
              _loadData(recentData: true);
            },
            onLoading: () async {
              _loadData(recentData: false);
            },
            child: ListView.builder(
              itemCount: notices.length,
              itemBuilder: (context, index) {
                final item = notices[index];

                return Card(
                  child: ListTile(
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        MyStyledText(getLocalizedText(item['title'])),
                        Text(item['regdate'],
                            style: AppTheme.bodySmall.copyWith(fontSize: 10)),
                      ],
                    ),
                    subtitle: MyStyledText(
                      getLocalizedText(item['message']),
                      style: AppTheme.bodyMedium,
                    ),
                    onTap: () {
                      if (_selectedNotice == item)
                        _selectedNotice = null;
                      else
                        _selectedNotice = item;
                      setState(() {});
                    },
                  ),
                );
              },
            ),
          ),
        )
      ],
    );
  }
}

class MemoView extends StatefulWidget {
  const MemoView({super.key});

  @override
  State<MemoView> createState() => _MemoViewState();
}

class _MemoViewState extends State<MemoView> {
  List<Map<String, dynamic>> memos = [];

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future _loadData() async {
    final result = await ServerAPI().loadMemo({'unread': true});
    if (result != null && result['result'] == 0) {
      memos = List<Map<String, dynamic>>.from(result['rows']);
      if (mounted) setState(() {});
    }
  }

  String getMessage(Map<String, String> e) {
    final lang = Localization.language;
    if (e[lang].isNotNullEmptyOrWhitespace) return e[lang]!;

    for (var key in e.keys) {
      if (e[key].isNotNullEmptyOrWhitespace) return e[lang]!;
    }

    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('notice.memo'.tr(), style: AppTheme.bodyLargeBold),
              ),
              if (memos.isEmpty) Text('notice.nomemo'.tr()),
              if (memos.isNotEmpty)
                ...memos
                    .map((e) => Card(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              spacing: 10,
                              children: [
                                Row(
                                  children: [
                                    MyStyledText(
                                      e['regdate'],
                                      style: TextStyle(
                                          fontSize: 14, color: Colors.white),
                                    ),
                                    Expanded(child: Container()),
                                    InkWell(
                                        onTap: () {
                                          onRemoveMessage(e);
                                        },
                                        child: Icon(Icons.delete_forever)),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Flexible(
                                      child: MyStyledText(
                                        e['message'] ?? 'No text.',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ),
                        ))
                    .toList(),
            ],
          ),
        ),
      ],
    );
  }

  void onRemoveMessage(Map<String, dynamic> e) async {
    if (await Util.promptAlert("notice.prompt_remove".tr()) != 'ok') return;

    final result = await ServerAPI().removeMemo({'id': e['id']});
    if (result != null && result['result'] == 0)
      Util.toastNotice('notice.notice_removed'.tr());
    else
      Util.showAlert('notice.notice_notremoved'.tr());
  }
}
