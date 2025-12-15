import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '/common/all.dart';
import '../data/chartdata.dart';

class PlotBandRenderer {
  static final yAxisLineUpdateProvider =
      StateProvider<DateTime?>((ref) => null);

  static List<double> yAxisLineValues = [];
  static List<String> yAxisValueTypes = [];

  static void clearLines() {
    yAxisLineValues.clear();
    yAxisValueTypes.clear();
  }

  static void setCurrentPrice(double price) {
    yAxisLineValues.add(price.toPrecision(2));
    yAxisValueTypes.add('current');
  }

  static PlotBand plotHorizLine(
      double yValue, Color color, bool isDashedLine, String text) {
    return PlotBand(
      isVisible: true,
      start: yValue,
      end: yValue,
      text: text,
      shouldRenderAboveSeries: true,
      horizontalTextPadding: '-10',
      horizontalTextAlignment: TextAnchor.end,
      verticalTextAlignment: TextAnchor.middle, // 수직 가운데 정렬
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 0,
      ),
      borderWidth: 1,
      borderColor: color,
      dashArray: isDashedLine ? [5, 5] : [0, 0],
    );
  }

  static PlotBand plotVertLine(
      double xValue, Color color, bool isDashedLine, String text) {
    return PlotBand(
      isVisible: true,
      start: DateTime.fromMillisecondsSinceEpoch(xValue.toInt()),
      end: DateTime.fromMillisecondsSinceEpoch(xValue.toInt()),
      text: text,
      shouldRenderAboveSeries: true,
      verticalTextPadding: '-10',
      verticalTextAlignment: TextAnchor.middle,
      horizontalTextAlignment: TextAnchor.end,
      textStyle: TextStyle(
        color: Colors.white,
        fontSize: 0,
      ),
      borderWidth: 1,
      borderColor: color,
      dashArray: isDashedLine ? [5, 5] : [0, 0],
    );
  }

  static List<PlotBand> getHorizLines(List<double> yAxisLineValues,
      List<String> yAxisValueTypes, Color priceColor) {
    List<PlotBand> bands = yAxisLineValues
        .asMap()
        .map((index, e) => MapEntry(
            index,
            plotHorizLine(
                yAxisLineValues[index],
                yAxisValueTypes[index] == 'bust'
                    ? Colors.red
                    : yAxisValueTypes[index] == 'entry'
                        ? Colors.grey
                        : priceColor,
                yAxisValueTypes[index] == 'current',
                yAxisLineValues[index].toStringAsFixed(2))))
        .values
        .toList();
    return bands;
  }
}

/*
class PriceTagView extends ConsumerStatefulWidget {
  final GlobalKey<SfCartesianChartState> chartKey;
  final ChartViewController chartViewController;

  const PriceTagView({
    required this.chartKey,
    required this.chartViewController,
    super.key,
  });

  @override
  ConsumerState<PriceTagView> createState() => _PriceTagViewState();
}

class _PriceTagViewState extends ConsumerState<PriceTagView> {
  Size? get chartSize {
    final renderBox =
        (widget.chartKey.currentContext?.findRenderObject() as RenderBox?);
    return renderBox != null && renderBox.hasSize ? renderBox.size : null;
  }

  Offset getPositionInChart(double yValue, {bool clamp = false}) {
    if (widget.chartKey.currentContext == null) return Offset.zero;
    final Size size = chartSize!;

    final double xAxisHeight = 20;
    final double yPadding = 10;
    final double chartHeight = size.height - xAxisHeight - yPadding * 2;

    final double minY = widget.chartViewController.minY;
    final double maxY = widget.chartViewController.maxY;

    double ratio = ((yValue - minY) / (maxY - minY));
    if (clamp) ratio = ratio.clamp(0, 1);
    final yPixel = size.height - (xAxisHeight + yPadding + chartHeight * ratio);

    return Offset(size.width, yPixel);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(PlotBandRenderer.yAxisLineUpdateProvider, (previous, next) {
      if (mounted) setState(() {});
    });

    if (widget.chartKey.currentContext == null || chartSize == null)
      return Container();
    if (PlotBandRenderer.yAxisLineValues.isEmpty) return Container();

    List<Widget> widgets = [];

    for (var i = 0; i < PlotBandRenderer.yAxisLineValues.length; i++) {
      final valueType = PlotBandRenderer.yAxisValueTypes[i];
      Offset position = getPositionInChart(PlotBandRenderer.yAxisLineValues[i],
          clamp: valueType == 'entry');

      Color? color;
      String text = '';
      if (valueType == 'current') {
        text = '${PlotBandRenderer.yAxisLineValues[i].toStringAsFixed(3)}';
        color = priceColors[widget.chartViewController.isPriceGoingUp ? 0 : 1];
      } else if (valueType == 'entry') {
        text = 'Entry P.';
        color = Colors.grey;
      } else if (valueType == 'bust') {
        text = 'Bust P.';
        color = Colors.red;
      }

      widgets.add(Positioned(
        left: position.dx - 80,
        top: position.dy - 10,
        child: Container(
          width: 80,
          height: 20,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(10),
              topLeft: Radius.circular(10),
            ),
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.black),
            ),
          ),
        ),
      ));
    }
    return Stack(children: widgets);
  }
}
*/
