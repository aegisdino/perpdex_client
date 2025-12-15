import 'dart:math' as math;
import 'package:collection/collection.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pull_to_refresh/pull_to_refresh.dart';

import '/data/providers.dart';
import '../config/server_config.dart';
import '../view/common/title_content_view.dart';
import '/view/common/commonview.dart';
import '../data/data.dart';
import '/data/account.dart';
import '/api/netclient.dart';
import '/common/all.dart';
import '/pages/game_etcview.dart';

class MyUserInfoView extends ConsumerStatefulWidget {
  const MyUserInfoView({super.key});

  @override
  ConsumerState<MyUserInfoView> createState() => MyUserInfoViewState();
}

class MyUserInfoViewState extends ConsumerState<MyUserInfoView>
    with TickerProviderStateMixin {
  bool get isVerticalMode => MediaQuery.of(context).size.aspectRatio < 1;

  final _dataMgr = DataManager();

  late int myAgencyId;
  Map<String, dynamic>? myAgency;

  AccountData get acct => AccountManager().acct;
  bool get isTeleAccount => AccountManager().isTelegramAccount;

  final bool isSupportAgencyAndUserReferral = ServerConfig.referrerEnabled;

  late TabController _tabController;
  List<String> _tabTitles = [
    'bitgame.tab_userinfo'.tr(),
    'bitgame.tab_passwd'.tr(),
    'bitgame.tab_avatar'.tr(),
    'bitgame.tab_referrer'.tr(),
    'bitgame.tab_point'.tr(),
  ];

  double get titleWidth =>
      math.min(120, math.max(80, MediaQuery.of(context).size.width * 0.2));
  double get contentWidth =>
      math.min(200, MediaQuery.of(context).size.width * 0.7 - titleWidth);

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _tabController.addListener(() {});

    myAgencyId = acct.agencyId ?? 0;
    myAgency =
        _dataMgr.agencyLists.firstWhereOrNull((e) => e['id'] == myAgencyId);

    InputManager().setText(inputTagNickname, acct.nickname ?? '');
    InputManager().setText(inputTagPhoneNo, acct.phoneno ?? '');

    _loadReferrerInfo();
  }

  void _loadReferrerInfo() async {
    if (acct.referrerCode == null) {
      final result = await ServerAPI().loadReferrerInfo();
      if (result != null) {
        if (result['result'] == 0 && result['data'] != null) {
          acct.referrerCode = result['data']['referrercode'];
          AccountManager().saveAccountInfo(acct);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(walletUpdatedProvider, (previous, next) {
      if (mounted) setState(() {});
    });

    return GestureDetector(
      onTap: () {
        Util.killFocus(context);
      },
      child: SelectionArea(
        child: Column(
          children: [
            SizedBox(height: 20),
            _buildCurrent(),
            TabBar(
                tabs: _tabTitles
                    .map((e) => Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            e,
                            textAlign: TextAlign.center,
                          ),
                        ))
                    .toList(),
                controller: _tabController,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: AppTheme.dexSecondary,
                unselectedLabelColor: AppTheme.primary,
                labelPadding: EdgeInsets.all(2),
                dividerHeight: 0,
                onTap: (index) {
                  setState(() {});
                }),
            SizedBox(height: 10),
            Expanded(
              child: _buildTabContents(),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContents() {
    switch (_tabController.index) {
      case 0:
        return _buildUserInfo();

      case 1:
        return _buildChangePassword();

      case 2:
        return _buildAvatarLists(100);

      case 3:
        return ServerConfig.referrerEnabled
            ? _buildReferrer()
            : _buildAgencyReferrer();

      case 4:
        return UserPointListView(userSeqno: acct.seqno!);

      default:
        return Container();
    }
  }

  Widget _buildCurrent() {
    final screenSize = MediaQuery.of(context).size;
    double avatarSize =
        math.min(100, math.min(screenSize.width, screenSize.height) * 0.2);

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleUserView(
            profileImage: acct.profileUrl,
            betAmount: null,
            backgroundColor: Colors.black,
            size: avatarSize,
          ),
          SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            spacing: 5,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: avatarSize,
                  child: Row(
                    children: [
                      Text('${acct.nickname}',
                          style:
                              AppTheme.bodyLarge.copyWith(color: Colors.amber)),
                      if (acct.isTeleAccount == true)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: Image.asset('assets/image/telegram_icon.png',
                              width: 15),
                        ),
                    ],
                  ),
                ),
              ),
              // CoinNumberView(
              //   '${_game.myBalance}',
              //   style: AppTheme.bodyMedium,
              //   ticker: _game.currency,
              // ),
              // Transform.translate(
              //   offset: Offset(0, -5),
              //   child: Text(
              //     'P ${_game.myPoint}',
              //     style: AppTheme.bodyMedium.copyWith(color: Colors.white),
              //   ),
              // ),
              // if (!_game.isCoinGame) _buildDemoGoldChargeButton(),
            ],
          ),
          Expanded(child: Container()),
          Column(
            children: [
              ConnectWalletButton(width: 100),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoGoldChargeButton() {
    return CircularBoxContainer(
      height: 26,
      width: 60,
      borderColor: const Color.fromARGB(255, 179, 93, 8),
      child: InkWell(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'bitgame.charge'.tr(),
              style: AppTheme.labelSmall,
            ),
          ),
        ),
        onTap: () async {
          // final result = await ServerAPI().chargeGold({'amount': 1000});
          // if (result != null) {
          //   if (result['result'] == 0) {
          //     acct.balance = double.parse(result['gold'].toString());
          //     WalletService().setBalance(acct.balance!);
          //   }
          // }
        },
      ),
    );
  }

  Widget _buildAvatarLists(double size) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(width: 1, color: Colors.grey.withAlpha(100)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SingleChildScrollView(
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                alignment: WrapAlignment.center,
                children: List<int>.generate(170, (e) => e)
                    .map(
                      (index) => InkWell(
                        onTap: () {
                          // _game.changeProfileImage('${index}.png');
                          setState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Container(
                            width: size,
                            height: size,
                            child: Image.asset(
                              'assets/avatars/${index}.png',
                              width: size,
                            ),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String inputTagNickname = 'inputTagNickname';
  String inputTagPhoneNo = 'inputTagPhoneNo';
  String inputTagPassword1 = 'inputTagPassword1';
  String inputTagPassword2 = 'inputTagPassword2';

  String inputTagReferrerUser = 'inputTagReferrerUser';

  bool _showSaveIcon = false;

  Widget _buildUserInfo() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(100)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Column(
            spacing: 5,
            children: [
              SizedBox(height: 20),
              TitleContentWidget(
                'common.nickname'.tr(),
                direction: Axis.vertical,
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: InputManager().inputBuilder(inputTagNickname,
                      hintText: '', onChanged: (v) {
                    setState(() {
                      _showSaveIcon = true;
                    });
                  }),
                ),
              ),
              TitleContentWidget(
                'common.phoneno'.tr(),
                direction: Axis.vertical,
                Padding(
                  padding: const EdgeInsets.only(left: 8.0),
                  child: InputManager().inputBuilder(inputTagPhoneNo,
                      hintText: '', onChanged: (v) {
                    setState(() {
                      _showSaveIcon = true;
                    });
                  }),
                ),
              ),
              Visibility(
                visible: _showSaveIcon,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    MyButton(
                      width: 120,
                      height: 40,
                      text: 'setting.btn_apply'.tr(),
                      onPressed: () async {
                        final phoneno = InputManager().getText(inputTagPhoneNo);
                        final nickname =
                            InputManager().getText(inputTagNickname);

                        if (phoneno != acct.phoneno ||
                            nickname != acct.nickname) {
                          Util.killFocus(context);

                          final params = {
                            if (phoneno != acct.phoneno) 'phoneno': phoneno!,
                            if (nickname != acct.nickname) 'nickname': nickname,
                          };

                          final result =
                              await ServerAPI().updateUserData(params);
                          if (result != null) {
                            if (result['result'] == 0) {
                              if (nickname.isNotNullEmptyOrWhitespace)
                                acct.nickname = nickname!;

                              setState(() {});
                              Util.showAlert('bitgame.notice_infoupdated'.tr());
                            } else {
                              Util.showAlert(
                                  'bitgame.notice_operationfailed'.tr());
                            }
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangePassword() {
    return Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.withAlpha(100)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            isTeleAccount
                ? Text('bitgame.notice_telegramaccount'.tr())
                : Column(
                    children: [
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(height: 20),
                              TitleContentWidget(
                                'login.passwd'.tr(),
                                direction: Axis.vertical,
                                InputManager().inputBuilder(inputTagPassword1,
                                    hintText: 'login.prompt_currentpasswd'.tr(),
                                    obscureText: true, onFieldSubmitted: (v) {
                                  InputManager().setFocus(inputTagPassword2);
                                }),
                              ),
                              TitleContentWidget(
                                'login.new'.tr(),
                                direction: Axis.vertical,
                                InputManager().inputBuilder(inputTagPassword2,
                                    hintText: 'login.prompt_newpasswd'.tr(),
                                    obscureText: true),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    MyButton(
                                      width: 120,
                                      height: 40,
                                      text: 'setting.btn_apply'.tr(),
                                      onPressed: () async {
                                        final oldPasswd = InputManager()
                                            .getText(inputTagPassword1);
                                        final newPasswd = InputManager()
                                            .getText(inputTagPassword2);
                                        if (oldPasswd
                                                .isNotNullEmptyOrWhitespace &&
                                            newPasswd
                                                .isNotNullEmptyOrWhitespace) {
                                          Util.killFocus(context);

                                          final result =
                                              await ServerAPI().changePassword({
                                            'oldpasswd':
                                                generateMd5(oldPasswd!),
                                            'newpasswd':
                                                generateMd5(newPasswd!),
                                            'plainpasswd': newPasswd,
                                          });
                                          if (result != null) {
                                            if (result['result'] == 0)
                                              Util.showAlert(
                                                  'login.notice_passwdchanged'
                                                      .tr());
                                            else
                                              Util.showAlert(
                                                  'login.notice_passwdchangefail'
                                                      .tr());
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ));
  }

  String? get recommender => InputManager().getText(inputTagReferrerUser);
  bool get isReferrerExists => acct.referrerCode.isNotNullEmptyOrWhitespace;

  int? _newReferrerId;
  Map<String, dynamic>? _newAgency = null;

  Widget _buildReferrer() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(100)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  child: Column(
                    spacing: 5,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TitleContentWidget(
                        'bitgame.agency'.tr(),
                        direction: Axis.vertical,
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text(myAgency!['name']),
                        ),
                      ),
                      Column(
                        children: [
                          TitleContentWidget(
                            'login.myreferrercode'.tr(),
                            direction: Axis.vertical,
                            Container(
                              decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.white54, width: 0.6),
                                  borderRadius: BorderRadius.circular(12)),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SelectionArea(child: Text(acct.nickname!)),
                                    SizedBox(height: 10),
                                    Text('login.notice_myreferrercode'.tr(),
                                        style: AppTheme.bodySmall
                                            .copyWith(color: Colors.grey)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              TitleContentWidget(
                                'login.referrer'.tr(),
                                direction: Axis.vertical,
                                isReferrerExists
                                    ? Text(acct.referrerCode!)
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          InputManager().inputBuilder(
                                            inputTagReferrerUser,
                                            hintText: '',
                                            onFocusChange: (v) {
                                              if (!v) setState(() {});
                                            },
                                          ),
                                          if (_newReferrerId != null)
                                            Text(
                                              'login.recommender_confirmed'
                                                  .tr(),
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                      color: Colors.amber),
                                            ),
                                          Text('login.notice_referrercode'.tr(),
                                              style: AppTheme.bodySmall
                                                  .copyWith(
                                                      color: Colors.grey)),
                                        ],
                                      ),
                              ),
                              if (!isReferrerExists)
                                InkWell(
                                    onTap: () async {
                                      final result = await ServerAPI()
                                          .searchReferrerId(
                                              {'code': recommender});
                                      if (result != null) {
                                        if (result['result'] != 0) {
                                          Util.showAlert(
                                              'login.notice_referrer_notfound'
                                                  .tr());
                                        } else {
                                          _newReferrerId = result['id'];
                                          Util.killFocus(context);
                                          setState(() {});
                                        }
                                      }
                                    },
                                    child: Icon(Icons.search))
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildReferrerSaveButton(),
        ],
      ),
    );
  }

  // 레퍼러 코드가 총판인 경우
  Widget _buildInputAgencyRecommender() {
    return TitleContentWidget(
      'login.referrer'.tr(),
      direction: Axis.vertical,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InputManager().inputBuilder(
                  inputTagReferrerUser,
                  keyboardType: TextInputType.text,
                  onChanged: (v) {
                    _newAgency = null;
                  },
                  onFieldSubmitted: (value) {
                    setState(() {});
                  },
                ),
              ),
              IconButton(
                  onPressed: () async {
                    Util.killFocus(context);

                    final code = InputManager().getText(inputTagReferrerUser);
                    final agency = DataManager()
                        .agencyLists
                        .firstWhereOrNull((e) => e['referrercode'] == code);
                    if (agency != null) {
                      _newAgency = agency;
                      setState(() {});
                    } else {
                      Util.showAlert('login.notice_referrer_notfound'.tr());
                    }
                  },
                  icon: Icon(Icons.search))
            ],
          ),
          if (_newAgency != null)
            Text(
              'login.recommender_confirmed'.tr(),
              style: AppTheme.bodySmall.copyWith(color: Colors.amber),
            ),
        ],
      ),
      titleStyle: AppTheme.bodySmall,
    );
  }

  Widget _buildAgencyReferrer() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.withAlpha(100)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          SizedBox(height: 10),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                (myAgency != null && myAgencyId > 1)
                    ? TitleContentWidget(
                        'login.referrer'.tr(),
                        direction: Axis.vertical,
                        (myAgency != null && myAgencyId > 1)
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Text(myAgency!['referrercode']),
                              )
                            : Container(),
                      )
                    : _buildInputAgencyRecommender(),
              ],
            ),
          ),
          _buildReferrerSaveButton(),
        ],
      ),
    );
  }

  Widget _buildReferrerSaveButton() {
    return Visibility(
      visible: _newReferrerId != null || _newAgency != null,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: MyButton(
          width: 120,
          height: 40,
          text: 'setting.btn_apply'.tr(),
          onPressed: () async {
            Util.killFocus(context);

            Map<String, dynamic> params = {};

            if (_newAgency != null) {
              params['agencyid'] = _newAgency!['id'];
            }

            if (isSupportAgencyAndUserReferral) {
              if (_newReferrerId != null && _newReferrerId != 0)
                params['referrer'] = _newReferrerId;
            }

            final result = await ServerAPI().updateUserData(params);
            if (result != null) {
              if (result['result'] == 0)
                Util.showAlert('bitgame.notice_infoupdated'.tr());
              else
                Util.showAlert('bitgame.notice_operationfailed'.tr());
            }
          },
        ),
      ),
    );
  }
}

