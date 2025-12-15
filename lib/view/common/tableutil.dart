import 'package:flutter/material.dart';

import '../../common/styles.dart';
import '../../common/theme.dart';

TableRow buildTableHeader(List<String> headers,
    {Color? backgroundColor, TextStyle? style}) {
  return TableRow(
      decoration: BoxDecoration(color: backgroundColor ?? AppTheme.primary),
      children: headers
          .map(
            (e) => TableCell(
              verticalAlignment: TableCellVerticalAlignment.middle,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    e,
                    style: style ??
                        AppTheme.textTheme.bodySmall!
                            .copyWith(color: AppTheme.onPrimary),
                  ),
                ),
              ),
            ),
          )
          .toList());
}

Widget buildCellContent(dynamic col, double fontSize, Color? color) {
  if (col is Widget)
    return col;
  else if (col is String) {
    if (col.startsWith('assets')) {
      return Image.asset(col, color: color);
    } else {
      return MyStyledText(
        col,
        style: TextStyle(fontSize: fontSize, color: color),
      );
    }
  } else if (col is IconData) {
    return Icon(col, color: color);
  }
  return Container();
}

List<TableRow> buildTableContents(
  List<dynamic> list, {
  List<List<dynamic>>? columns,
  List<String> Function(dynamic)? elemFunction,
  Function(int)? onTapRow,
  Function(int, int)? onTapColumn,
  double? fontSize,
  EdgeInsets? cellPadding,
  Color? bgColor1,
  Color? bgColor2,
  int? selectedIndex,
  Color? selectedBgColor,
  Color? selectedTextColor,
}) {
  int row = 0;
  if (list.isEmpty) return [];

  return list
      .asMap()
      .map((rowIndex, e) => MapEntry(
          rowIndex,
          TableRow(
              decoration: BoxDecoration(
                  color: selectedIndex == rowIndex
                      ? selectedBgColor
                      : (row++ % 2) == 1
                          ? (bgColor2 ?? Colors.grey[800])
                          : (bgColor1 ?? Colors.transparent)),
              children: columns != null
                  ? columns[rowIndex]
                      .asMap()
                      .map((colIndex, col) => MapEntry(
                          colIndex,
                          TableCell(
                              verticalAlignment:
                                  TableCellVerticalAlignment.middle,
                              child: InkWell(
                                onTap: () {
                                  if (onTapRow != null) onTapRow(rowIndex);
                                  if (onTapColumn != null)
                                    onTapColumn(rowIndex, colIndex);
                                },
                                child: Center(
                                  child: Padding(
                                    padding: cellPadding ??
                                        const EdgeInsets.symmetric(
                                            horizontal: 2, vertical: 10.0),
                                    child: buildCellContent(
                                      col,
                                      fontSize ?? 14,
                                      selectedIndex == rowIndex
                                          ? selectedTextColor
                                          : null,
                                    ),
                                  ),
                                ),
                              ))))
                      .values
                      .toList()
                  : elemFunction!
                      .call(e)
                      .asMap()
                      .map((colIndex, col) => MapEntry(
                          colIndex,
                          TableCell(
                            verticalAlignment:
                                TableCellVerticalAlignment.middle,
                            child: InkWell(
                              onTap: () {
                                if (onTapRow != null) onTapRow(rowIndex);
                                if (onTapColumn != null)
                                  onTapColumn(rowIndex, colIndex);
                              },
                              child: Center(
                                child: Padding(
                                  padding: cellPadding ??
                                      const EdgeInsets.symmetric(
                                          horizontal: 2, vertical: 10.0),
                                  child: MyStyledText(
                                    col,
                                    style: TextStyle(
                                        fontSize: fontSize ?? 14,
                                        color: selectedIndex == rowIndex
                                            ? selectedTextColor
                                            : null),
                                  ),
                                ),
                              ),
                            ),
                          )))
                      .values
                      .toList())))
      .values
      .toList();
}
