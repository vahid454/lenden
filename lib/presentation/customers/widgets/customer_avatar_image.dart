import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/providers/customer_photo_providers.dart';

class CustomerAvatarImage extends ConsumerWidget {
  final String initials;
  final String? photoPath;
  final Color color;
  final double size;
  final double fontSize;
  final double? borderWidth;
  final bool expandable;
  final String? viewerTitle;

  const CustomerAvatarImage({
    super.key,
    required this.initials,
    required this.photoPath,
    required this.color,
    this.size = 46,
    this.fontSize = 16,
    this.borderWidth,
    this.expandable = false,
    this.viewerTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final path = photoPath;
    final photo = path == null || path.isEmpty
        ? null
        : ref.watch(customerPhotoBytesProvider(path));
    final bytes = photo?.valueOrNull;
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: borderWidth == null
            ? null
            : Border.all(
                color: color.withValues(alpha: 0.4), width: borderWidth!),
      ),
      child: bytes == null
          ? Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    initials,
                    style: GoogleFonts.poppins(
                      fontSize: fontSize,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  if (photo?.isLoading == true)
                    SizedBox.square(
                      dimension: size * 0.45,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: color,
                      ),
                    ),
                ],
              ),
            )
          : Image.memory(
              bytes,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              filterQuality: FilterQuality.medium,
            ),
    );

    if (!expandable || bytes == null) return avatar;

    return Semantics(
      button: true,
      label: 'Open ${viewerTitle ?? 'customer'} photo',
      child: Tooltip(
        message: 'View photo',
        child: InkWell(
          onTap: () => _openPhoto(context, bytes),
          customBorder: const CircleBorder(),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              avatar,
              Positioned(
                right: -2,
                bottom: -2,
                child: Container(
                  width: 25,
                  height: 25,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Icon(
                    Icons.open_in_full_rounded,
                    size: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openPhoto(BuildContext context, Uint8List bytes) {
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close photo',
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) => _CustomerPhotoViewer(
        bytes: bytes,
        title: viewerTitle,
      ),
      transitionBuilder: (_, animation, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.0).animate(animation),
          child: child,
        ),
      ),
    );
  }
}

class _CustomerPhotoViewer extends StatefulWidget {
  final Uint8List bytes;
  final String? title;

  const _CustomerPhotoViewer({required this.bytes, this.title});

  @override
  State<_CustomerPhotoViewer> createState() => _CustomerPhotoViewerState();
}

class _CustomerPhotoViewerState extends State<_CustomerPhotoViewer> {
  final _controller = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_controller.value != Matrix4.identity()) {
      _controller.value = Matrix4.identity();
      return;
    }

    const scale = 2.5;
    final position = _doubleTapDetails?.localPosition ?? Offset.zero;
    _controller.value = Matrix4.identity()
      ..translate(
        -position.dx * (scale - 1),
        -position.dy * (scale - 1),
      )
      ..scale(scale);
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                onDoubleTapDown: (details) => _doubleTapDetails = details,
                onDoubleTap: _toggleZoom,
                child: InteractiveViewer(
                  transformationController: _controller,
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Image.memory(
                      widget.bytes,
                      fit: BoxFit.contain,
                      gaplessPlayback: true,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 8,
              right: 8,
              top: 8,
              child: Row(
                children: [
                  IconButton.filledTonal(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded, size: 20),
                  ),
                  if (widget.title != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.title!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