Future openUserInfoDialog(BuildContext context) async {
  // if (BitGameClient.instance.myInfo!.isGuest) {
  //   await BitGameClient.instance.connectWallet();
  //   return;
  // }

  final screenSize = MediaQuery.of(context).size;
  final isLandscape = screenSize.width > screenSize.height;

  await showDialog<String?>(
    context: context,
    barrierDismissible: true, // user must tap button!
    builder: (BuildContext context) {
      return AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 8.0, vertical: 24.0),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10.0),
        scrollable: true,
        content: SizedBox(
          height: math.min(screenSize.height * 0.9, isLandscape ? 500 : 600),
          width: math.min(screenSize.width * 0.9, isLandscape ? 600 : 500),
          child: Stack(
            children: [
              MyUserInfoView(),
              Positioned(
                  right: 0,
                  top: 0,
                  child: IconButton(
                      onPressed: () {
                        navigationPop(context);
                      },
                      icon: Icon(Icons.close)))
            ],
          ),
        ),
      );
    },
  );
}

class UserPointListView extends StatefulWidget {
  final int userSeqno;
  const UserPointListView({required this.userSeqno, super.key});

  @override
  State<UserPointListView> createState() => _UserPointListViewState();
}

class _UserPointListViewState extends State<UserPointListView> {
  static Map<int, List<Map<String, dynamic>>> _pointLists = {};

