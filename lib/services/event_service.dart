import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import 'api_helpers.dart';

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String? bannerUrl;
  final String address;
  final double? latitude;
  final double? longitude;
  final bool isOnline;
  final DateTime startTime;
  final DateTime endTime;
  final int volunteersNeeded;
  final int minAge;
  final bool isPaid;
  final String? compensationDetails;
  final String status;
  final double? distance; // distance in km (populated during nearby search)
  final String organizerName;
  final String organizerEmail;
  final String organizerId;
  final int? matchScore;
  final int approvedCount;
  final bool isOrganizerVerified;
  final List<String> openPositions;
  final List<String> perks;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    this.bannerUrl,
    required this.address,
    this.latitude,
    this.longitude,
    required this.isOnline,
    required this.startTime,
    required this.endTime,
    required this.volunteersNeeded,
    required this.minAge,
    required this.isPaid,
    this.compensationDetails,
    required this.status,
    this.distance,
    required this.organizerName,
    required this.organizerEmail,
    required this.organizerId,
    this.matchScore,
    this.approvedCount = 0,
    required this.isOrganizerVerified,
    this.openPositions = const [],
    this.perks = const [],
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    // Check if organizer object is embedded
    final organizer = json['organizer'] ?? {};
    return EventModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      category: json['category'] ?? '',
      bannerUrl: AppConfig.formatMediaUrl(json['bannerUrl']),
      address: json['address'] ?? '',
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      isOnline: json['isOnline'] ?? false,
      startTime: parseServerDate(json['startTime']),
      endTime: parseServerDate(json['endTime']),
      volunteersNeeded: json['volunteersNeeded'] ?? 0,
      minAge: json['minAge'] ?? 16,
      isPaid: json['isPaid'] ?? false,
      compensationDetails: json['compensationDetails'],
      status: json['status'] ?? 'ACTIVE',
      distance: json['distance'] != null
          ? (json['distance'] as num).toDouble()
          : null,
      // Recommendation rows carry a flat organizerName; never assert a
      // verification the payload does not state.
      organizerName:
          organizer['fullName'] ?? json['organizerName'] ?? 'Organizer',
      organizerEmail: organizer['email'] ?? '',
      organizerId: json['organizerId'] ?? '',
      matchScore: json['matchScore'],
      approvedCount: json['approvedCount'] ?? 0,
      isOrganizerVerified: json['isOrganizerVerified'] ?? false,
      openPositions: json['openPositions'] != null
          ? List<String>.from(json['openPositions'])
          : const [],
      perks: json['perks'] != null
          ? List<String>.from(json['perks'])
          : const [],
    );
  }
}

class EventService extends ChangeNotifier {
  static String get baseUrl => AppConfig.baseUrl;

  List<EventModel> _events = [];
  List<dynamic> _organizerApplications = [];
  List<dynamic> _userApplications = [];

  /// Whether /events/mine has come back at least once. Without this the
  /// dashboard cannot tell "no drives" from "not asked yet".
  bool _hasLoadedMyEvents = false;

  /// Whether the last public-events load failed. A wiped list and an empty
  /// result are indistinguishable otherwise, so a dropped request rendered as
  /// "No matching events found".
  bool _eventsLoadFailed = false;
  bool _hasLoadedEvents = false;
  Map<String, dynamic>? _organizerAnalytics;
  List<EventModel> _myEvents = [];
  bool _isLoading = false;

  List<EventModel> get events => _events;
  List<dynamic> get organizerApplications => _organizerApplications;
  List<dynamic> get userApplications => _userApplications;
  bool get hasLoadedMyEvents => _hasLoadedMyEvents;
  bool get eventsLoadFailed => _eventsLoadFailed;
  bool get hasLoadedEvents => _hasLoadedEvents;
  Map<String, dynamic>? get organizerAnalytics => _organizerAnalytics;
  List<EventModel> get myEvents => _myEvents;
  bool get isLoading => _isLoading;

