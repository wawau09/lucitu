import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:panorama_viewer/panorama_viewer.dart';
import 'package:placelist/DB/store.dart';
import 'package:placelist/widgets/app_network_image.dart';

class StoreDetailImageHeader extends StatefulWidget {
  final Store store;
  final bool isDark;

  const StoreDetailImageHeader({
    super.key,
    required this.store,
    required this.isDark,
  });

  @override
  State<StoreDetailImageHeader> createState() => _StoreDetailImageHeaderState();
}

class _StoreDetailImageHeaderState extends State<StoreDetailImageHeader> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    final imageUrls = widget.store.imageUrls;

    if (imageUrls.isEmpty) {
      return SizedBox(
        height: 400,
        width: double.infinity,
        child: Container(
          color: widget.isDark ? const Color(0xFF1C1C1E) : Colors.grey[200],
          child: Center(
            child: Icon(
              Icons.coffee_rounded,
              color: widget.isDark ? Colors.white24 : Colors.grey,
              size: 80,
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 400,
      width: double.infinity,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            scrollBehavior: const MaterialScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.mouse,
                PointerDeviceKind.touch,
                PointerDeviceKind.trackpad,
              },
            ),
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return AppNetworkImage(
                imageUrl: imageUrls[index],
                fit: BoxFit.contain,
                isDark: widget.isDark,
                width: double.infinity,
                height: 400,
              );
            },
          ),
          if (imageUrls.length > 1)
            Positioned(
              bottom: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  imageUrls.length,
                  (index) => Container(
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _currentPage == index
                          ? Colors.blue
                          : (widget.isDark ? Colors.white24 : Colors.grey.shade400),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            right: 16,
            bottom: 16,
            child: Material(
              color: widget.isDark
                  ? Colors.black.withValues(alpha: 0.6)
                  : Colors.white.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => Scaffold(
                        extendBodyBehindAppBar: true,
                        appBar: AppBar(
                          backgroundColor: Colors.transparent,
                          elevation: 0,
                          iconTheme: const IconThemeData(color: Colors.white),
                        ),
                        body: PanoramaViewer(
                          child: Image.asset(
                            'assets/relax_inn_seaview_suite_4k.jpg',
                          ),
                        ),
                      ),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.threed_rotation,
                        size: 20,
                        color: widget.isDark ? Colors.white70 : Colors.black87,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        "3D 파노라마 (데모)",
                        style: GoogleFonts.notoSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: widget.isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
