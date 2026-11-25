import 'dart:async';

import 'package:flutter/material.dart';
import '../../models/patient.dart';
import '../../services/patient_service.dart';
import 'patient_detail_screen.dart';
import 'patient_form_screen.dart';

class PatientListScreen extends StatefulWidget {
  const PatientListScreen({super.key});
  @override
  State<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends State<PatientListScreen> {
  static const _pageSize = 50;
  final _svc = PatientService();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  final List<Patient> _list = [];
  int _page = 0, _totalPages = 1, _total = 0;
  bool _loading = true, _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        _loadMore();
      }
    });
    _reload();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final r = await _svc.searchPage(_search.text.trim(),
          page: 1, perPage: _pageSize);
      if (!mounted) return;
      setState(() {
        _list
          ..clear()
          ..addAll(r.items);
        _page = 1;
        _totalPages = r.totalPages;
        _total = r.totalItems;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final r = await _svc.searchPage(_search.text.trim(),
          page: _page + 1, perPage: _pageSize);
      if (!mounted) return;
      setState(() {
        _list.addAll(r.items);
        _page += 1;
        _totalPages = r.totalPages;
        _total = r.totalItems;
      });
    } catch (_) {}
    if (mounted) setState(() => _loadingMore = false);
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _reload);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(children: [
            Expanded(child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: 'Rechercher (nom, prénom, n° dossier)',
                prefixIcon: Icon(Icons.search)),
              onChanged: _onSearchChanged)),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () async {
                await Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const PatientFormScreen()));
                _reload();
              },
              icon: const Icon(Icons.person_add),
              label: const Text('Nouveau patient')),
          ]),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('$_total patient(s)',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : ListView.separated(
                        controller: _scroll,
                        itemCount: _list.length + (_loadingMore ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          if (i >= _list.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final p = _list[i];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(p.prenom.isNotEmpty ? p.prenom[0].toUpperCase() : '?')),
                            title: Text(p.fullName),
                            subtitle: Text('N° ${p.numeroDossier} • ${p.telephone}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(context,
                                MaterialPageRoute(builder: (_) =>
                                  PatientDetailScreen(patientId: p.id)));
                              _reload();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
