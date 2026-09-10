import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'database_service.dart';

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  StreamSubscription<Position>? _positionStream;
  Timer? _syncTimer;
  double _totalDistance = 0.0;
  DateTime? _startTime;
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  static const String syncUrl = 'http://103.207.168.245/safl/api/location/update';
  static const String baseUrl = 'http://103.207.168.245/safl/api/location';

  double _safeParse(dynamic v) {
    if (v == null) return 0.0;
    final double? p = double.tryParse(v.toString());
    if (p == null || !p.isFinite) return 0.0;
    return p;
  }

  Future<Map<String, dynamic>?> fetchLatestLocation(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final response = await http.get(
        Uri.parse('$baseUrl/latest/$userId'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          return Map<String, dynamic>.from(data[0]);
        }
        if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
      }
    } catch (e) {
      debugPrint("Fetch Latest Location Error: $e");
    }
    return null;
  }

  Future<List<Map<String, dynamic>>> fetchLocationHistory(int userId, {String? date}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      var url = '$baseUrl/history/$userId';
      if (date != null) {
        // Prioritize today_entry_date for visits, keep others as fallbacks
        url += '?today_entry_date=$date&date=$date&entry_date=$date&history_date=$date';
      }
      
      debugPrint("Fetching Location History: $url");
      
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> rawList = [];
        if (data is List) {
          rawList = data;
        } else if (data is Map) {
          if (data['data'] is List) {
            rawList = data['data'];
          } else if (data['history'] is List) {
            rawList = data['history'];
          } else if (data['visits'] is List) {
            rawList = data['visits'];
          }
        }

        final List<Map<String, dynamic>> parsedList = [];
        for (var item in rawList) {
          final map = Map<String, dynamic>.from(item);
          
          final latVal = map['latitude'] ?? map['lat'] ?? map['visit_lat'] ?? map['latitude_actual'];
          final lngVal = map['longitude'] ?? map['lng'] ?? map['long'] ?? map['visit_long'] ?? map['longitude_actual'];
          
          final double lat = _safeParse(latVal);
          final double lng = _safeParse(lngVal);
          
          if (lat != 0.0) {
            map['latitude'] = lat.toString();
            map['longitude'] = lng.toString();
            // Ensure today_entry_date exists for client-side filtering if missing
            if (map['today_entry_date'] == null) {
               map['today_entry_date'] = (map['time'] ?? map['created_at'] ?? map['timestamp'] ?? '').toString().split(' ')[0].split('T')[0];
            }
            parsedList.add(map);
          }
        }

        parsedList.sort((a, b) {
          final t1 = DateTime.tryParse((a['time'] ?? a['created_at'] ?? a['timestamp'] ?? '').toString()) ?? DateTime(2000);
          final t2 = DateTime.tryParse((b['time'] ?? b['created_at'] ?? b['timestamp'] ?? '').toString()) ?? DateTime(2000);
          return t1.compareTo(t2);
        });

        return parsedList;
      }
    } catch (e) {
      debugPrint("Fetch Location History Error: $e");
    }
    return [];
  }

  Future<bool> deleteLocation(int locationId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final response = await http.get(
        Uri.parse('$baseUrl/delete/$locationId'),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("Delete Location Error: $e");
      return false;
    }
  }

  Future<void> startTracking() async {
    if (_isTracking) return;

    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      final prefs = await SharedPreferences.getInstance();
      _totalDistance = prefs.getDouble('tracked_distance') ?? 0.0;
      _startTime = DateTime.now();
      _isTracking = true;

      _positionStream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      ).listen((Position position) {
        _handleNewPosition(position);
      });

      _syncTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
        _syncDataWithServer();
      });
    }
  }

  void _handleNewPosition(Position position) async {
    if (_lastPosition != null && position.latitude.isFinite && position.longitude.isFinite) {
      final double distance = Geolocator.distanceBetween(
        _lastPosition!.latitude,
        _lastPosition!.longitude,
        position.latitude,
        position.longitude,
      );
      if (distance.isFinite) {
        _totalDistance += (distance / 1000.0);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setDouble('tracked_distance', _totalDistance);
      }
    }
    
    if (position.latitude.isFinite && position.longitude.isFinite) {
      _lastPosition = position;
    }

    try {
      await DatabaseService().insertLocation(position.latitude, position.longitude);
    } catch (e) {
      debugPrint("DB Insert Error: $e");
    }
  }

  Future<void> _syncDataWithServer() async {
    if (kIsWeb) return;
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult.contains(ConnectivityResult.none)) return;

    final unsynced = await DatabaseService().getUnsyncedLocations();
    if (unsynced.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token');
    final userJson = prefs.getString('user_data');
    Map<String, dynamic> user = {};
    if (userJson != null) user = jsonDecode(userJson);

    try {
      final response = await http.post(
        Uri.parse(syncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': user['id'] ?? 0,
          'locations': unsynced,
          'total_distance': _totalDistance,
          'time': DateTime.now().toIso8601String(),
        }),
      );

      if (response.statusCode == 200) {
        final List<int> ids = unsynced.map((e) => e['id'] as int).toList();
        await DatabaseService().markLocationsSynced(ids);
      }
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<void> stopTracking() async {
    await _positionStream?.cancel();
    _syncTimer?.cancel();
    _isTracking = false;
    _lastPosition = null;
  }

  Future<void> syncLocationNow({String? action, String? loanNo}) async {
    try {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final userJson = prefs.getString('user_data');
      Map<String, dynamic> user = {};
      if (userJson != null) user = jsonDecode(userJson);

      final body = {
        'id': user['id'] ?? 0,
        'user_id': user['id'] ?? 0,
        'lat': position.latitude.toString(),
        'lng': position.longitude.toString(),
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
        'action': action ?? 'direct_sync',
        'loan_no': loanNo ?? '',
        'case_no': loanNo ?? '',
        'name': user['name'] ?? 'User',
        'time': DateTime.now().toIso8601String(),
        'total_distance': _totalDistance,
        'status': 'active',
      };

      await http.post(
        Uri.parse(syncUrl),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );
    } catch (e) {
      debugPrint("Sync Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> fetchLocationsByLoanNo(String loanNo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final response = await http.get(
        Uri.parse(baseUrl),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        List<dynamic> list = [];
        if (data is List) {
          list = data;
        } else if (data is Map && data['data'] is List) {
          list = data['data'];
        }

        return list
            .where((e) => e['loan_no']?.toString() == loanNo || e['case_no']?.toString() == loanNo)
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint("Fetch Error: $e");
    }
    return [];
  }

  double getTotalDistance() => _totalDistance.isFinite ? _totalDistance : 0.0;

  Future<double> fetchTodayDistance(int userId) async {
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      return await _fetchDistanceForDateRange(userId, today, today);
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> fetchMonthlyDistance(int userId) async {
    try {
      final now = DateTime.now();
      final String monthPrefix = DateFormat('yyyy-MM').format(now);
      final String monthStart = "$monthPrefix-01";
      
      // Rely on fetchLocationHistory and filter for the whole month
      final history = await fetchLocationHistory(userId, date: monthStart);
      if (history.isEmpty) return 0.0;

      double total = 0.0;
      LatLng? lastPoint;

      for (var item in history) {
        final dRaw = (item['today_entry_date'] ?? item['time'] ?? '').toString();
        if (!dRaw.startsWith(monthPrefix)) continue;

        final double lat = _safeParse(item['latitude'] ?? item['lat']);
        final double lng = _safeParse(item['longitude'] ?? item['lng']);

        if (lat != 0.0) {
          final current = LatLng(lat, lng);
          if (lastPoint != null) {
            final double d = Geolocator.distanceBetween(lastPoint.latitude, lastPoint.longitude, current.latitude, current.longitude);
            if (d.isFinite) total += d / 1000.0;
          }
          lastPoint = current;
        }
      }
      return total.isFinite ? total : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  Future<double> _fetchDistanceForDateRange(int userId, String start, String end) async {
    try {
      final history = await fetchLocationHistory(userId, date: start);
      if (history.isEmpty) return 0.0;

      double total = 0.0;
      LatLng? lastPoint;

      for (var item in history) {
        final double lat = _safeParse(item['latitude'] ?? item['lat']);
        final double lng = _safeParse(item['longitude'] ?? item['lng']);

        if (lat != 0.0) {
          final current = LatLng(lat, lng);
          if (lastPoint != null) {
            final double d = Geolocator.distanceBetween(lastPoint.latitude, lastPoint.longitude, current.latitude, current.longitude);
            if (d.isFinite) total += d / 1000.0;
          }
          lastPoint = current;
        }
      }
      return total.isFinite ? total : 0.0;
    } catch (e) {
      return 0.0;
    }
  }

  String getDuration() {
    if (_startTime == null) return "0h 0m";
    final diff = DateTime.now().difference(_startTime!);
    return "${diff.inHours}h ${diff.inMinutes % 60}m";
  }

  Future<bool> ensureLocationAccess(BuildContext context) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (!context.mounted) return false;
      await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("GPS Disabled"),
          content: const Text("Location services are required. Please enable GPS."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("CANCEL")),
            TextButton(onPressed: () { Navigator.pop(ctx); Geolocator.openLocationSettings(); }, child: const Text("OPEN SETTINGS")),
          ],
        ),
      );
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    
    if (permission == LocationPermission.deniedForever) return false;
    return true;
  }
}
