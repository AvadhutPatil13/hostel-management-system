import 'package:flutter/material.dart';

class ImagePreviewPage extends StatefulWidget {
  const ImagePreviewPage({
    super.key,
    this.assetPath,
    this.imageUrls = const [],
    this.initialIndex = 0,
    this.title,
  });

  final String? assetPath;
  final List<String> imageUrls;
  final int initialIndex;
  final String? title;

  @override
  State<ImagePreviewPage> createState() => _ImagePreviewPageState();
}

class _ImagePreviewPageState extends State<ImagePreviewPage> {
  late final PageController _controller;
  late int _index;

  List<String> get _urls => widget.imageUrls.isNotEmpty
      ? widget.imageUrls
      : (widget.assetPath == null ? const [] : [widget.assetPath!]);

  @override
  void initState() {
    super.initState();
    final maxIndex = _urls.isEmpty ? 0 : _urls.length - 1;
    _index = widget.initialIndex.clamp(0, maxIndex);
    _controller = PageController(initialPage: _index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _move(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= _urls.length) return;
    _controller.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title ?? 'Photo'),
      ),
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _urls.length,
            onPageChanged: (value) => setState(() => _index = value),
            itemBuilder: (context, index) {
              final source = _urls[index];
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 5,
                  child: source.startsWith('http')
                      ? Image.network(
                          source,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white,
                            size: 64,
                          ),
                        )
                      : Image.asset(source, fit: BoxFit.contain),
                ),
              );
            },
          ),
          if (_urls.length > 1 && _index > 0)
            _navigationButton(
              alignment: Alignment.centerLeft,
              icon: Icons.chevron_left,
              onPressed: () => _move(-1),
            ),
          if (_urls.length > 1 && _index < _urls.length - 1)
            _navigationButton(
              alignment: Alignment.centerRight,
              icon: Icons.chevron_right,
              onPressed: () => _move(1),
            ),
        ],
      ),
    );
  }

  Widget _navigationButton({
    required Alignment alignment,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          color: Colors.white,
          style: IconButton.styleFrom(
            backgroundColor: Colors.black54,
          ),
        ),
      ),
    );
  }
}
