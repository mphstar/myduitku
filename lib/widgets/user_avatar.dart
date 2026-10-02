import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Helper widget to render user avatar from DiceBear Open Peeps style
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.radius = 20,
    this.backgroundColor,
  });

  final String name;
  final double radius;
  final Color? backgroundColor;

  String get _seed {
    final clean = name.trim();
    return clean.isEmpty ? 'duitku_user' : Uri.encodeComponent(clean);
  }

  String get _avatarUrl =>
      'https://api.dicebear.com/7.x/open-peeps/svg?seed=$_seed&backgroundColor=transparent';

  @override
  Widget build(BuildContext context) {
    final effectiveBg = backgroundColor ?? Theme.of(context).primaryColor.withValues(alpha: 0.12);

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        color: effectiveBg,
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
      ),
      child: ClipOval(
        child: SvgPicture.network(
          _avatarUrl,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          placeholderBuilder: (context) => Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
                color: Theme.of(context).primaryColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
