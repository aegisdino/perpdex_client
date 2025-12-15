import 'package:flutter/material.dart';

import '../../common/theme.dart';

class MyTabView extends StatefulWidget {
  final List<String> tabTitles;
  final double? width;
  final int? initialTabIndex;
  final Function(int index)? onSelected;

  const MyTabView({
    required this.tabTitles,
    this.width,
    this.initialTabIndex,
    this.onSelected,
    super.key,
  });

  @override
  State<MyTabView> createState() => MyTabViewState();
}

class MyTabViewState extends State<MyTabView> with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(
        initialIndex: widget.initialTabIndex ?? 0,
        length: widget.tabTitles.length,
        vsync: this);

    _tabController.addListener(() {
      widget.onSelected?.call(_tabController.index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 200,
      child: TabBar(
        tabs: widget.tabTitles
            .map((e) => Padding(
                  padding: EdgeInsets.all(4.0),
                  child: FittedBox(fit: BoxFit.scaleDown, child: Text(e)),
                ))
            .toList(),
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.label,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.dexSecondary,
        dividerHeight: 0,
        onTap: (index) {
          setState(() {});
        },
      ),
    );
  }
}
