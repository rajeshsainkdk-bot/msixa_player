import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_colors.dart';

class GenreCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final LinearGradient gradient;
  final String? imageUrl;
  final String? badge;
  final bool isSelected;
  final VoidCallback onTap;

  const GenreCard({
    Key? key,
    required this.title,
    required this.icon,
    required this.gradient,
    this.imageUrl,
    this.badge,
    this.isSelected = false,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 130,
        height: 82,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.18),
            width: isSelected ? 2.0 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: gradient.colors.first.withOpacity(0.55),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Stack(
            children: [
              // Rich Category Thumbnail Image (if provided)
              if (imageUrl != null && imageUrl!.startsWith('http'))
                Positioned.fill(
                  child: CachedNetworkImage(
                    imageUrl: imageUrl!,
                    fit: BoxFit.cover,
                    color: Colors.black.withOpacity(0.52),
                    colorBlendMode: BlendMode.darken,
                    placeholder: (_, __) => Container(decoration: BoxDecoration(gradient: gradient)),
                    errorWidget: (_, __, ___) => Container(decoration: BoxDecoration(gradient: gradient)),
                  ),
                ),

              // Ambient Category Icon
              Positioned(
                right: -8,
                bottom: -8,
                child: Icon(
                  icon,
                  size: 48,
                  color: Colors.white.withOpacity(0.2),
                ),
              ),

              // Category Text & Icon
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(icon, size: 15, color: Colors.white),
                        ),
                        if (badge != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.white24, width: 0.5),
                            ),
                            child: Text(
                              badge!,
                              style: const TextStyle(
                                color: Color(0xFF00E5FF),
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
