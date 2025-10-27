import 'package:flutter/material.dart';

class PostulanteAvatar extends StatelessWidget {
  const PostulanteAvatar({super.key, 
    required this.nombre,
    required this.fotoUrl,
    required this.radius,
  });

  final String nombre;
  final String? fotoUrl;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final hasPhoto = fotoUrl != null && fotoUrl!.isNotEmpty;
    final initials =
        nombre.isNotEmpty ? nombre.substring(0, 1).toUpperCase() : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: primaryColor.withOpacity(0.1),
      backgroundImage: hasPhoto ? NetworkImage(fotoUrl!) : null,
      child: hasPhoto
          ? null
          : Text(
              initials,
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
    );
  }
}