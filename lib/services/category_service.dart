import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

/// The drive category taxonomy, from `GET /events/categories`.
///
/// Discover chips, the Create-Event picker and the profile interest picker
/// all read this one list. Three hand-maintained copies used to disagree with
/// the server's matching categories, which silently broke recommendations and
/// match alerts.
class CategoryService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  List<String> _categories = const [];
  bool _loading = false;
  bool _failed = false;
  Future<void>? _inFlight;

  List<String> get categories => _categories;
  bool get isLoading => _loading;
  bool get loadFailed => _failed;
  bool get hasLoaded => _categories.isNotEmpty;

  /// Fetches once and caches; concurrent callers share the same request.
  /// A failed load is retried on the next call.
  Future<void> ensureLoaded() {
    if (_categories.isNotEmpty) return Future.value();
    return _inFlight ??= _fetch().whenComplete(() => _inFlight = null);
  }

  Future<void> _fetch() async {
    _loading = true;
    _failed = false;
    notifyListeners();
    try {
      final response = await http.get(Uri.parse('$baseUrl/events/categories'));
      if (response.statusCode == 200) {
        _categories = unwrapList(
          jsonDecode(response.body),
        ).whereType<String>().toList(growable: false);
        _failed = _categories.isEmpty;
      } else {
        _failed = true;
      }
    } catch (e) {
      debugPrint('[CATEGORY SERVICE] fetch failed: $e');
      _failed = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// The canonical spelling of [value] from the list (case-insensitive), or
  /// null when it is not a known category.
  String? canonical(String? value) {
    if (value == null) return null;
    final lower = value.trim().toLowerCase();
    for (final c in _categories) {
      if (c.toLowerCase() == lower) return c;
    }
    return null;
  }
}