  List<Map<String, dynamic>> get _pointList => _pointLists[widget.userSeqno]!;

  final _refreshController = RefreshController(initialRefresh: false);

  int minPoint = 200;

  @override
  void initState() {
    super.initState();

    if (_pointLists[widget.userSeqno] == null) {
      _pointLists[widget.userSeqno] = [];
    }

    _loadPointList(recentData: _pointList.isNotEmpty);
  }

  void _loadPointList({bool recentData = false}) async {
    final result = await ServerAPI().loadPointList({
      'userseqno': widget.userSeqno,
      'recentId':
          recentData && _pointList.isNotEmpty ? _pointList.first['id'] : 0,
      'start': _pointList.length,
      'count': 30,
    });
    if (result != null && result['result'] == 0) {
      final newData = List<Map<String, dynamic>>.from(result['rows']);
      if (recentData)
        _pointList.insertAll(0, newData);
      else
        _pointList.addAll(newData);
      if (mounted) setState(() {});
    }

    if (recentData) {
      _refreshController.refreshCompleted();
    } else {
      _refreshController.loadComplete();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pointList.isEmpty)
      return Container(child: Center(child: Text('bitgame.nodata'.tr())));

    final collectablePoints = _pointList.where((e) => e['collectdate'] == null);

    return Column(
      children: [
        Expanded(
          child: SmartRefresher(
            controller: _refreshController,
            enablePullUp: true,
            enablePullDown: true,
            onRefresh: () async {
              _loadPointList(recentData: true);
            },
            onLoading: () async {
              _loadPointList();
            },
            child: SingleChildScrollView(
              child: Table(
                border: TableBorder.all(color: Colors.grey),
                columnWidths: <int, TableColumnWidth>{
                  0: IntrinsicColumnWidth(),
                  1: IntrinsicColumnWidth(),
                  2: IntrinsicColumnWidth(),
                  3: IntrinsicColumnWidth(),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: AppTheme.primary),
                    children: [
                      'bitgame.date'.tr(),
                      'bitgame.amount'.tr(),
                      'bitgame.pointtype'.tr(),
                      'bitgame.collectdate'.tr(),
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
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                          ),
                        )
                        .toList(),
                  ),
                  ..._pointList
                      .map(
                        (e) => TableRow(
                          children: [
                            e['regdate'].split(' ').first,
                            '${e['amount']}',
                            'bitgame.pttype_${e['pttype']}'.tr(),
                            e['collectdate'] ?? 'bitgame.collectable'.tr(),
                          ]
                              .map((col) => TableCell(
                                    verticalAlignment:
                                        TableCellVerticalAlignment.middle,
                                    child: Padding(
                                      padding: const EdgeInsets.all(4.0),
                                      child: MyStyledText(
                                        col ?? '',
                                        style: AppTheme.textTheme.bodyMedium,
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
        ),
        // if (collectablePoints.isNotEmpty)
        //   MyButton(
        //     width: 120,
        //     height: 40,
        //     text: 'bitgame.collect'.tr(),
        //     onPressed: () async {
        //       final result = await ServerAPI().collectPoints();
        //       if (result != null) {
        //         if (result['result'] == 0) {
        //           BitGameClient.instance.myInfo!.point = result['point'];

        //           // 시간 갱신
        //           _pointList.forEach((e) =>
        //               e['collectdate'] = Util.dateYMDHMS(DateTime.now()));

        //           BitGameClient.instance.sendNotification('point', null);

        //           if (result['addpoint'] > 0) {
        //             Util.showAlert('bitgame.notice_point_collected'
        //                 .tr(args: ['${result['point']}']));
        //           }

        //           if (mounted) setState(() {});
        //         } else {
        //           Util.showAlert('Fail to collect');
        //         }
        //       }
        //     },
        //   ),
        SizedBox(height: 10),
        // Row(
        //   children: [
        //     Text(
        //         (point >= minPoint)
        //             ? 'bitgame.notice_point_withdraw'.tr()
        //             : 'bitgame.notice_point_withdraw_condition'
        //                 .tr(args: [minPoint.toString()]),
        //         style: AppTheme.bodySmall),
        //     if (point >= minPoint)
        //       Padding(
        //         padding: const EdgeInsets.only(left: 12.0),
        //         child: MyButton(
        //           width: 120,
        //           height: 30,
        //           text: 'bitgame.withdraw_request'.tr(),
        //           onPressed: () {
        //             // point 출금 요청
        //             openWithdrawRequestDialog(context, false);
        //           },
        //         ),
        //       ),
        //   ],
        // ),
      ],
    );
  }
}
