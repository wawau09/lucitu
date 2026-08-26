import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:placelist/utils/app_colors.dart';

/// A robust network image widget that gracefully handles CORS on Flutter Web,
/// multi-URL fallbacks, empty/invalid URLs, and custom placeholders/error states.
class AppNetworkImage extends StatefulWidget {
  final String? imageUrl;
  final List<String>? imageUrls;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool isDark;
  final Widget? placeholder;
  final Widget? errorWidget;

  const AppNetworkImage({
    super.key,
    this.imageUrl,
    this.imageUrls,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.isDark = false,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  int _currentIndex = 0;
  bool _allFailed = false;

  List<String> get _resolvedUrls {
    final list = <String>[];
    if (widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty) {
      list.add(widget.imageUrl!.trim());
    }
    if (widget.imageUrls != null) {
      for (final u in widget.imageUrls!) {
        final clean = u.trim();
        if (clean.isNotEmpty && !list.contains(clean)) {
          list.add(clean);
        }
      }
    }
    return list
        .map((u) {
          if (u.startsWith('//')) return 'https:$u';
          if (u.startsWith('http://')) return 'https://${u.substring(7)}';
          return u;
        })
        .where((u) => u.startsWith('http://') || u.startsWith('https://') || u.startsWith('data:image'))
        .toList();
  }

  @override
  void didUpdateWidget(covariant AppNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl || oldWidget.imageUrls != widget.imageUrls) {
      _currentIndex = 0;
      _allFailed = false;
    }
  }

  void _onImageError() {
    final urls = _resolvedUrls;
    if (_currentIndex + 1 < urls.length) {
      if (mounted) {
        setState(() {
          _currentIndex++;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _allFailed = true;
        });
      }
    }
  }

  Widget _buildFallbackWidget() {
    if (widget.errorWidget != null) {
      return widget.errorWidget!;
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF4EDE6),
      child: Center(
        child: Icon(
          Icons.coffee_rounded,
          color: widget.isDark ? Colors.white24 : AppColors.accent.withValues(alpha: 0.6),
          size: ((widget.width ?? 60) * 0.35).clamp(16.0, 48.0),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    if (widget.placeholder != null) {
      return widget.placeholder!;
    }
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.isDark ? const Color(0xFF2C2C2E) : Colors.grey[200],
      child: Center(
        child: SizedBox(
          width: ((widget.width ?? 60) * 0.3).clamp(14.0, 24.0),
          height: ((widget.height ?? 60) * 0.3).clamp(14.0, 24.0),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              widget.isDark ? Colors.white38 : AppColors.primary.withValues(alpha: 0.6),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final urls = _resolvedUrls;

    Widget imageChild;

    if (urls.isEmpty || _allFailed) {
      imageChild = _buildFallbackWidget();
    } else {
      final currentUrl = urls[_currentIndex];

      if (kIsWeb) {
        // On Web, Image.network handles standard HTML decoding and bypasses XHR CORS restrictions
        imageChild = Image.network(
          currentUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return _buildPlaceholder();
          },
          errorBuilder: (context, error, stackTrace) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onImageError();
            });
            return _buildFallbackWidget();
          },
        );
      } else {
        // On Mobile/Desktop native, CachedNetworkImage provides disk caching
        imageChild = CachedNetworkImage(
          imageUrl: currentUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          placeholder: (context, url) => _buildPlaceholder(),
          errorWidget: (context, url, error) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _onImageError();
            });
            return _buildFallbackWidget();
          },
        );
      }
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: SizedBox(
          width: widget.width,
          height: widget.height,
          child: imageChild,
        ),
      );
    }

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: imageChild,
    );
  }
}
