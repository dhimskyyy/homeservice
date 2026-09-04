import 'package:flutter/material.dart';

class SpinningRefreshButton extends StatefulWidget {
  final Future<void> Function() onRefresh;
  final Color? color;
  final double size;
  final String tooltip;

  const SpinningRefreshButton({
    super.key,
    required this.onRefresh,
    this.color,
    this.size = 20,
    this.tooltip = 'Muat Ulang',
  });

  @override
  State<SpinningRefreshButton> createState() => _SpinningRefreshButtonState();
}

class _SpinningRefreshButtonState extends State<SpinningRefreshButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleTap() async {
    if (_controller.isAnimating) return;

    _controller.forward(from: 0.0);
    try {
      await widget.onRefresh();
    } finally {
      if (mounted && _controller.isAnimating) {
        // Biarkan putaran selesai sampai 1 putaran penuh
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: widget.size,
      tooltip: widget.tooltip,
      onPressed: _handleTap,
      icon: RotationTransition(
        turns: _controller,
        child: Icon(
          Icons.refresh,
          color: widget.color,
          size: widget.size,
        ),
      ),
    );
  }
}
