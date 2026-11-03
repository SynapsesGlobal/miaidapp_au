import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// 商品媒体相册：视频（若有）排在第一页，后面是多张图片，可左右滑动。
/// 底部有圆点指示，右上角显示“当前页/总数”；点图片可全屏查看并缩放。
///
/// 接口字段：`images`（URL 数组，第一张是封面）、`video`（URL 或 null）。
/// 旧版接口只有单张 `image` 时也能正常显示。
class ProductMediaGallery extends StatefulWidget {
  final List<String> images;
  final String? video;
  final double height;

  const ProductMediaGallery({
    super.key,
    required this.images,
    this.video,
    this.height = 360,
  });

  /// 从商品 JSON 读取媒体字段。
  factory ProductMediaGallery.fromProduct(Map product, {double height = 360}) {
    return ProductMediaGallery(
      images: imagesOf(product),
      video: videoOf(product),
      height: height,
    );
  }

  static List<String> imagesOf(Map product) {
    final raw = product['images'];
    final list = <String>[];
    if (raw is List) {
      for (final item in raw) {
        final url = item?.toString() ?? '';
        if (url.isNotEmpty) list.add(url);
      }
    }
    if (list.isEmpty) {
      final single = product['image']?.toString() ?? '';
      if (single.isNotEmpty) list.add(single);
    }
    return list;
  }

  static String? videoOf(Map product) {
    final url = product['video']?.toString() ?? '';
    return url.isEmpty ? null : url;
  }

  @override
  State<ProductMediaGallery> createState() => _ProductMediaGalleryState();
}

class _MediaItem {
  final String url;
  final bool isVideo;
  const _MediaItem(this.url, {this.isVideo = false});
}

class _ProductMediaGalleryState extends State<ProductMediaGallery> {
  final PageController _controller = PageController();
  final ValueNotifier<int> _page = ValueNotifier<int>(0);

  List<_MediaItem> get _items => [
        if (widget.video != null) _MediaItem(widget.video!, isVideo: true),
        ...widget.images.map((url) => _MediaItem(url)),
      ];

  @override
  void dispose() {
    _controller.dispose();
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    if (items.isEmpty) {
      return Container(
        height: widget.height,
        width: double.infinity,
        color: Colors.grey[200],
        child: Center(
          child: Icon(Icons.image_not_supported_outlined,
              color: Colors.grey[400], size: 56),
        ),
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: items.length,
            onPageChanged: (index) => _page.value = index,
            itemBuilder: (context, index) {
              final item = items[index];
              if (item.isVideo) {
                return _ProductVideoPlayer(
                  url: item.url,
                  pageIndex: index,
                  currentPage: _page,
                );
              }
              return GestureDetector(
                onTap: () => _openFullScreen(context, items, index),
                child: _networkImage(item.url, widget.height),
              );
            },
          ),
          if (items.length > 1) ...[
            Positioned(
              top: 12,
              right: 12,
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, page, _) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${page + 1}/${items.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 10,
              left: 0,
              right: 0,
              child: ValueListenableBuilder<int>(
                valueListenable: _page,
                builder: (context, page, _) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < items.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == page ? 16 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == page
                              ? Colors.white
                              : Colors.white.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openFullScreen(
      BuildContext context, List<_MediaItem> items, int index) {
    final images = items.where((i) => !i.isVideo).map((i) => i.url).toList();
    final initial = images.indexOf(items[index].url);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FullScreenImages(
          images: images,
          initialIndex: initial < 0 ? 0 : initial,
        ),
      ),
    );
  }
}

Widget _networkImage(String url, double height) {
  return CachedNetworkImage(
    imageUrl: url,
    width: double.infinity,
    height: height,
    fit: BoxFit.cover,
    placeholder: (context, url) => Container(
      height: height,
      color: Colors.grey[100],
      child: const Center(child: CupertinoActivityIndicator()),
    ),
    errorWidget: (context, url, error) => Container(
      height: height,
      color: Colors.grey[200],
      child: Center(
        child: Icon(Icons.broken_image_outlined,
            color: Colors.grey[400], size: 56),
      ),
    ),
  );
}

/// 相册里的视频页：点击播放/暂停，滑到其他页时自动暂停。
class _ProductVideoPlayer extends StatefulWidget {
  final String url;
  final int pageIndex;
  final ValueNotifier<int> currentPage;

  const _ProductVideoPlayer({
    required this.url,
    required this.pageIndex,
    required this.currentPage,
  });

  @override
  State<_ProductVideoPlayer> createState() => _ProductVideoPlayerState();
}

class _ProductVideoPlayerState extends State<_ProductVideoPlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setLooping(true);
      setState(() => _ready = true);
    }).catchError((Object _) {
      if (mounted) setState(() => _failed = true);
    });
    _controller.addListener(_onControllerChanged);
    widget.currentPage.addListener(_onPageChanged);
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  void _onPageChanged() {
    if (widget.currentPage.value != widget.pageIndex &&
        _controller.value.isPlaying) {
      _controller.pause();
    }
  }

  @override
  void dispose() {
    widget.currentPage.removeListener(_onPageChanged);
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    if (!_ready) return;
    _controller.value.isPlaying ? _controller.pause() : _controller.play();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return Container(
        color: Colors.black87,
        child: Center(
          child: Icon(Icons.videocam_off_outlined,
              color: Colors.grey[400], size: 56),
        ),
      );
    }
    if (!_ready) {
      return Container(
        color: Colors.black87,
        child: const Center(
            child: CupertinoActivityIndicator(color: Colors.white)),
      );
    }

    final playing = _controller.value.isPlaying;
    return GestureDetector(
      onTap: _toggle,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Center(
              child: AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: VideoPlayer(_controller),
              ),
            ),
            if (!playing)
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 44),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                _controller,
                allowScrubbing: true,
                padding: const EdgeInsets.only(bottom: 22),
                colors: VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white.withOpacity(0.4),
                  backgroundColor: Colors.white.withOpacity(0.2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 全屏图片查看：左右滑动切换，双指缩放。
class _FullScreenImages extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const _FullScreenImages({required this.images, required this.initialIndex});

  @override
  State<_FullScreenImages> createState() => _FullScreenImagesState();
}

class _FullScreenImagesState extends State<_FullScreenImages> {
  late final PageController _controller =
      PageController(initialPage: widget.initialIndex);
  late int _page = widget.initialIndex;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: widget.images.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, index) => InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(
                        child: CupertinoActivityIndicator(color: Colors.white)),
                    errorWidget: (context, url, error) => Icon(
                        Icons.broken_image_outlined,
                        color: Colors.grey[400],
                        size: 56),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            if (widget.images.length > 1)
              Positioned(
                top: 20,
                left: 0,
                right: 0,
                child: Center(
                  child: Text(
                    '${_page + 1}/${widget.images.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
