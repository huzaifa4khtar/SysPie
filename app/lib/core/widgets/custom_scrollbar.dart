import 'package:flutter/material.dart';

/// A custom horizontal scrollbar with a thin track and draggable thumb.
/// Replaces the default Flutter scrollbar for a more minimal, app-specific
/// look, and shows on hover through an AnimatedOpacity in the parent widget.
class CustomHorizontalScrollbar extends StatefulWidget {
  final ScrollController controller;
  final Color trackColor;
  final Color thumbColor;

  const CustomHorizontalScrollbar({
    super.key,
    required this.controller,
    required this.trackColor,
    required this.thumbColor,
  });

  @override
  State<CustomHorizontalScrollbar> createState() =>
      _CustomHorizontalScrollbarState();
}

class _CustomHorizontalScrollbarState extends State<CustomHorizontalScrollbar> {
  bool _isDragging = false;

  ScrollController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final trackHeight = constraints.maxHeight;

        if (!_controller.hasClients || trackWidth <= 0) {
          return _buildTrack(trackWidth, trackHeight, 0, 0);
        }

        final position = _controller.position;
        final maxExtent = position.maxScrollExtent;
        if (maxExtent <= 0) {
          return _buildTrack(trackWidth, trackHeight, 0, trackWidth);
        }

        final viewportDimension = position.viewportDimension;
        final contentDimension = viewportDimension + maxExtent;

        final thumbWidth = (viewportDimension / contentDimension) * trackWidth;
        final thumbOffset =
            (position.pixels / maxExtent) * (trackWidth - thumbWidth);

        return GestureDetector(
          onHorizontalDragStart: (details) {
            _isDragging = true;
            final thumbCenter = thumbOffset + thumbWidth / 2;
            final dragRatio =
                (details.localPosition.dx - thumbCenter) / thumbWidth;
            if (dragRatio.abs() < 1.5) {
              _controller.jumpTo(
                _controller.offset + dragRatio * maxExtent * 0.1,
              );
            }
          },
          onHorizontalDragUpdate: (details) {
            if (_isDragging) {
              final dx = details.delta.dx;
              final scrollDelta = (dx / trackWidth) * contentDimension;
              _controller.jumpTo(
                (_controller.offset + scrollDelta).clamp(0.0, maxExtent),
              );
            }
          },
          onHorizontalDragEnd: (_) {
            _isDragging = false;
          },
          onTapDown: (details) {
            final tapX = details.localPosition.dx;
            final thumbCenter = thumbOffset + thumbWidth / 2;
            final jumpDistance =
                (tapX - thumbCenter) / thumbWidth * viewportDimension;
            _controller.jumpTo(
              (_controller.offset + jumpDistance).clamp(0.0, maxExtent),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: _buildTrack(trackWidth, trackHeight, thumbOffset, thumbWidth),
        );
      },
    );
  }

  Widget _buildTrack(
    double trackWidth,
    double trackHeight,
    double thumbOffset,
    double thumbWidth,
  ) {
    return Container(
      width: trackWidth,
      height: trackHeight,
      color: widget.trackColor,
      child: Stack(
        children: [
          Positioned(
            left: thumbOffset,
            top: 2,
            bottom: 2,
            width: thumbWidth.clamp(0.0, trackWidth),
            child: Container(
              decoration: BoxDecoration(
                color: _isDragging
                    ? widget.thumbColor.withValues(alpha: 0.9)
                    : widget.thumbColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A custom vertical scrollbar with a thin track and draggable thumb.
/// Replaces the default Flutter scrollbar for a more minimal, app-specific
/// look, and shows on hover through an AnimatedOpacity in the parent widget.
class CustomVerticalScrollbar extends StatefulWidget {
  final ScrollController controller;
  final Color trackColor;
  final Color thumbColor;

  const CustomVerticalScrollbar({
    super.key,
    required this.controller,
    required this.trackColor,
    required this.thumbColor,
  });

  @override
  State<CustomVerticalScrollbar> createState() =>
      _CustomVerticalScrollbarState();
}

class _CustomVerticalScrollbarState extends State<CustomVerticalScrollbar> {
  bool _isDragging = false;

  ScrollController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final trackWidth = constraints.maxWidth;
        final trackHeight = constraints.maxHeight;

        if (!_controller.hasClients || trackHeight <= 0) {
          return _buildTrack(trackWidth, trackHeight, 0, 0);
        }

        final position = _controller.position;
        final maxExtent = position.maxScrollExtent;
        if (maxExtent <= 0) {
          return _buildTrack(trackWidth, trackHeight, 0, trackHeight);
        }

        final viewportDimension = position.viewportDimension;
        final contentDimension = viewportDimension + maxExtent;

        final thumbHeight =
            (viewportDimension / contentDimension) * trackHeight;
        final thumbOffset =
            (position.pixels / maxExtent) * (trackHeight - thumbHeight);

        return GestureDetector(
          onVerticalDragStart: (details) {
            _isDragging = true;
            final thumbCenter = thumbOffset + thumbHeight / 2;
            final dragRatio =
                (details.localPosition.dy - thumbCenter) / thumbHeight;
            if (dragRatio.abs() < 1.5) {
              _controller.jumpTo(
                _controller.offset + dragRatio * maxExtent * 0.1,
              );
            }
          },
          onVerticalDragUpdate: (details) {
            if (_isDragging) {
              final dy = details.delta.dy;
              final scrollDelta = (dy / trackHeight) * contentDimension;
              _controller.jumpTo(
                (_controller.offset + scrollDelta).clamp(0.0, maxExtent),
              );
            }
          },
          onVerticalDragEnd: (_) {
            _isDragging = false;
          },
          onTapDown: (details) {
            final tapY = details.localPosition.dy;
            final thumbCenter = thumbOffset + thumbHeight / 2;
            final jumpDistance =
                (tapY - thumbCenter) / thumbHeight * viewportDimension;
            _controller.jumpTo(
              (_controller.offset + jumpDistance).clamp(0.0, maxExtent),
            );
          },
          behavior: HitTestBehavior.opaque,
          child: _buildTrack(trackWidth, trackHeight, thumbOffset, thumbHeight),
        );
      },
    );
  }

  Widget _buildTrack(
    double trackWidth,
    double trackHeight,
    double thumbOffset,
    double thumbHeight,
  ) {
    return Container(
      width: trackWidth,
      height: trackHeight,
      color: widget.trackColor,
      child: Stack(
        children: [
          Positioned(
            top: thumbOffset,
            left: 2,
            right: 2,
            height: thumbHeight.clamp(0.0, trackHeight),
            child: Container(
              decoration: BoxDecoration(
                color: _isDragging
                    ? widget.thumbColor.withValues(alpha: 0.9)
                    : widget.thumbColor.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(4.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
