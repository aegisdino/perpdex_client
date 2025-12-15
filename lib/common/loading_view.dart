import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'util.dart';

class LoadingView extends StatefulWidget {
  final String mode;

  const LoadingView({required this.mode, super.key});

  @override
  State<LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<LoadingView>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _textController;

  late Animation<double> _scaleAnimation;

  int _currentImageIndex = 0;

  final List<AssetImage> _imageProviders = [
    AssetImage('assets/image/loading1.png'),
    AssetImage('assets/image/loading2.png'),
    AssetImage('assets/image/loading3.png'),
    AssetImage('assets/image/loading4.png'),
    AssetImage('assets/image/loading5.png'),
  ];

  final AssetImage _oneImageProvider =
      AssetImage('assets/logo/loading-logo.gif');

  double viewSize = 200;
  final textColor = Color.fromARGB(255, 217, 114, 10);

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();

    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeInOut,
    ));

    _controller.addListener(() {
      if (_imageLoadCount > 0) {
        final newIndex =
            (_controller.value * _imageLoadCount).floor() % _imageLoadCount;
        if (newIndex != _currentImageIndex && mounted) {
          setState(() {
            _currentImageIndex = newIndex;
          });
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      viewSize = math.max(
          150,
          math.min(MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height) /
              4);

      _preloadImagesAndStart();
    });
  }

  int _imageLoadCount = 0;

  Future _preloadImagesAndStart() async {
    if (widget.mode == 'multi') {
      // 모든 이미지 프리로딩
      for (final imageProvider in _imageProviders) {
        await precacheImage(imageProvider, context);
        if (++_imageLoadCount > 0) {
          if (mounted)
            setState(() {});
          else
            break;
        }
      }
    } else if (widget.mode == 'one') {
      await precacheImage(_oneImageProvider, context);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 배경
        Container(
          color: Colors.black54,
        ),
        if (widget.mode == 'one') _buildOneImage(),
        if (widget.mode == 'multi') _buildLoadingImages(),
      ],
    );
  }

  Widget _buildOneImage() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image(
          image: _oneImageProvider,
        ),
      ],
    );
  }

  Widget _buildLoadingImages() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: viewSize,
          height: viewSize - 1,
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: Alignment.center,
              radius: 0.5,
              colors: [
                Colors.black54,
                Colors.transparent,
              ],
              stops: [0.6, 1.0],
            ),
          ),
          child: ShaderMask(
            shaderCallback: (bounds) => RadialGradient(
              center: Alignment.center,
              radius: 0.5,
              colors: [
                Colors.black87,
                Colors.transparent,
              ],
              stops: [0.5, 1.0],
            ).createShader(bounds),
            blendMode: BlendMode.dstIn,
            child: Image(
              image: _imageProviders[_currentImageIndex],
              fit: BoxFit.cover,
              width: viewSize * 0.9,
              height: viewSize * 0.9,
              filterQuality: FilterQuality.low,
            ),
          ),
        ),
        Transform.translate(
          offset: Offset(0, -20),
          child: _buildLoadingTextAnim(),
        )
      ],
    );
  }

  Widget _buildLoadingTextAnim() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Text(
            'Loading',
            style: AppTheme.headlineLargeBold.copyWith(
              color: textColor,
              fontStyle: FontStyle.italic,
              shadows: [
                Shadow(
                  blurRadius: 5.0,
                  color: textColor,
                  offset: Offset(0, 0),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
