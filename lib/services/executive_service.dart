import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/executive_status.dart';
import 'collection_api_service.dart';
import 'auth_service.dart';

class ExecutiveService {
  static const String allUsersUrl = 'http://103.207.168.245/safl/api/users?per_page=1000';

  static Future<List<ExecutiveStatus>> fetchExecutives({String? tlName}) async {
    try {
      final currentUser = await AuthService.getUserData();
      final String? role = currentUser?.role.toLowerCase();
      final bool isAdmin = role?.contains('admin') ?? false;
      final bool isTL = role?.contains('tl') ?? false;
      final bool isACM = role?.contains('acm') ?? false;
      debugPrint("ExecutiveService Fetch: User: ${currentUser?.name}, Role: $role, IsAdmin: $isAdmin");

      // We primarily use the dashboard data for executive monitoring
      final filters = tlName != null ? {'tl_name': tlName} : <String, dynamic>{};
      final dashboard = await CollectionApiService.fetchEnhancedDashboardStats(filters: filters);
      
      List<dynamic> summaries = dashboard['executive_summary'] ?? [];
      debugPrint("Dashboard Executive Summary Count: ${summaries.length}");

      // Dashboard summary should already be filtered by the server based on role.
      // We apply local matching only if the server returns more than it should.
      if (!isAdmin && currentUser != null) {
        final String currentName = currentUser.cleanName.toLowerCase().trim();
        
        // If regular executive, only keep themselves.
        // If TL/ACM, ensure results actually belong to their hierarchy.
        summaries = summaries.where((s) {
          final String sName = (s['name'] ?? '').toString().trim().toLowerCase();
          final String sTl = (s['tl_name'] ?? '').toString().trim().toLowerCase();
          final String sAcm = (s['acm_name'] ?? '').toString().trim().toLowerCase();

          if (isTL) return sTl == currentName || sTl.contains(currentName) || currentName.contains(sTl) || sName == currentName;
          if (isACM) return sAcm == currentName || sAcm.contains(currentName) || currentName.contains(sAcm) || sName == currentName;
          return sName == currentName || sName.contains(currentName) || currentName.contains(sName);
        }).toList();
        debugPrint("ExecutiveService Local Filter: Kept ${summaries.length} summaries");
      }
      
      if (summaries.isNotEmpty) {
        // We also fetch real-time user data to get location/online status if available
        final List<dynamic> realUsers = await _fetchRawUsers();
        
        // Create normalized user map for high-speed matching
        final Map<String, dynamic> userMap = {};
        for (var u in realUsers) {
          final String name = (u['name'] ?? u['exe_name'] ?? u['NAME'] ?? '').toString().toLowerCase();
          userMap[name] = u;
          
          // Also store normalized version (without e1234_ prefix)
          final norm = _normalize(name);
          if (norm != name) userMap[norm] = u;
        }
        
        return summaries.map((s) {
          final String rawName = (s['name'] ?? 'Executive').toString().toLowerCase().trim();
          final String normName = _normalize(rawName);
          
          // 1. Try exact map lookup
          dynamic realUser = userMap[rawName] ?? userMap[normName];
          
          // 2. Fallback: Search the list for a "contains" match
          if (realUser == null) {
            try {
              realUser = realUsers.firstWhere((u) {
                final String uName = (u['name'] ?? u['exe_name'] ?? u['NAME'] ?? '').toString().toLowerCase().trim();
                final String uNorm = _normalize(uName);
                
                // Match if normalized names match OR one contains the other
                return uNorm == normName || 
                       (normName.length > 3 && uNorm.contains(normName)) || 
                       (uNorm.length > 3 && normName.contains(uNorm));
              }, orElse: () => null);
            } catch (_) {}
          }
          
          if (realUser != null) {
            debugPrint("Matched Executive '$rawName' to ID: ${realUser['id']}");
          } else {
            debugPrint("Warning: Still could not match executive name '$rawName'");
          }
          
          return ExecutiveStatus.fromJson({
            ...s,
            'id': realUser?['id'] ?? s['id'] ?? 0,
            'is_online': realUser?['is_online'] ?? 0,
            'lat': realUser?['lat'] ?? realUser?['latitude'] ?? 0.0,
            'lng': realUser?['lng'] ?? realUser?['longitude'] ?? 0.0,
            'distance': realUser?['total_km'] ?? s['distance'] ?? 0.0,
            'total_cases': s['total_cases'] ?? 0,
            'today_collection': s['total_received'] ?? 0.0,
            'today_visits': s['today_visits'] ?? 0,
            'today_ptp': s['today_ptp'] ?? 0,
          });
        }).toList();
      }
    } catch (e) {
      debugPrint("Dashboard Executive Fetch Error: $e");
    }
    
    // Fallback logic
    final raw = await _fetchRawUsers();
    final currentUser = await AuthService.getUserData();
    final String role = currentUser?.role.toLowerCase() ?? '';
    final bool isAdmin = role.contains('admin');

    if (!isAdmin && currentUser != null) {
      final String currentName = _normalize(currentUser.name.toLowerCase());
      final bool isTL = role.contains('tl');
      final bool isACM = role.contains('acm');
      
      return raw.where((u) {
        final String uName = _normalize((u['name'] ?? u['exe_name'] ?? '').toString().toLowerCase());
        final String uTlName = _normalize((u['tl_name'] ?? '').toString().toLowerCase());
        final String uAcmName = _normalize((u['acm_name'] ?? '').toString().toLowerCase());
        
        if (isTL) return uTlName == currentName || uTlName.contains(currentName);
        if (isACM) return uAcmName == currentName || uAcmName.contains(currentName);
        return uName == currentName || uName.contains(currentName);
      }).map((e) => ExecutiveStatus.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    return raw.map((e) => ExecutiveStatus.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  static String _normalize(String name) {
    if (name.isEmpty) return "";
    // Removes "e1470-" or "e1470_" or similar employee code prefixes
    final RegExp separator = RegExp(r'^[eE]\d+[-_]');
    return name.replaceFirst(separator, "").trim();
  }

  static Future<List<dynamic>> fetchTlSummaries() async {
    try {
      final currentUser = await AuthService.getUserData();
      final String? role = currentUser?.role.toLowerCase();
      final bool isAdmin = role?.contains('admin') ?? false;
      final bool isTL = role?.contains('tl') ?? false;
      final bool isACM = role?.contains('acm') ?? false;

      final dashboard = await CollectionApiService.fetchDashboardData();
      List<dynamic> summaries = dashboard['tl_summary'] ?? [];

      // If not admin/tl/acm, they shouldn't see TL summaries
      if (!isAdmin && !isTL && !isACM) {
        debugPrint("Executive user detected, returning empty TL summary to trigger executive list");
        return [];
      }
      
      return summaries;
    } catch (e) {
      return [];
    }
  }

  static Future<List<dynamic>> _fetchRawUsers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      
      final response = await http.get(
        Uri.parse(allUsersUrl),
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) return data;
        if (data is Map) {
          if (data['data'] is List) return data['data'];
          if (data['data'] is Map && data['data']['data'] is List) return data['data']['data'];
        }
      }
    } catch (e) {
      debugPrint("Raw Users Fetch Error: $e");
    }
    return [];
  }
}