  Future<void> fetchEvents({
    String? category,
    String? search,
    double? latitude,
    double? longitude,
    double? radius,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      // Build query string
      final queryParams = <String, String>{};
      if (category != null && category.isNotEmpty && category != 'All') {
        queryParams['category'] = category;
      }
      if (search != null && search.isNotEmpty) {
        queryParams['search'] = search;
      }
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
        if (radius != null) {
          // The API validates radius as an integer number of kilometres.
          queryParams['radius'] = radius.round().toString();
        }
      }

      final uri = Uri.parse(
        '$baseUrl/events',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        _events = data.map((json) => EventModel.fromJson(json)).toList();
        _eventsLoadFailed = false;
      } else {
        _events = [];
        _eventsLoadFailed = true;
      }
    } catch (e) {
      debugPrint('FetchEvents Connection Error: $e');
      _events = [];
      _eventsLoadFailed = true;
    } finally {
      _isLoading = false;
      _hasLoadedEvents = true;
      notifyListeners();
    }
  }

  /// GET /events/:id — the authoritative record, including approvedCount.
  Future<EventModel?> fetchEventById(String id) async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/events/$id'));
      if (response.statusCode == 200) {
        return EventModel.fromJson(jsonDecode(response.body));
      }
    } catch (e) {
      debugPrint('fetchEventById error: $e');
    }
    return null;
  }

  /// GET /events/mine — the organizer's own events in every status. The
  /// public list hides FULL/COMPLETED/CANCELLED drives, which made them
  /// vanish from the organizer's dashboard the moment they filled up.
  Future<void> fetchMyEvents(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/mine?limit=100'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        _myEvents = data.map((json) => EventModel.fromJson(json)).toList();
      }
    } catch (e) {
      debugPrint('fetchMyEvents error: $e');
    } finally {
      // Set on failure too: a failed load is still "we asked". Leaving it
      // false would spin forever instead of showing the empty state.
      _hasLoadedMyEvents = true;
      notifyListeners();
    }
  }

  /// Drop every cached list so the next account on this device does not see
  /// the previous user's data.
  void clear() {
    _events = [];
    _myEvents = [];
    _hasLoadedMyEvents = false;
    _eventsLoadFailed = false;
    _hasLoadedEvents = false;
    _organizerApplications = [];
    _userApplications = [];
    _organizerAnalytics = null;
    _isLoading = false;
    notifyListeners();
  }

  Future<Map<String, dynamic>> createEvent({
    required String token,
    required String title,
    required String description,
    required String category,
    required String address,
    String? bannerUrl,
    double? latitude,
    double? longitude,
    bool isOnline = false,
    required DateTime startTime,
    required DateTime endTime,
    required int volunteersNeeded,
    int minAge = 16,
    bool isPaid = false,
    String? compensationDetails,
    List<String> openPositions = const [],
    List<String> perks = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          if (bannerUrl != null && bannerUrl.isNotEmpty) 'bannerUrl': bannerUrl,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'isOnline': isOnline,
          // Explicit UTC: a local DateTime serialises without a zone suffix
          // and the server would store the wall-clock time as UTC.
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
          'volunteersNeeded': volunteersNeeded,
          'minAge': minAge,
          'isPaid': isPaid,
          if (compensationDetails != null && compensationDetails.isNotEmpty)
            'compensationDetails': compensationDetails,
          'openPositions': openPositions,
          'perks': perks,
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        return {'success': true, 'event': data};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to create event'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> applyForEvent({
    required String token,
    required String eventId,
    String? roleRequested,
    String? message,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/applications'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'eventId': eventId,
          'roleRequested': roleRequested,
          'message': message,
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 201) {
        await fetchUserApplications(token);
        return {'success': true, 'application': data};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to submit application'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<List<EventModel>> fetchRecommendations(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/recommendations'),
        headers: {'Authorization': 'Bearer $token'},
      );

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data.map((json) => EventModel.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchEventApplications(
    String token,
    String eventId,
  ) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/applications/event/$eventId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = unwrapList(jsonDecode(response.body));
        return List<Map<String, dynamic>>.from(data);
      }
    } catch (e) {
      debugPrint('fetchEventApplications error: $e');
    }
    return [];
  }

  Future<Map<String, dynamic>> updateApplicationStatus(
    String token,
    String applicationId,
    String status,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/applications/$applicationId/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'status': status}),
      );
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'application': data};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to update status'),
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<void> fetchOrganizerApplications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/applications/organizer'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _organizerApplications = unwrapList(jsonDecode(response.body));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchOrganizerApplications error: $e');
    }
  }

  /// Withdraw the signed-in volunteer's own pending application.
  ///
  /// The server refuses once an organizer has approved it, so the error
  /// message it returns is the one worth showing rather than a generic
  /// failure.
  Future<String?> withdrawApplication(
    String token,
    String applicationId,
  ) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/applications/$applicationId'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200 || response.statusCode == 204) {
        _userApplications = _userApplications
            .where((a) => a is Map && a['id'] != applicationId)
            .toList();
        notifyListeners();
        return null;
      }
      return apiMessage(
        jsonDecode(response.body),
        'Could not withdraw the application',
      );
    } catch (e) {
      debugPrint('withdrawApplication error: $e');
      return 'Could not reach the server. Check your connection.';
    }
  }

  Future<void> fetchUserApplications(String token) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/applications/my'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        _userApplications = unwrapList(jsonDecode(response.body));
        notifyListeners();
      }
    } catch (e) {
      debugPrint('fetchUserApplications error: $e');
    }
  }

  Future<Map<String, dynamic>> updateEvent({
    required String token,
    required String eventId,
    required String title,
    required String description,
    required String category,
    required String address,
    String? bannerUrl,
    double? latitude,
    double? longitude,
    bool isOnline = false,
    required DateTime startTime,
    required DateTime endTime,
    required int volunteersNeeded,
    int minAge = 16,
    bool isPaid = false,
    String? compensationDetails,
    List<String> openPositions = const [],
    List<String> perks = const [],
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'category': category,
          // Explicit null so a removed banner is cleared server-side
          // (an omitted key leaves the old value in place).
          'bannerUrl': (bannerUrl != null && bannerUrl.isNotEmpty)
              ? bannerUrl
              : null,
          'address': address,
          'latitude': latitude,
          'longitude': longitude,
          'isOnline': isOnline,
          // Explicit UTC: a local DateTime serialises without a zone suffix
          // and the server would store the wall-clock time as UTC.
          'startTime': startTime.toUtc().toIso8601String(),
          'endTime': endTime.toUtc().toIso8601String(),
          'volunteersNeeded': volunteersNeeded,
          'minAge': minAge,
          'isPaid': isPaid,
          'compensationDetails':
              (isPaid &&
                  compensationDetails != null &&
                  compensationDetails.isNotEmpty)
              ? compensationDetails
              : null,
          'openPositions': openPositions,
          'perks': perks,
        }),
      );

      final data = jsonDecode(response.body);
      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        return {'success': true, 'event': data};
      } else {
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to update event'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<Map<String, dynamic>> deleteEvent(String token, String eventId) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/events/$eventId'),
        headers: {'Authorization': 'Bearer $token'},
      );

      _isLoading = false;
      notifyListeners();

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        final data = jsonDecode(response.body);
        return {
          'success': false,
          'message': apiMessage(data, 'Failed to delete event'),
        };
      }
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return {'success': false, 'message': 'Network connection failed: $e'};
    }
  }

  Future<void> fetchOrganizerAnalytics(String token) async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/events/organizer/analytics'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        _organizerAnalytics = jsonDecode(response.body);
      } else {
        debugPrint(
          '[EVENT SERVICE] Failed to fetch analytics: ${response.body}',
        );
      }
    } catch (e) {
      debugPrint('[EVENT SERVICE] Error fetching analytics: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<String?> uploadEventImage(
    String token,
    List<int> bytes,
    String filename,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/events/upload'),
      );
      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['url'] as String?;
      } else {
        debugPrint('[EVENT SERVICE] Upload failed: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[EVENT SERVICE] Upload connection error: $e');
      return null;
    }
  }
}
