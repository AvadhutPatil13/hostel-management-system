import 'dart:async';

import 'package:flutter/material.dart';

import '../../config/room_asset_images.dart';
import '../../services/api_service.dart';

class StudentAvailableRoomsPage extends StatefulWidget {
  const StudentAvailableRoomsPage({super.key});

  @override
  State<StudentAvailableRoomsPage> createState() =>
      _StudentAvailableRoomsPageState();
}

class _StudentAvailableRoomsPageState
    extends State<StudentAvailableRoomsPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _rooms = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rooms = await ApiService.availableRooms();
      if (!mounted) return;
      setState(() => _rooms = rooms);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to load available rooms.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredRooms {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _rooms;

    return _rooms.where((room) {
      final searchable = [
        room['building'],
        room['roomNo'],
        room['type'],
        room['floor'],
      ].map((value) => value?.toString().toLowerCase() ?? '').join(' ');
      return searchable.contains(query);
    }).toList();
  }

  int _number(Map<String, dynamic> room, String key, [int fallback = 0]) {
    return int.tryParse(room[key]?.toString() ?? '') ?? fallback;
  }

  List<String> _photosFor(Map<String, dynamic> room) {
    final stored = room['roomImages'];
    final storedUrls = stored is List
        ? stored
            .map((value) => value.toString().trim())
            .where((value) => value.startsWith('http'))
            .toList()
        : <String>[];

    return [
      ...storedUrls,
      ...RoomAssetImages.forRoom(room),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rooms = _filteredRooms;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'Available Rooms',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            'Browse rooms with available beds and view their photos.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search building, room or type',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: _searchController.clear,
                      icon: const Icon(Icons.clear),
                    ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 18),
          if (_loading && _rooms.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null && _rooms.isEmpty)
            _buildError(context)
          else if (rooms.isEmpty)
            _buildEmpty(context)
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 1000
                    ? 3
                    : constraints.maxWidth >= 650
                        ? 2
                        : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rooms.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: columns == 1 ? 0.88 : 0.82,
                  ),
                  itemBuilder: (context, index) => _buildRoomCard(
                    context,
                    rooms[index],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(BuildContext context, Map<String, dynamic> room) {
    final photos = _photosFor(room);
    final capacity = _number(room, 'capacity', 1);
    final occupied = _number(room, 'occupiedCount');
    final available = (capacity - occupied).clamp(0, capacity);
    final building = room['building']?.toString() ?? 'Building';
    final roomNo = room['roomNo']?.toString() ?? '-';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: RoomPhotoCarousel(
              photos: photos,
              title: '$building - Room $roomNo',
              brokenImage: _brokenImage(context),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$building - Room $roomNo',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${room['type'] ?? 'Room'} • Floor ${room['floor'] ?? 0}',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.bed_outlined,
                      size: 19,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '$available ${available == 1 ? 'bed' : 'beds'} available',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _brokenImage(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Center(child: Icon(Icons.broken_image_outlined)),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          children: [
            const Icon(Icons.meeting_room_outlined, size: 48),
            const SizedBox(height: 12),
            Text(
              'No available rooms found.',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 44),
            const SizedBox(height: 10),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class RoomPhotoCarousel extends StatefulWidget {
  const RoomPhotoCarousel({
    super.key,
    required this.photos,
    required this.title,
    required this.brokenImage,
  });

  final List<String> photos;
  final String title;
  final Widget brokenImage;

  @override
  State<RoomPhotoCarousel> createState() => _RoomPhotoCarouselState();
}

class _RoomPhotoCarouselState extends State<RoomPhotoCarousel> {
  late final PageController _controller;
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _userInteracting = false;
  double _scrollOffset = 0;

  bool get _isPageMode => widget.photos.length <= 4;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.84);
    _scrollController = ScrollController();
    _startAutoScroll();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    if (widget.photos.length < 2) return;
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted || _userInteracting) return;

      if (_isPageMode && _controller.hasClients) {
        final current = (_controller.page ?? 0).round();
        final next = (current + 1) % widget.photos.length;
        _controller.animateToPage(
          next,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      } else if (_scrollController.hasClients) {
        final max = _scrollController.position.maxScrollExtent;
        if (max <= 0) return;
        _scrollOffset += 238;
        if (_scrollOffset >= max) _scrollOffset = 0;
        _scrollController.animateTo(
          _scrollOffset,
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _setInteracting(bool value) {
    if (mounted) setState(() => _userInteracting = value);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) return widget.brokenImage;

    final gallery = _isPageMode
        ? PageView.builder(
            controller: _controller,
            itemCount: widget.photos.length,
            onPageChanged: (_) => setState(() {}),
            itemBuilder: (context, index) => _buildPhoto(context, index),
          )
        : ListView.separated(
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: widget.photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) => _buildPhoto(context, index),
          );

    return Listener(
      onPointerDown: (_) => _setInteracting(true),
      onPointerUp: (_) => _setInteracting(false),
      onPointerCancel: (_) => _setInteracting(false),
      child: gallery,
    );
  }

  Widget _buildPhoto(BuildContext context, int index) {
    final source = widget.photos[index];
    return Padding(
      padding: EdgeInsets.only(
        left: _isPageMode && index == 0 ? 4 : 0,
        right: _isPageMode && index == widget.photos.length - 1 ? 4 : 0,
      ),
      child: SizedBox(
        width: 230,
        child: GestureDetector(
          onTap: () => _openZoomPreview(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: source.startsWith('http')
                ? Image.network(
                    source,
                    fit: BoxFit.cover,
                    cacheWidth: 640,
                    errorBuilder: (_, __, ___) => widget.brokenImage,
                  )
                : Image.asset(
                    source,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => widget.brokenImage,
                  ),
          ),
        ),
      ),
    );
  }

  void _openZoomPreview(BuildContext context, int initialIndex) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => _RoomZoomPreview(
        photos: widget.photos,
        initialIndex: initialIndex,
        title: widget.title,
      ),
    );
  }
}

class _RoomZoomPreview extends StatefulWidget {
  const _RoomZoomPreview({
    required this.photos,
    required this.initialIndex,
    required this.title,
  });

  final List<String> photos;
  final int initialIndex;
  final String title;

  @override
  State<_RoomZoomPreview> createState() => _RoomZoomPreviewState();
}

class _RoomZoomPreviewState extends State<_RoomZoomPreview> {
  late final PageController _pageController;
  late final TransformationController _transformController;
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
    _pageController = PageController(initialPage: _index);
    _transformController = TransformationController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  void _zoom(double factor) {
    final current = _transformController.value.getMaxScaleOnAxis();
    final next = (current * factor).clamp(0.6, 4.0);
    _transformController.value = Matrix4.identity()
      ..scaleByDouble(next, next, next, 1.0);
  }

  void _changeImage(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.photos.length) return;
    _pageController.animateToPage(
      next,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      backgroundColor: Colors.black,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          title: Text(widget.title),
          actions: [
            IconButton(
              tooltip: 'Zoom out',
              onPressed: () => _zoom(0.8),
              icon: const Icon(Icons.zoom_out),
            ),
            IconButton(
              tooltip: 'Reset zoom',
              onPressed: () => _transformController.value = Matrix4.identity(),
              icon: const Icon(Icons.center_focus_strong),
            ),
            IconButton(
              tooltip: 'Zoom in',
              onPressed: () => _zoom(1.25),
              icon: const Icon(Icons.zoom_in),
            ),
          ],
        ),
        body: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _index = index;
                  _transformController.value = Matrix4.identity();
                });
              },
              itemBuilder: (context, index) {
                final source = widget.photos[index];
                return InteractiveViewer(
                  transformationController: _transformController,
                  minScale: 0.6,
                  maxScale: 4,
                  child: Center(
                    child: source.startsWith('http')
                        ? Image.network(source, fit: BoxFit.contain)
                        : Image.asset(source, fit: BoxFit.contain),
                  ),
                );
              },
            ),
            if (_index > 0)
              _arrow(
                alignment: Alignment.centerLeft,
                icon: Icons.chevron_left,
                onPressed: () => _changeImage(-1),
              ),
            if (_index < widget.photos.length - 1)
              _arrow(
                alignment: Alignment.centerRight,
                icon: Icons.chevron_right,
                onPressed: () => _changeImage(1),
              ),
          ],
        ),
      ),
    );
  }

  Widget _arrow({
    required Alignment alignment,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Align(
      alignment: alignment,
      child: IconButton.filled(
        onPressed: onPressed,
        icon: Icon(icon, size: 32),
        style: IconButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: Colors.black54,
        ),
      ),
    );
  }
}
