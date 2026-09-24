import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 商品图片全屏预览：黑底、左右滑动切换、双指缩放、双击放大/还原、右上角关闭。
///
/// 不引入新依赖，缩放用 Flutter 自带的 InteractiveViewer，图片复用 cached_network_image 的缓存。
Future<void> showProductImagePreview(
  BuildContext context, {
  required List<String> imageUrls,
  int initialIndex = 0,
}) {
  if (imageUrls.isEmpty) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _ProductImagePreview(
        imageUrls: imageUrls,
        initialIndex: initialIndex.clamp(0, imageUrls.length - 1),
      ),
      transitionsBuilder: (_, animation, __, child) =>
          FadeTransition(opacity: animation, child: child),
    ),
  );
}

class _ProductImagePreview extends StatefulWidget {
  const _ProductImagePreview({
    required this.imageUrls,
    required this.initialIndex,
  });

  final List<String> imageUrls;
  final int initialIndex;

  @override
  State<_ProductImagePreview> createState() => _ProductImagePreviewState();
}

class _ProductImagePreviewState extends State<_ProductImagePreview> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _index = widget.initialIndex;

  /// 当前页是否处于放大状态；放大时禁止左右翻页，避免拖动图片时误翻
  bool _zoomed = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            itemCount: widget.imageUrls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (context, i) => _ZoomableImage(
              url: widget.imageUrls[i],
              onZoomChanged: (zoomed) {
                if (zoomed != _zoomed) setState(() => _zoomed = zoomed);
              },
            ),
          ),
          // 顶部：页码 + 关闭
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Center(
                      child: widget.imageUrls.length > 1
                          ? Text(
                              '${_index + 1} / ${widget.imageUrls.length}',
                              style: GoogleFonts.rubik(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                  IconButton(
                    splashRadius: 22,
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 单张可缩放图片：双指缩放、双击在 1x 与 2.5x 之间切换
class _ZoomableImage extends StatefulWidget {
  const _ZoomableImage({required this.url, required this.onZoomChanged});

  final String url;
  final ValueChanged<bool> onZoomChanged;

  @override
  State<_ZoomableImage> createState() => _ZoomableImageState();
}

class _ZoomableImageState extends State<_ZoomableImage>
    with SingleTickerProviderStateMixin {
  final TransformationController _controller = TransformationController();
  late final AnimationController _animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );
  Animation<Matrix4>? _matrixAnimation;
  TapDownDetails? _doubleTapDetails;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_notifyZoom);
    _animation.addListener(() {
      if (_matrixAnimation != null) _controller.value = _matrixAnimation!.value;
    });
  }

  void _notifyZoom() {
    widget.onZoomChanged(_controller.value.getMaxScaleOnAxis() > 1.01);
  }

  @override
  void dispose() {
    _controller.removeListener(_notifyZoom);
    _controller.dispose();
    _animation.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    final current = _controller.value;
    Matrix4 target;
    if (current.getMaxScaleOnAxis() > 1.01) {
      target = Matrix4.identity();
    } else {
      // 以双击点为中心放大到 2.5 倍
      final position = _doubleTapDetails?.localPosition ?? Offset.zero;
      const scale = 2.5;
      target = Matrix4.identity()
        ..translate(-position.dx * (scale - 1), -position.dy * (scale - 1))
        ..scale(scale);
    }
    _matrixAnimation = Matrix4Tween(begin: current, end: target).animate(
      CurvedAnimation(parent: _animation, curve: Curves.easeOut),
    );
    _animation.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onDoubleTapDown: (details) => _doubleTapDetails = details,
      onDoubleTap: _handleDoubleTap,
      child: InteractiveViewer(
        transformationController: _controller,
        minScale: 1,
        maxScale: 4,
        clipBehavior: Clip.none,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: widget.url,
            fit: BoxFit.contain,
            placeholder: (_, __) => const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white70,
              ),
            ),
            errorWidget: (_, __, ___) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
