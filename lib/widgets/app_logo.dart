import 'package:flutter/material.dart';
import '../models/parametre.dart';
import '../services/parametre_service.dart';

/// Logo de l'application (dent souriante).
class AppLogo extends StatelessWidget {
  final double size;
  const AppLogo({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/logo.png', width: size, height: size, fit: BoxFit.contain);
}

/// Logo du cabinet s'il a été chargé dans Paramétrage, sinon logo de l'application.
class ClinicLogo extends StatefulWidget {
  final double size;
  const ClinicLogo({super.key, this.size = 40});
  @override
  State<ClinicLogo> createState() => _ClinicLogoState();
}

class _ClinicLogoState extends State<ClinicLogo> {
  Parametre? _p;

  @override
  void initState() {
    super.initState();
    ParametreService.changes.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    ParametreService.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await ParametreService().get();
      if (mounted) setState(() => _p = p);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final url = _p?.logoUrl ?? '';
    if (url.isEmpty) return AppLogo(size: widget.size);
    return Image.network(url,
        width: widget.size, height: widget.size, fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => AppLogo(size: widget.size));
  }
}
