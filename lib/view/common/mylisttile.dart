import 'package:flutter/material.dart';

class MyListTile extends StatelessWidget {
  final Widget? leading;
  final double? leadingWidth;
  final Widget? title;
  final Widget? subtitle;
  final EdgeInsets? padding;
  final void Function()? onTap;
  const MyListTile({
    this.leading,
    this.leadingWidth,
    this.title,
    this.subtitle,
    this.padding,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding ?? const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (leading != null)
              SizedBox(
                  width: leadingWidth ?? 60,
                  child: Row(
                    children: [
                      leading ?? Container(),
                    ],
                  )),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  title ?? Container(),
                  subtitle ?? Container(),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
