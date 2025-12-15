import 'package:flutter/material.dart';

class SizeProviderWidget extends StatefulWidget {
  final Widget child;
  final Function(Size) onChildSize;

  const SizeProviderWidget({
    Key? key,
    required this.onChildSize,
    required this.child,
  }) : super(key: key);
  @override
  SizeProviderWidgetState createState() => SizeProviderWidgetState();
}

class SizeProviderWidgetState extends State<SizeProviderWidget> {
  @override
  void initState() {
    ///add size listener for first build
    _onResize();
    super.initState();
  }

  Size? lastSize;

  void _onResize() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      if (context.size is Size) {
        if (lastSize != context.size!) {
          lastSize = context.size!;
          widget.onChildSize(context.size!);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ///add size listener for every build uncomment the fallowing
    _onResize();
    return widget.child;
  }
}
