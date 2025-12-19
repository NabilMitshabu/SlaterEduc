import 'package:flutter/material.dart';
import 'package:slatereduc/services/api/user_directory_service.dart';

class CorrespondentNameWidget extends StatelessWidget {
  final String? userId;
  final String? fallbackName;
  final TextStyle? style;
  final bool bold;
  final double fontSize;

  const CorrespondentNameWidget({
    Key? key,
    required this.userId,
    this.fallbackName,
    this.style,
    this.bold = false,
    this.fontSize = 16,
  }) : super(key: key);

  Future<String> _resolveName() async {
    if (userId == null || userId!.isEmpty) {
      return fallbackName ?? '';
    }
    final resolved = await UserDirectoryService().resolveUserName(userId!);
    if (resolved.isNotEmpty) return resolved;
    return fallbackName ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _resolveName(),
      builder: (context, snapshot) {
        final name = snapshot.data ?? fallbackName ?? '';
        return Text(
          name,
          style: style ?? TextStyle(
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontSize: fontSize,
          ),
        );
      },
    );
  }
}

