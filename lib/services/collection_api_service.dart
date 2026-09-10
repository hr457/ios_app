import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../models/customer_case.dart';
import '../models/task_model.dart';
import 'auth_service.dart';
import 'location_service.dart';
import 'database_service.dart';

class CollectionApiService {
  static const String baseUrl = 'http://103.207.168.245/safl/api';
  static const String collectionUrl = '$baseUrl/collections';
  static const String visitUrl = '$baseUrl/visits';
  static const String taskUrl = '$baseUrl/collection-tasks'; // Pluralized for Laravel standard

  static int serverTotalCount = 0;
  static int serverCurrentPage = 1;
  static int serverLastPage = 1;
  
  static Map<String, dynamic>? _cachedDashboardData;
  static DateTime? _lastDashboardFetch;
  static Future<Map<String, dynamic>>? _dashboardFuture;

  static Map<String, List<String>>? _cachedHierarchy;
  static DateTime? _lastHierarchyFetch;

  static List<dynamic>? _cachedMonthlyVisits;
  static DateTime? _lastVisitsFetch;

  static Future<void> saveDashboardStats(Map<String, dynamic> stats) async {
    await saveToCache("dashboard_stats", stats);
  }

  static Future<Map<String, dynamic>?> loadDashboardStats() async {
    final data = await loadFromCache("dashboard_stats");
    if (data != null) return Map<String, dynamic>.from(data);
    return null;
  }

  static Future<void> saveOutcomeCounts(Map<String, int> counts) async {
    await saveToCache("outcome_counts", counts);
  }

  static Future<Map<String, int>?> loadOutcomeCounts() async {
    final data = await loadFromCache("outcome_counts");
    if (data != null) return Map<String, int>.from(data);
    return null;
  }

  static Future<void> saveToCache(String key, dynamic data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheData = {
        'data': data,
        'ts': DateTime.now().toIso8601String(),
      };
      await prefs.setString('cache_$key', jsonEncode(cacheData));
    } catch (_) {}
  }

  static Future<dynamic> loadFromCache(String key) async {
    final full = await loadFromCacheFull(key);
    return full?['data'];
  }

  static Future<Map<String, dynamic>?> loadFromCacheFull(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final str = prefs.getString('cache_$key');
      if (str != null) return jsonDecode(str);
    } catch (_) {}
    return null;
  }

  static bool isCacheStale(String? timestamp, {int hours = 5}) {
    if (timestamp == null) return true;
    try {
      final now = DateTime.now();
      final ts = DateTime.parse(timestamp);
      
      // 1. Check morning cutoff (11:00 AM)
      final cutoff = DateTime(now.year, now.month, now.day, 11, 0);
      if (now.isAfter(cutoff) && ts.isBefore(cutoff)) {
        return true; // Data is from before 11 AM, needs fresh sync
      }

      // 2. Check standard TTL (e.g. 5 hours)
      return now.difference(ts).inHours >= hours;
    } catch (_) {
      return true;
    }
  }

  static String getCacheKey(String prefix, Map<String, dynamic>? filters) {
    if (filters == null || filters.isEmpty) return prefix;
    // Create a stable string from map entries
    final sortedKeys = filters.keys.toList()..sort();
    final parts = sortedKeys.map((k) => "$k:${filters[k]}").join("|");
    return "${prefix}_$parts";
  }

  static DateTime get istNow => DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  static Future<Map<String, dynamic>> _fetchRaw({required String url, Map<String, dynamic>? filters, int page = 1, int perPage = 20}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      String qs = "?page=$page&per_page=$perPage";
      if (filters != null && filters.isNotEmpty) {
        qs += "&" + filters.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty && e.value.toString().toUpperCase() != 'ALL')
            .map((e) => "${e.key}=${Uri.encodeComponent(e.value.toString())}")
            .join("&");
      }
      final response = await http.get(Uri.parse('$url$qs'), headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded['data'] != null) {
          final data = decoded['data'];
          if (data is Map) {
            return {'list': List<dynamic>.from(data['data'] ?? []), 'total': (data['total'] ?? 0) as int, 'last_page': (data['last_page'] ?? 1) as int};
          } else if (data is List) {
            return {'list': data, 'total': data.length, 'last_page': 1};
          }
        }
      }
    } catch (e) { debugPrint("API Raw Fetch Error: $e"); }
    return {'list': [], 'total': 0, 'last_page': 1};
  }

  static Future<List<dynamic>> _fetchAllPages({required String url, Map<String, dynamic>? filters}) async {
    const int pageSize = 500;
    final first = await _fetchRaw(url: url, filters: filters, page: 1, perPage: pageSize);
    final int totalPages = first['last_page'];
    final List<dynamic> allData = List.from(first['list']);
    if (totalPages > 1) {
      final List<Future<Map<String, dynamic>>> otherPages = [];
      for (int p = 2; p <= totalPages; p++) otherPages.add(_fetchRaw(url: url, filters: filters, page: p, perPage: pageSize));
      final results = await Future.wait(otherPages);
      for (var res in results) allData.addAll(res['list']);
    }
    return allData;
  }

  static Future<List<dynamic>> _fetchVisitsForRole({required String url, Map<String, dynamic>? filters}) async {
    final currentUser = await AuthService.getUserData();
    if (currentUser == null) return [];
    final String role = currentUser.role.toUpperCase().trim();
    final bool isTL = role == 'TL' || role.contains('LEADER');
    final Map<String, dynamic> vF = filters != null ? Map.from(filters) : {};
    if (!role.contains('ADMIN')) {
      bool hasSpecificFilter = vF.containsKey('exe_name') || vF.containsKey('tl_name') || vF.containsKey('acm_name');
      if (!hasSpecificFilter) {
        if (isTL) {
          final teamV = await _fetchAllPages(url: url, filters: {...vF, 'tl_name': currentUser.name});
          final persV = await _fetchAllPages(url: url, filters: {...vF, 'exe_name': currentUser.name});
          final Map<dynamic, dynamic> mV = {};
          for (var v in teamV) mV[v['id']] = v;
          for (var v in persV) mV[v['id']] = v;
          return mV.values.toList();
        } else if (role == 'ACM' || role.contains('MANAGER')) { vF['acm_name'] = currentUser.name; }
        else { vF['exe_name'] = currentUser.name; }
      }
    }
    return await _fetchAllPages(url: url, filters: vF);
  }

  static Future<List<CustomerCase>> fetchCollections({Map<String, dynamic>? filters, int page = 1, int perPage = 20, bool skipRoleFilter = false, bool enrich = true}) async {
    final currentUser = await AuthService.getUserData();
    if (currentUser == null) return [];
    final String role = currentUser.role.toUpperCase().trim();
    final bool isTL = role == 'TL' || role.contains('LEADER');
    final virtualKeys = ['in_progress', 'yet_to_visit', 'visit_done', 'is_rollback', 'joint_visit', 'max_projection_date', 'min_projection_date', 'projection_date', 'resolution_status', 'bucket', 'case_category', 'is_non_starter'];
    
    List<CustomerCase> finalResult = [];

    // Check for Master Cache first for instant speed if filters are simple
    if (page == 1 && (filters == null || filters.isEmpty || filters.keys.every((k) => virtualKeys.contains(k) || k == 'search'))) {
      final master = await loadFromCacheFull("master_collections");
      if (master != null && !isCacheStale(master['ts'], hours: 2)) {
        final List raw = master['data'] as List;
        finalResult = raw.map((e) => CustomerCase.fromJson(Map<String, dynamic>.from(e))).toList();
        if (enrich) finalResult = await _applyVirtualFilters(finalResult, filters);
        serverTotalCount = finalResult.length;
        serverLastPage = 1;
        return finalResult;
      }
    }

    if (filters != null && (filters.keys.any((k) => virtualKeys.contains(k)) || filters['all_data'] == '1')) {
       final Map<String, dynamic> cleanFilters = Map.from(filters);
       for (var k in [...virtualKeys, 'start_date', 'end_date', 'action_start_date', 'action_end_date', 'all_data']) cleanFilters.remove(k);
       List<dynamic> allRaw = [];
       if (isTL && (!filters.containsKey('tl_name') && !filters.containsKey('exe_name')) && !skipRoleFilter) {
          final team = await _fetchAllPages(url: collectionUrl, filters: {...cleanFilters, 'tl_name': currentUser.name});
          final pers = await _fetchAllPages(url: collectionUrl, filters: {...cleanFilters, 'exe_name': currentUser.name});
          final Map<dynamic, dynamic> m = {};
          for (var c in team) m[c['id']] = c;
          for (var c in pers) m[c['id']] = c;
          allRaw = m.values.toList();
       } else {
          final Map<String, dynamic> f = Map.from(cleanFilters);
          if (!role.contains('ADMIN') && !skipRoleFilter) {
            if (role == 'TL') f['tl_name'] = currentUser.name;
            else if (role == 'ACM' || role.contains('MANAGER')) f['acm_name'] = currentUser.name;
            else f['exe_name'] = currentUser.name;
          }
          allRaw = await _fetchAllPages(url: collectionUrl, filters: f);
       }
       
       if (filters['all_data'] == '1') {
         saveToCache("master_collections", allRaw);
       }
       
       finalResult = allRaw.map((e) => CustomerCase.fromJson(Map<String, dynamic>.from(e))).toList();
       serverLastPage = 1; serverCurrentPage = 1;
       if (enrich) finalResult = await _applyVirtualFilters(finalResult, filters);
    } else if (isTL && (filters == null || (!filters.containsKey('tl_name') && !filters.containsKey('exe_name'))) && !skipRoleFilter) {
      final team = await _fetchCollectionsInternal(roleColumn: 'tl_name', name: currentUser.name, filters: filters, page: page, perPage: perPage);
      final int c1 = serverTotalCount;
      final pers = await _fetchCollectionsInternal(roleColumn: 'exe_name', name: currentUser.name, filters: filters, page: page, perPage: perPage);
      final int c2 = serverTotalCount;
      final Map<int, CustomerCase> m = {};
      for (var c in team) m[c.id] = c;
      for (var c in pers) m[c.id] = c;
      finalResult = m.values.toList();
      serverTotalCount = c1 + c2;
      if (enrich) finalResult = await _applyVirtualFilters(finalResult, filters);
    } else {
      final res = await _fetchCollectionsInternal(name: currentUser.name, filters: filters, page: page, perPage: perPage, skipRoleFilter: skipRoleFilter);
      finalResult = enrich ? await _applyVirtualFilters(res, filters) : res;
    }
    
    // CACHE ONLY FIRST PAGE FOR INSTANT UI
    if (page == 1) {
      final String cacheKey = getCacheKey("collections", filters);
      saveToCache(cacheKey, finalResult.map((e) => e.rawJson).toList());
    }
    
    return finalResult;
  }

  static Future<List<dynamic>> fetchRecentVisits({bool force = false}) async {
    // 1. Try In-Memory Cache
    if (!force && _cachedMonthlyVisits != null && _lastVisitsFetch != null && DateTime.now().difference(_lastVisitsFetch!).inMinutes < 60) {
      return _cachedMonthlyVisits!;
    }

    // 2. Try Persistent Cache
    if (!force) {
      final cached = await loadFromCache("recent_visits_90d");
      if (cached != null && cached is List) {
        _cachedMonthlyVisits = cached;
        _lastVisitsFetch = DateTime.now(); // Reset memory timer
        return _cachedMonthlyVisits!;
      }
    }

    // 3. Fetch from Server
    final now = istNow;
    final ninetyDaysAgo = now.subtract(const Duration(days: 90));
    final String startDate = "${ninetyDaysAgo.year}-${ninetyDaysAgo.month.toString().padLeft(2, '0')}-${ninetyDaysAgo.day.toString().padLeft(2, '0')}";
    
    try {
      final visits = await _fetchVisitsForRole(url: visitUrl, filters: {'start_date': startDate});
      if (visits.isNotEmpty) {
        _cachedMonthlyVisits = visits;
        _lastVisitsFetch = DateTime.now();
        saveToCache("recent_visits_90d", visits);
      }
    } catch (e) {
      debugPrint("Error fetching recent visits: $e");
    }

    return _cachedMonthlyVisits ?? [];
  }

  static Future<List<CustomerCase>> enrichCases(List<CustomerCase> list) async {
    return _applyVirtualFilters(list, null);
  }

  static Future<List<CustomerCase>> _applyVirtualFilters(List<CustomerCase> list, Map<String, dynamic>? filters) async {
    final currentIst = istNow;
    
    // Apply Search Filter locally if present
    if (filters != null && filters['search'] != null && filters['search'].toString().isNotEmpty) {
      final String s = filters['search'].toString().toLowerCase().trim();
      list = list.where((c) {
        final String loan = c.loanNo.toLowerCase();
        final String name = c.customer.toLowerCase();
        final String city = (c.rawJson['city'] ?? c.rawJson['CITY'] ?? '').toString().toLowerCase();
        return loan.contains(s) || name.contains(s) || city.contains(s);
      }).toList();
    }

    // PRE-FETCH RECENT VISITS (90 DAYS) TO ENRICH CASE DATA - Uses Cache if available
    final visits = await fetchRecentVisits();

    // Map to store latest visit info per loan
    final Map<String, Map<String, dynamic>> enrichmentMap = {};
    for (var v in visits) {
      final loan = (v['loan_no'] ?? v['case_no'] ?? '').toString().trim();
      final pDateRaw = (v['projection_date'] ?? v['ptp_date'] ?? '').toString();
      final vDateRaw = (v['today_entry_date'] ?? v['created_at'] ?? '').toString();
      
      if (loan.isEmpty) continue;
      
      if (!enrichmentMap.containsKey(loan)) {
        enrichmentMap[loan] = Map<String, dynamic>.from(v);
      } else {
        // Keep the record with the latest projection date
        final curMax = DateTime.tryParse((enrichmentMap[loan]!['projection_date'] ?? enrichmentMap[loan]!['ptp_date'] ?? '').toString()) ?? DateTime(2000);
        final newDate = DateTime.tryParse(pDateRaw) ?? DateTime(2000);
        if (newDate.isAfter(curMax)) enrichmentMap[loan] = Map<String, dynamic>.from(v);
      }
    }

    // ENRICH ALL CASES IN THE LIST
    for (var c in list) {
      final enrichment = enrichmentMap[c.loanNo.trim()];
      if (enrichment != null) {
        c.rawJson['last_visit_date'] = enrichment['today_entry_date'] ?? enrichment['created_at'];
        c.rawJson['projection_date'] = enrichment['projection_date'] ?? enrichment['ptp_date'];
        c.rawJson['ptp_date'] = enrichment['ptp_date'] ?? enrichment['projection_date'];
      }
    }

    if (filters == null || filters.isEmpty) return list;
    List<CustomerCase> filtered = list;
    if (filters['resolution_status'] == 'paid') filtered = filtered.where((c) => (c.rawJson['resolution_status'] ?? '').toString().toLowerCase().trim() == 'paid').toList();
    else if (filters['resolution_status'] == 'unpaid') filtered = filtered.where((c) => (c.rawJson['resolution_status'] ?? '').toString().toLowerCase().trim() != 'paid').toList();
    if (filters['bucket'] != null && filters['bucket'].toString().toUpperCase() != 'ALL') {
      final String bStr = filters['bucket'].toString().toLowerCase().trim();
      
      if (bStr == 'regular_cat') {
        filtered = filtered.where((c) {
          final String b = (c.rawJson['BKT.'] ?? c.rawJson['bkt'] ?? c.rawJson['bucket'] ?? c.bucket).toString().toLowerCase().replaceAll(' ', '');
          return b == '0' || b == 'x' || b.contains('xbkt') || b.contains('(01)');
        }).toList();
      } else if (bStr == 'delinquent_cat') {
        filtered = filtered.where((c) {
          final String b = (c.rawJson['BKT.'] ?? c.rawJson['bkt'] ?? c.rawJson['bucket'] ?? c.bucket).toString().toLowerCase().replaceAll(' ', '');
          return b.contains('0-30') || b.contains('31-60') || b.contains('61-90') || b.contains('(02)') || b.contains('(03)') || b.contains('(04)') || b.contains('3160rs');
        }).toList();
      } else if (bStr == 'delinquent_new_cat') {
        filtered = filtered.where((c) {
          final String b = (c.rawJson['BKT.'] ?? c.rawJson['bkt'] ?? c.rawJson['bucket'] ?? c.bucket).toString().toLowerCase().replaceAll(' ', '');
          final bool isReg = b == '0' || b == 'x' || b.contains('xbkt') || b.contains('(01)');
          final bool is090 = b.contains('0-30') || b.contains('31-60') || b.contains('61-90') || b.contains('(02)') || b.contains('(03)') || b.contains('(04)') || b.contains('3160rs');
          return !isReg && !is090;
        }).toList();
      } else {
        final List<String> targetBuckets = bStr.split(',').map((e) => e.trim()).toList();
        filtered = filtered.where((c) {
          String rawBkt = (c.rawJson['BKT.'] ?? c.rawJson['bkt'] ?? c.rawJson['bucket'] ?? c.bucket).toString().toLowerCase().trim();
          if (rawBkt.isEmpty || rawBkt == 'null') rawBkt = '0';
          return targetBuckets.any((target) => rawBkt == target || rawBkt.contains(target));
        }).toList();
      }
    }
    if (filters['case_category'] != null && filters['case_category'].toString().toUpperCase() != 'ALL') {
      final String targetProduct = filters['case_category'].toString().toLowerCase().trim();
      filtered = filtered.where((c) => c.type.toLowerCase().trim() == targetProduct).toList();
    }
    bool filterInProgress = filters['in_progress'] == '1';
    bool filterYetToVisit = filters['yet_to_visit'] == '1';
    if (filterInProgress || filterYetToVisit) {
      filtered = filtered.where((c) => (c.rawJson['resolution_status'] ?? '').toString().toLowerCase().trim() != 'paid').toList();
      final Set<String> visitedLoanNos = visits.map((v) => (v['loan_no'] ?? v['case_no'] ?? '').toString().trim()).toSet();
      if (filterInProgress) filtered = filtered.where((c) => visitedLoanNos.contains(c.loanNo.trim())).toList();
      else if (filterYetToVisit) filtered = filtered.where((c) => !visitedLoanNos.contains(c.loanNo.trim())).toList();
    }
    if (filters['visit_done'] == 'done') {
      final String? target = filters['calling_remark']?.toString().toLowerCase();
      final Set<String> doneLoanNos = visits.where((v) => (v['visit_done'] ?? v['ptp_done'] ?? '').toString().toLowerCase().trim() == 'done')
                                           .map((v) => (v['loan_no'] ?? v['case_no'] ?? '').toString().trim()).toSet();
      filtered = filtered.where((c) {
         if (!doneLoanNos.contains(c.loanNo.trim())) return false;
         if (target != null) {
            final v = visits.firstWhere((vis) => (vis['loan_no'] ?? vis['case_no'] ?? '').toString().trim() == c.loanNo.trim());
            return (v['calling_remark'] ?? '').toString().toLowerCase().trim() == target;
         }
         return true;
      }).toList();
    }
    if (filters['is_rollback'] == '1') filtered = filtered.where((c) => c.emiAmount > 0 && c.collectedAmount > c.emiAmount).toList();
    
    if (filters['is_non_starter'] == '1') {
      filtered = filtered.where((c) {
        final String ns = (c.rawJson['non_starter'] ?? c.rawJson['NON STARTER'] ?? '').toString().toUpperCase().trim();
        return ns == 'YES' || ns == '1' || ns == 'TRUE';
      }).toList();
    }

    if (filters['followup_overdue'] == '1') {
      final today = DateTime(currentIst.year, currentIst.month, currentIst.day);
      filtered = filtered.where((c) {
        final fup = c.upcomingFollowUpDate;
        return fup != null && 
               DateTime(fup.year, fup.month, fup.day).isBefore(today) && 
               (c.rawJson['resolution_status'] ?? '').toString().toLowerCase().trim() != 'paid';
      }).toList();
    }

    if (filters['joint_visit'] == '1') {
      final String monthStart = "${currentIst.year}-${currentIst.month.toString().padLeft(2, '0')}-01";
      final visits = await _fetchAllPages(url: visitUrl, filters: {'start_date': monthStart, 'calling_remark': 'joint visit'});
      final Set<String> jointLoanNos = visits.map((v) => (v['loan_no'] ?? v['case_no'] ?? '').toString()).toSet();
      filtered = filtered.where((c) => jointLoanNos.contains(c.loanNo)).toList();
    }
    final bool hasDateFilter = filters.containsKey('max_projection_date') || filters.containsKey('min_projection_date') || filters.containsKey('projection_date');
    if (hasDateFilter) {
      final String todayStr = DateFormat('yyyy-MM-dd').format(currentIst);
      final String? targetRemark = filters['calling_remark']?.toString().toLowerCase();
      filtered = filtered.where((c) {
        final latest = enrichmentMap[c.loanNo.trim()]; if (latest == null) return false;
        final remark = (latest['calling_remark'] ?? '').toString().toLowerCase();
        if (targetRemark != null && remark != targetRemark) return false;
        final String projDateRaw = (latest['projection_date'] ?? latest['ptp_date'] ?? '').toString();
        final String projDate = projDateRaw.split(' ')[0].split('T')[0];
        if (filters.containsKey('max_projection_date')) return projDate.compareTo(todayStr) < 0;
        else if (filters.containsKey('min_projection_date')) return projDate.compareTo(todayStr) > 0;
        else if (filters.containsKey('projection_date')) return projDate == todayStr;
        return true;
      }).toList();
    }
    serverTotalCount = filtered.length; return filtered;
  }

  static Future<List<CustomerCase>> _fetchCollectionsInternal({String? roleColumn, required String name, Map<String, dynamic>? filters, int page = 1, int perPage = 20, bool skipRoleFilter = false}) async {
    final Map<String, dynamic> f = Map.from(filters ?? {});
    final currentUser = await AuthService.getUserData();
    final String role = currentUser?.role.toUpperCase().trim() ?? "";
    if (!role.contains('ADMIN') && !skipRoleFilter) {
      bool hasSpecificFilter = f.containsKey('exe_name') || f.containsKey('tl_name') || f.containsKey('acm_name');
      if (!hasSpecificFilter) {
        if (roleColumn != null) f[roleColumn] = name;
        else if (role == 'TL') f['tl_name'] = name;
        else if (role == 'ACM' || role.contains('MANAGER')) f['acm_name'] = name;
        else f['exe_name'] = name;
      }
    }
    final raw = await _fetchRaw(url: collectionUrl, filters: f, page: page, perPage: perPage);
    serverTotalCount = raw['total']; serverLastPage = raw['last_page']; serverCurrentPage = page;
    return List<CustomerCase>.from(raw['list'].map((e) => CustomerCase.fromJson(Map<String, dynamic>.from(e))));
  }

  static Future<Map<String, dynamic>> fetchEnhancedDashboardStats({Map<String, dynamic>? filters}) async {
    try {
      final currentUser = await AuthService.getUserData();
      if (currentUser == null) return {};
      final String role = currentUser.role.toUpperCase().trim();
      final bool isTL = role == 'TL' || role.contains('LEADER');
      List<dynamic> rawCases = [];
      if (isTL && (filters == null || (!filters.containsKey('tl_name') && !filters.containsKey('exe_name')))) {
        final team = await _fetchAllPages(url: collectionUrl, filters: {...?filters, 'tl_name': currentUser.name});
        final pers = await _fetchAllPages(url: collectionUrl, filters: {...?filters, 'exe_name': currentUser.name});
        final Map<dynamic, dynamic> m = {};
        for (var c in team) m[c['id']] = c;
        for (var c in pers) m[c['id']] = c;
        rawCases = m.values.toList();
      } else {
        final Map<String, dynamic> f = Map.from(filters ?? {});
        if (!role.contains('ADMIN')) {
          bool hasSpecificFilter = f.containsKey('exe_name') || f.containsKey('tl_name') || f.containsKey('acm_name');
          if (!hasSpecificFilter) {
            if (role == 'TL') f['tl_name'] = currentUser.name;
            else if (role == 'ACM' || role.contains('MANAGER')) f['acm_name'] = currentUser.name;
            else f['exe_name'] = currentUser.name;
          }
        }
        rawCases = await _fetchAllPages(url: collectionUrl, filters: f);
      }
      final List<CustomerCase> allCases = rawCases.map((e) => CustomerCase.fromJson(Map<String, dynamic>.from(e))).toList();
      final now = istNow; final String todayStr = DateFormat('yyyy-MM-dd').format(now);
      final String monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
      final rawVisitsAll = await _fetchVisitsForRole(url: visitUrl, filters: {...?filters, 'start_date': monthStart});
      final rawVisits = rawVisitsAll.where((v) => _isCurrentMonth((v['today_entry_date'] ?? v['created_at'] ?? '').toString())).toList();
      final Set<String> visitedLoanNosInMonth = rawVisits.map((v) => (v['loan_no'] ?? v['case_no'] ?? '').toString()).toSet();
      final Map<String, Map<String, dynamic>> latestVisitMap = {};
      for (var v in rawVisits) {
        final loan = (v['loan_no'] ?? v['case_no'] ?? '').toString();
        final projDateRaw = (v['projection_date'] ?? v['ptp_date'] ?? '').toString();
        if (loan.isEmpty || projDateRaw.isEmpty) continue;
        if (!latestVisitMap.containsKey(loan) || DateTime.parse(projDateRaw).isAfter(DateTime.parse((latestVisitMap[loan]!['projection_date'] ?? latestVisitMap[loan]!['ptp_date']).toString()))) {
          latestVisitMap[loan] = Map<String, dynamic>.from(v);
        }
      }
      Map<String, dynamic> stats = {
        'overdueFollowupCount': 0,
        'allocated': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'yetToVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'inProgress': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'completed': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'jointVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'totalPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'totalVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'visitsDone': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'topPerformers': <Map<String, dynamic>>[], 'buckets': <String, Map<String, dynamic>>{},
        'efficiency': {
          'regular': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
          'od': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0}, // Internal name for 0-90
          'delinquent': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0}, // New High-Bucket
          'overall': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
          'rollBack': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
          'nonStarter': {'coll': 0.0, 'total_req': 0.0, 'percentage': 0.0, 'count': 0, 'pos_ach': 0.0, 'pos_total': 0.0, 'pos_percentage': 0.0},
        },
        'totalOverdue': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'totalEmi': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'xBkt': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'zeroToNinetyBkt': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'delinquentBkt': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'skipVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'skipPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'shiftVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'shiftPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'todayVisit': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'todayPtp': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'rollBack': {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0},
        'monthly_distance': {'count': '0.0 KM', 'coll': 0.0, 'due': 0.0},
        'efficiency_breakdown': {
          'regular': {'by_exe': <String, Map<String, dynamic>>{}, 'by_bucket': <String, Map<String, dynamic>>{}, 'by_product': <String, Map<String, dynamic>>{}},
          'od': {'by_exe': <String, Map<String, dynamic>>{}, 'by_bucket': <String, Map<String, dynamic>>{}, 'by_product': <String, Map<String, dynamic>>{}},
          'delinquent': {'by_exe': <String, Map<String, dynamic>>{}, 'by_bucket': <String, Map<String, dynamic>>{}, 'by_product': <String, Map<String, dynamic>>{}},
          'overall': {'by_exe': <String, Map<String, dynamic>>{}, 'by_bucket': <String, Map<String, dynamic>>{}, 'by_product': <String, Map<String, dynamic>>{}},
          'rollBack': {'by_exe': <String, Map<String, dynamic>>{}, 'by_bucket': <String, Map<String, dynamic>>{}, 'by_product': <String, Map<String, dynamic>>{}},
          'nonStarter': {'by_exe': <String, Map<String, dynamic>>{}, 'by_bucket': <String, Map<String, dynamic>>{}, 'by_product': <String, Map<String, dynamic>>{}},
        },
      };
      final Map<String, Map<String, dynamic>> perfMap = {};
      final Map<String, Map<String, dynamic>> bucketMap = {};
      for (var c in allCases) {
        final double coll = c.collectedAmount; final double emi = c.emiAmount; final double dueAmount = c.dueAmount; final double pos = c.pos;
        final String product = c.type.isEmpty ? 'Other' : c.type;
        final String resStatus = (c.rawJson['resolution_status'] ?? '').toString().toLowerCase();
        String rawBkt = (c.rawJson['BKT.'] ?? c.rawJson['bkt'] ?? c.rawJson['bucket'] ?? c.bucket).toString().trim();
        String bktName = rawBkt.isEmpty || rawBkt == 'null' || rawBkt == 'false' ? '0' : rawBkt;
        if (c.executive.isNotEmpty) {
          perfMap.putIfAbsent(c.executive, () => {'name': c.executive, 'paid_count': 0, 'total_received': 0.0, 'total_cases': 0, 'today_visits': 0, 'today_ptp': 0, 'pos_ach': 0.0, 'pos_total': 0.0});
          perfMap[c.executive]!['total_received'] += coll; perfMap[c.executive]!['total_cases'] += 1;
          perfMap[c.executive]!['pos_ach'] += c.posAch; perfMap[c.executive]!['pos_total'] += pos;
          if (resStatus == 'paid') perfMap[c.executive]!['paid_count'] += 1;
        }
        bucketMap.putIfAbsent(bktName, () => {'name': 'Bkt $bktName', 'count': 0, 'coll': 0.0, 'overdue': 0.0, 'total_emi': 0.0, 'percentage': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
        var b = bucketMap[bktName]!; b['count']++; b['coll'] += coll; b['overdue'] += dueAmount; b['total_emi'] += emi;
        b['pos_ach'] += c.posAch; b['pos_total'] += pos;
        final double caseReq = emi; final String bktClean = bktName.toLowerCase().replaceAll(' ', '');
        
        // 0. Base total overdue for Roll Back Denominator (sum for all accounts)
        stats['efficiency']['rollBack']['total_req'] += dueAmount;
        final String rbExeKey = c.executive.isEmpty ? 'Unknown' : c.executive;
        stats['efficiency_breakdown']['rollBack']['by_exe'].putIfAbsent(rbExeKey, () => {'paid': 0, 'unpaid': 0, 'coll': 0.0, 'total_req': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
        stats['efficiency_breakdown']['rollBack']['by_exe'][rbExeKey]['total_req'] += dueAmount;
        
        stats['efficiency_breakdown']['rollBack']['by_bucket'].putIfAbsent(bktName, () => {'paid': 0, 'unpaid': 0, 'coll': 0.0, 'total_req': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
        stats['efficiency_breakdown']['rollBack']['by_bucket'][bktName]['total_req'] += dueAmount;

        stats['efficiency_breakdown']['rollBack']['by_product'].putIfAbsent(product, () => {'paid': 0, 'unpaid': 0, 'coll': 0.0, 'total_req': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
        stats['efficiency_breakdown']['rollBack']['by_product'][product]['total_req'] += dueAmount;

        // Regular: Matches "0", "x", "(01)x-bkt", "01xbkt"
        final bool isRegular = bktClean == '0' || bktClean == 'x' || bktClean.contains('xbkt') || bktClean.contains('(01)');
        
        // 0-90 Account (Internal key 'od'): Matches "(02)0-30", "(03)31-60", "(04)61-90", "31-60_rs", etc.
        final bool is0to90 = bktClean.contains('0-30') || bktClean.contains('31-60') || 
                             bktClean.contains('61-90') || bktClean.contains('(02)') || 
                             bktClean.contains('(03)') || bktClean.contains('(04)') || bktClean.contains('3160rs');
                             
        // Delinquent Account (Internal key 'delinquent'): Remaining buckets (4+, 5+, NPA etc.)
        final bool isDelinquentNew = !isRegular && !is0to90;
        
        // Non-Starter check
        final String nsRaw = (c.rawJson['non_starter'] ?? c.rawJson['NON STARTER'] ?? '').toString().toUpperCase().trim();
        final bool isNonStarter = nsRaw == 'YES' || nsRaw == '1' || nsRaw == 'TRUE';

        void fillBreakdown(String cat) {
          stats['efficiency_breakdown'][cat]['by_exe'].putIfAbsent(c.executive, () => {'paid': 0, 'unpaid': 0, 'coll': 0.0, 'total_req': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
          var t = stats['efficiency_breakdown'][cat]['by_exe'][c.executive]; if (resStatus == 'paid') t['paid']++; else t['unpaid']++;
          t['coll'] += coll; t['total_req'] += caseReq; t['pos_ach'] += c.posAch; t['pos_total'] += pos;
          stats['efficiency_breakdown'][cat]['by_bucket'].putIfAbsent(bktName, () => {'paid': 0, 'unpaid': 0, 'coll': 0.0, 'total_req': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
          var bt = stats['efficiency_breakdown'][cat]['by_bucket'][bktName]; if (resStatus == 'paid') bt['paid']++; else bt['unpaid']++;
          bt['coll'] += coll; bt['total_req'] += caseReq; bt['pos_ach'] += c.posAch; bt['pos_total'] += pos;
          stats['efficiency_breakdown'][cat]['by_product'].putIfAbsent(product, () => {'paid': 0, 'unpaid': 0, 'coll': 0.0, 'total_req': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0});
          var pt = stats['efficiency_breakdown'][cat]['by_product'][product]; if (resStatus == 'paid') pt['paid']++; else pt['unpaid']++;
          pt['coll'] += coll; pt['total_req'] += caseReq; pt['pos_ach'] += c.posAch; pt['pos_total'] += pos;
        }
        void updateBox(String key) {
           stats[key]['count']++; stats[key]['coll'] += coll; stats[key]['due'] += emi;
           stats[key]['pos_ach'] += c.posAch; stats[key]['pos_total'] += pos;
        }
        if (isRegular) {
          stats['efficiency']['regular']['coll'] += coll; stats['efficiency']['regular']['total_req'] += caseReq; stats['efficiency']['regular']['count']++;
          stats['efficiency']['regular']['pos_ach'] += c.posAch; stats['efficiency']['regular']['pos_total'] += pos; fillBreakdown('regular');
        } else if (is0to90) {
          stats['efficiency']['od']['coll'] += coll; stats['efficiency']['od']['total_req'] += caseReq; stats['efficiency']['od']['count']++;
          stats['efficiency']['od']['pos_ach'] += c.posAch; stats['efficiency']['od']['pos_total'] += pos; fillBreakdown('od');
        } else if (isDelinquentNew) {
          stats['efficiency']['delinquent']['coll'] += coll; stats['efficiency']['delinquent']['total_req'] += caseReq; stats['efficiency']['delinquent']['count']++;
          stats['efficiency']['delinquent']['pos_ach'] += c.posAch; stats['efficiency']['delinquent']['pos_total'] += pos; fillBreakdown('delinquent');
        }

        if (isNonStarter) {
          stats['efficiency']['nonStarter']['coll'] += coll; stats['efficiency']['nonStarter']['total_req'] += caseReq; stats['efficiency']['nonStarter']['count']++;
          stats['efficiency']['nonStarter']['pos_ach'] += c.posAch; stats['efficiency']['nonStarter']['pos_total'] += pos; fillBreakdown('nonStarter');
        }
        stats['efficiency']['overall']['coll'] += coll; stats['efficiency']['overall']['total_req'] += caseReq; stats['efficiency']['overall']['count']++;
        stats['efficiency']['overall']['pos_ach'] += c.posAch; stats['efficiency']['overall']['pos_total'] += pos; fillBreakdown('overall');
        if (emi > 0 && coll > emi) {
          final double excess = coll - emi;
          stats['rollBack']['count']++; stats['rollBack']['coll'] += coll; stats['rollBack']['due'] += emi;
          stats['rollBack']['pos_ach'] += c.posAch; stats['rollBack']['pos_total'] += pos;
          
          // Add Excess Collection to Efficiency Numerator
          stats['efficiency']['rollBack']['coll'] += excess; 
          stats['efficiency']['rollBack']['count']++;
          stats['efficiency']['rollBack']['pos_ach'] += c.posAch; 
          stats['efficiency']['rollBack']['pos_total'] += pos;
          
          // Breakdown logic (Numerator only, Denominator handled above for all cases)
          var rbExeTarget = stats['efficiency_breakdown']['rollBack']['by_exe'][rbExeKey];
          rbExeTarget['paid']++; rbExeTarget['coll'] += excess; 
          rbExeTarget['pos_ach'] += c.posAch; rbExeTarget['pos_total'] += pos;
          
          var rbBktTarget = stats['efficiency_breakdown']['rollBack']['by_bucket'][bktName];
          rbBktTarget['paid']++; rbBktTarget['coll'] += excess;
          rbBktTarget['pos_ach'] += c.posAch; rbBktTarget['pos_total'] += pos;

          var rbPtTarget = stats['efficiency_breakdown']['rollBack']['by_product'][product];
          rbPtTarget['paid']++; rbPtTarget['coll'] += excess;
          rbPtTarget['pos_ach'] += c.posAch; rbPtTarget['pos_total'] += pos;
        }
        updateBox('allocated');
        if (resStatus == 'paid') { updateBox('completed'); }
        else { 
          if (visitedLoanNosInMonth.contains(c.loanNo)) { updateBox('inProgress'); } 
          else { updateBox('yetToVisit'); } 
          
          // Overdue Follow-up Check for Notification
          final enrichment = latestVisitMap[c.loanNo.trim()];
          if (enrichment != null) {
            final String? pDateRaw = (enrichment['projection_date'] ?? enrichment['ptp_date']).toString();
            if (pDateRaw != null && pDateRaw.isNotEmpty && pDateRaw != 'null') {
              final fupDate = DateTime.tryParse(pDateRaw);
              if (fupDate != null) {
                final today = DateTime(now.year, now.month, now.day);
                if (DateTime(fupDate.year, fupDate.month, fupDate.day).isBefore(today)) {
                  stats['overdueFollowupCount']++;
                }
              }
            }
          }
        }
        if (dueAmount > 0) updateBox('totalOverdue');
        if (emi > 0) updateBox('totalEmi');
        
        if (isRegular) updateBox('xBkt'); 
        else if (is0to90) updateBox('zeroToNinetyBkt');
        else if (isDelinquentNew) updateBox('delinquentBkt');
        if (resStatus == 'unpaid') {
          final latest = latestVisitMap[c.loanNo];
          if (latest != null) {
            final remark = (latest['calling_remark'] ?? '').toString().toLowerCase();
            final String projDateRaw = (latest['projection_date'] ?? latest['ptp_date'] ?? '').toString();
            final String projDate = projDateRaw.split(' ')[0].split('T')[0];
            if (remark == 'visit') {
              if (projDate == todayStr) updateBox('todayVisit');
              else if (projDate.compareTo(todayStr) < 0) updateBox('skipVisit');
              else updateBox('shiftVisit');
            } else if (remark == 'ptp') {
              if (projDate == todayStr) updateBox('todayPtp');
              else if (projDate.compareTo(todayStr) < 0) updateBox('skipPtp');
              else updateBox('shiftPtp');
            }
          }
        }
      }
      bucketMap.forEach((key, b) {
        double totalRequired = (b['total_emi'] as double) + (b['overdue'] as double);
        double collected = b['coll'] as double;
        if (totalRequired > 0) b['percentage'] = (collected / totalRequired) * 100;
        else b['percentage'] = collected > 0 ? 100.0 : 0.0;
      });
      final eff = stats['efficiency'] as Map<String, dynamic>;
      eff.forEach((key, val) {
        double tr = val['total_req'] as double; double c = val['coll'] as double;
        if (tr > 0) val['percentage'] = (c / tr) * 100; else val['percentage'] = c > 0 ? 100.0 : 0.0;
        double pt = (val['pos_total'] ?? 0.0) as double; double pa = (val['pos_ach'] ?? 0.0) as double;
        if (pt > 0) val['pos_percentage'] = (pa / pt) * 100; else val['pos_percentage'] = pa > 0 ? 100.0 : 0.0;
      });
      stats['buckets'] = bucketMap;
      stats['totalPtp'] = {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0}; 
      stats['totalVisit'] = {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0};
      stats['jointVisit'] = {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0}; 
      stats['visitsDone'] = {'count': 0, 'coll': 0.0, 'due': 0.0, 'pos_ach': 0.0, 'pos_total': 0.0};
      final Set<String> allocatedLoanNos = allCases.map((c) => c.loanNo.trim().toLowerCase()).toSet();
      final Map<String, double> loanToEmi = {for (var c in allCases) c.loanNo.trim().toLowerCase(): c.emiAmount};
      final Map<String, double> loanToPos = {for (var c in allCases) c.loanNo.trim().toLowerCase(): c.pos};
      final Map<String, double> loanToPosAch = {for (var c in allCases) c.loanNo.trim().toLowerCase(): c.posAch};

      for (var v in rawVisits) {
        final loan = (v['loan_no'] ?? v['case_no'] ?? '').toString().trim().toLowerCase();
        if (loan.isEmpty || !allocatedLoanNos.contains(loan)) continue;
        final double emiForLoan = loanToEmi[loan] ?? 0.0;
        final double posForLoan = loanToPos[loan] ?? 0.0;
        final double posAchForLoan = loanToPosAch[loan] ?? 0.0;
        final remark = (v['calling_remark'] ?? '').toString().toLowerCase().trim();
        final vDoneRaw = (v['visit_done'] ?? v['ptp_done'] ?? '').toString().toLowerCase().trim();
        final bool isTrulyDone = vDoneRaw == 'done' || vDoneRaw == '1' || vDoneRaw == 'true' || (vDoneRaw.isNotEmpty && vDoneRaw != 'skip' && vDoneRaw != 'shift');
        final c = _double(v['cash_rec'] ?? v['payment_rec'] ?? v['amount']);
        final String vDateRaw = (v['today_entry_date'] ?? v['created_at'] ?? '').toString();
        final String vDate = vDateRaw.split(' ')[0].split('T')[0];
        if (vDate == todayStr) {
          final String exe = (v['exe_name'] ?? v['executive'] ?? '').toString().toLowerCase().trim();
          if (exe.isNotEmpty) {
             final matchKey = perfMap.keys.where((k) => k.toLowerCase().trim() == exe).firstOrNull;
             if (matchKey != null) {
               if (remark == 'visit' && isTrulyDone) perfMap[matchKey]!['today_visits']++;
               if (remark == 'ptp' && isTrulyDone) perfMap[matchKey]!['today_ptp']++;
             }
          }
        }
        if (remark == 'ptp') { 
          stats['totalPtp']['count']++; 
          stats['totalPtp']['coll'] += c; 
          stats['totalPtp']['due'] += emiForLoan; 
          stats['totalPtp']['pos_ach'] += posAchForLoan; 
          stats['totalPtp']['pos_total'] += posForLoan; 
        } else if (remark == 'visit') { 
          stats['totalVisit']['count']++; 
          stats['totalVisit']['coll'] += c; 
          stats['totalVisit']['due'] += emiForLoan; 
          stats['totalVisit']['pos_ach'] += posAchForLoan; 
          stats['totalVisit']['pos_total'] += posForLoan; 
        } else if (remark == 'joint visit') { 
          stats['jointVisit']['count']++; 
          stats['jointVisit']['coll'] += c; 
          stats['jointVisit']['due'] += emiForLoan; 
          stats['jointVisit']['pos_ach'] += posAchForLoan; 
          stats['jointVisit']['pos_total'] += posForLoan; 
        }
        if (isTrulyDone && vDate == todayStr) { 
          stats['visitsDone']['count']++; 
          stats['visitsDone']['coll'] += c; 
          stats['visitsDone']['due'] += emiForLoan; 
          stats['visitsDone']['pos_ach'] += posAchForLoan; 
          stats['visitsDone']['pos_total'] += posForLoan; 
        }
      }
      final sortedPerf = perfMap.values.toList();
      sortedPerf.sort((a, b) { int cmp = (b['paid_count'] as int).compareTo(a['paid_count'] as int); if (cmp != 0) return cmp; return (b['total_received'] as double).compareTo(a['total_received'] as double); });
      stats['topPerformers'] = sortedPerf; stats['executive_summary'] = perfMap.values.toList();
      
      // Persist to storage for offline/fast load
      saveDashboardStats(stats);
      
      return stats;
    } catch (e) { debugPrint("Enhanced Stats Error: $e"); return {}; }
  }

  static Future<Map<String, int>> fetchOutcomeCounts() async {
    final currentUser = await AuthService.getUserData();
    if (currentUser == null) return {};
    final String role = currentUser.role.toUpperCase().trim();
    final now = istNow;
    final String monthStart = "${now.year}-${now.month.toString().padLeft(2, '0')}-01";
    final Map<String, int> counts = {};
    Map<String, dynamic> f = {'start_date': monthStart};
    final bool isTL = role == 'TL' || role.contains('LEADER');
    try {
      if (isTL) {
         final resultsTeam = await Future.wait([
            _fetchRaw(url: visitUrl, filters: {...f, 'tl_name': currentUser.name, 'calling_remark': 'visit', 'visit_done': 'done'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'tl_name': currentUser.name, 'calling_remark': 'visit', 'visit_done': 'skip'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'tl_name': currentUser.name, 'calling_remark': 'visit', 'visit_done': 'shift'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'tl_name': currentUser.name, 'calling_remark': 'ptp', 'visit_done': 'done'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'tl_name': currentUser.name, 'calling_remark': 'ptp', 'visit_done': 'skip'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'tl_name': currentUser.name, 'calling_remark': 'ptp', 'visit_done': 'shift'}, perPage: 1),
         ]);
         final resultsPers = await Future.wait([
            _fetchRaw(url: visitUrl, filters: {...f, 'exe_name': currentUser.name, 'calling_remark': 'visit', 'visit_done': 'done'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'exe_name': currentUser.name, 'calling_remark': 'visit', 'visit_done': 'skip'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'exe_name': currentUser.name, 'calling_remark': 'visit', 'visit_done': 'shift'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'exe_name': currentUser.name, 'calling_remark': 'ptp', 'visit_done': 'done'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'exe_name': currentUser.name, 'calling_remark': 'ptp', 'visit_done': 'skip'}, perPage: 1),
            _fetchRaw(url: visitUrl, filters: {...f, 'exe_name': currentUser.name, 'calling_remark': 'ptp', 'visit_done': 'shift'}, perPage: 1),
         ]);
         counts['v_done'] = resultsTeam[0]['total'] + resultsPers[0]['total'];
         counts['v_skip'] = resultsTeam[1]['total'] + resultsPers[1]['total'];
         counts['v_shift'] = resultsTeam[2]['total'] + resultsPers[2]['total'];
         counts['p_done'] = resultsTeam[3]['total'] + resultsPers[3]['total'];
         counts['p_skip'] = resultsTeam[4]['total'] + resultsPers[4]['total'];
         counts['p_shift'] = resultsTeam[5]['total'] + resultsPers[5]['total'];
      } else {
        if (role == 'ACM' || role.contains('MANAGER')) f['acm_name'] = currentUser.name;
        else f['exe_name'] = currentUser.name;
        final results = await Future.wait([
          _fetchRaw(url: visitUrl, filters: {...f, 'calling_remark': 'visit', 'visit_done': 'done'}, perPage: 1),
          _fetchRaw(url: visitUrl, filters: {...f, 'calling_remark': 'visit', 'visit_done': 'skip'}, perPage: 1),
          _fetchRaw(url: visitUrl, filters: {...f, 'calling_remark': 'visit', 'visit_done': 'shift'}, perPage: 1),
          _fetchRaw(url: visitUrl, filters: {...f, 'calling_remark': 'ptp', 'visit_done': 'done'}, perPage: 1),
          _fetchRaw(url: visitUrl, filters: {...f, 'calling_remark': 'ptp', 'visit_done': 'skip'}, perPage: 1),
          _fetchRaw(url: visitUrl, filters: {...f, 'calling_remark': 'ptp', 'visit_done': 'shift'}, perPage: 1),
        ]);
        counts['v_done'] = results[0]['total']; counts['v_skip'] = results[1]['total']; counts['v_shift'] = results[2]['total'];
        counts['p_done'] = results[3]['total']; counts['p_skip'] = results[4]['total']; counts['p_shift'] = results[5]['total'];
      }
    } catch (e) { debugPrint("Outcome counts error: $e"); }
    return counts;
  }

  static Future<Map<String, dynamic>> fetchDashboardData({Map<String, dynamic>? filters}) async {
    if (filters == null || filters.isEmpty) {
      if (_cachedDashboardData != null && _lastDashboardFetch != null && DateTime.now().difference(_lastDashboardFetch!).inHours < 1) return _cachedDashboardData!;
      if (_dashboardFuture != null) return _dashboardFuture!;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      Map<String, dynamic> fFilters = filters != null ? Map.from(filters) : {};
      final currentUser = await AuthService.getUserData();
      if (currentUser != null) {
        final String role = currentUser.role.toUpperCase().trim();
        final String name = currentUser.name; 
        if (!role.contains('ADMIN')) {
          bool hasSpecificFilter = fFilters.containsKey('exe_name') || fFilters.containsKey('tl_name') || fFilters.containsKey('acm_name');
          if (!hasSpecificFilter) {
            if (role == 'TL') fFilters['tl_name'] = name;
            else if (role == 'ACM' || role.contains('MANAGER')) fFilters['acm_name'] = name;
            else fFilters['exe_name'] = name;
          }
        }
      }
      String qs = "";
      if (fFilters.isNotEmpty) {
        qs = "?" + fFilters.entries.where((e) => e.value != null && e.value.toString().isNotEmpty && e.value != 'ALL').map((e) => "${e.key}=${Uri.encodeComponent(e.value.toString())}").join("&");
      }
      final url = Uri.parse('$collectionUrl/dashboard$qs');
      final Future<Map<String, dynamic>> fetchFuture = http.get(url, headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 45)).then((res) {
        if (res.statusCode == 200) {
          final d = jsonDecode(res.body);
          if (d['status'] == true && d['data'] != null) {
            final data = Map<String, dynamic>.from(d['data']);
            if (filters == null || filters.isEmpty) { 
              _cachedDashboardData = data; 
              _lastDashboardFetch = DateTime.now(); 
              saveToCache("dashboard_data", data);
            }
            return data;
          }
        }
        return <String, dynamic>{};
      });
      if (filters == null || filters.isEmpty) { _dashboardFuture = fetchFuture; fetchFuture.whenComplete(() => _dashboardFuture = null); }
      return await fetchFuture;
    } catch (_) {}
    return _cachedDashboardData ?? {};
  }

  static double _double(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '').trim()) ?? 0.0;
  }

  static Future<CustomerCase?> fetchCaseDetails(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final url = Uri.parse('$collectionUrl/$id');
      final res = await http.get(url, headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 30));
      if (res.statusCode == 200) {
        final d = jsonDecode(res.body);
        if (d['status'] == true && d['data'] != null) {
          final c = CustomerCase.fromJson(Map<String, dynamic>.from(d['data']));
          saveToCache("case_details_$id", c.rawJson);
          return c;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<bool> submitVisit({
    required CustomerCase customer,
    required String subject,
    required String remarks,
    DateTime? followUp,
    double? collectedAmount,
    String? callingRemark,
    dynamic photo,
    String? jointExe,
    String? jointTl,
    String? jointAcm,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      if (token == null) return false;
      final currentUser = await AuthService.getUserData();
      final String originalExe = currentUser?.name ?? customer.executive;
      final String tcToSave = jointExe ?? (customer.rawJson['tc_name'] ?? '').toString();
      Position? position;
      try {
        position = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)).timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException("GPS Timeout"));
      } catch (_) {}
      var req = http.MultipartRequest('POST', Uri.parse(visitUrl));
      req.headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $token'});
      req.fields['loan_no'] = customer.loanNo;
      req.fields['case_no'] = customer.loanNo;
      req.fields['cust_id'] = (customer.rawJson['cust_id'] ?? customer.rawJson['customer_id'] ?? '').toString();
      req.fields['cust_id_count'] = (customer.rawJson['cust_id_count'] ?? '1').toString();
      req.fields['exe_name'] = originalExe; req.fields['tc_name'] = tcToSave;
      req.fields['tl_name'] = jointTl ?? customer.tl; req.fields['acm_name'] = jointAcm ?? customer.acm;
      req.fields['visit_remark'] = remarks; req.fields['subject'] = subject;
      req.fields['today_entry_date'] = DateFormat('yyyy-MM-dd').format(istNow);
      req.fields['payment_rec'] = (collectedAmount ?? 0.0).toString();
      req.fields['cash_rec'] = (collectedAmount ?? 0.0).toString(); // Send to both for safety
      req.fields['payment_rec_date'] = DateFormat('yyyy-MM-dd').format(istNow);
      if (position != null) {
        req.fields['lat'] = position.latitude.toString(); req.fields['lng'] = position.longitude.toString();
        req.fields['latitude'] = position.latitude.toString(); req.fields['longitude'] = position.longitude.toString();
        req.fields['visit_address'] = "${position.latitude}, ${position.longitude}";
      }
      final String baseStatus = callingRemark ?? (subject.toLowerCase().contains('ptp') ? 'ptp' : 'visit');
      req.fields['calling_remark'] = baseStatus;
      String resStat = 'skip';
      if (followUp != null) {
        final now = istNow; final t = DateFormat('yyyy-MM-dd').format(now); final f = DateFormat('yyyy-MM-dd').format(followUp);
        if (f == t) resStat = 'done'; else if (followUp.isAfter(now)) resStat = 'shift';
      }
      req.fields['ptp_done'] = resStat; req.fields['visit_done'] = resStat;
      if (followUp != null) {
        final fStr = DateFormat('yyyy-MM-dd').format(followUp);
        req.fields['projection_date'] = fStr; req.fields['next_ptp'] = fStr; req.fields['follow_up'] = fStr;
      }
      if (photo != null) {
        final path = photo is String ? photo : (photo.path);
        req.files.add(await http.MultipartFile.fromPath('visit_image', path));
      }
      
      try {
        final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final d = jsonDecode(res.body);
          if (d['status'] == true) {
            try { await LocationService().syncLocationNow(action: subject, loanNo: customer.loanNo); } catch (_) {}
            final String? f = followUp != null ? DateFormat('yyyy-MM-dd').format(followUp) : null;
            await updateCase(customer.id, {
              'ptp_done': resStat, 'visit_done': resStat, 'calling_remark': baseStatus,
              'today_entry_date': DateFormat('yyyy-MM-dd').format(istNow), 'remark': remarks,
              'projection_date': f, 'next_ptp': f, 'ptp_date': f,
              'tc_name': tcToSave, 'tl_name': jointTl ?? customer.tl, 'acm_name': jointAcm ?? customer.acm,
              'exe_name': originalExe, 'cust_id_count': (customer.rawJson['cust_id_count'] ?? '1').toString(),
              if (collectedAmount != null && collectedAmount > 0) 'payment_rec': collectedAmount,
              if (collectedAmount != null && collectedAmount > 0) 'cash_rec': collectedAmount,
              if (collectedAmount != null && collectedAmount > 0) 'payment_rec_date': DateFormat('yyyy-MM-dd').format(istNow),
            });
            return true;
          }
        }
      } catch (e) {
        debugPrint("Network error during visit submit, saving offline: $e");
        // OFFLINE SAVE LOGIC
        final Map<String, dynamic> offlineData = {
          'loan_no': customer.loanNo, 'case_no': customer.loanNo,
          'cust_id': (customer.rawJson['cust_id'] ?? customer.rawJson['customer_id'] ?? '').toString(),
          'cust_id_count': (customer.rawJson['cust_id_count'] ?? '1').toString(),
          'exe_name': originalExe, 'tc_name': tcToSave,
          'tl_name': jointTl ?? customer.tl, 'acm_name': jointAcm ?? customer.acm,
          'visit_remark': remarks, 'subject': subject,
          'today_entry_date': DateFormat('yyyy-MM-dd').format(istNow),
          'payment_rec': (collectedAmount ?? 0.0).toString(),
          'cash_rec': (collectedAmount ?? 0.0).toString(),
          'payment_rec_date': DateFormat('yyyy-MM-dd').format(istNow),
          'calling_remark': baseStatus, 'ptp_done': resStat, 'visit_done': resStat,
          if (followUp != null) 'projection_date': DateFormat('yyyy-MM-dd').format(followUp),
          if (followUp != null) 'next_ptp': DateFormat('yyyy-MM-dd').format(followUp),
          if (followUp != null) 'follow_up': DateFormat('yyyy-MM-dd').format(followUp),
          if (position != null) 'lat': position.latitude.toString(),
          if (position != null) 'lng': position.longitude.toString(),
          if (position != null) 'latitude': position.latitude.toString(),
          if (position != null) 'longitude': position.longitude.toString(),
          if (position != null) 'visit_address': "${position.latitude}, ${position.longitude}",
        };
        
        final String? photoPath = photo != null ? (photo is String ? photo : photo.path) : null;
        await DatabaseService().insertPendingVisit(offlineData, photoPath);
        return true; // Return true but caller should check sync status if they want
      }
      return false;
    } catch (_) { return false; }
  }

  static Future<bool> updateCase(int id, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      var req = http.MultipartRequest('POST', Uri.parse('$collectionUrl/$id'));
      req.headers.addAll({'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'});
      req.fields['_method'] = 'PUT';
      data.forEach((k, v) { if (v != null) req.fields[k] = v.toString(); });
      final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 15)));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<void> syncPendingVisits() async {
    final unsynced = await DatabaseService().getUnsyncedVisits();
    if (unsynced.isEmpty) return;
    
    debugPrint("Syncing ${unsynced.length} pending visits...");
    
    for (var v in unsynced) {
      try {
        final int localId = v['id'];
        final Map<String, dynamic> data = jsonDecode(v['data']);
        final String? photoPath = v['photo_path'];
        
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('api_token');
        if (token == null) continue;

        var req = http.MultipartRequest('POST', Uri.parse(visitUrl));
        req.headers.addAll({'Accept': 'application/json', 'Authorization': 'Bearer $token'});
        
        data.forEach((key, value) {
          if (value != null) req.fields[key] = value.toString();
        });
        
        if (photoPath != null && photoPath.isNotEmpty) {
          req.files.add(await http.MultipartFile.fromPath('visit_image', photoPath));
        }

        final res = await http.Response.fromStream(await req.send().timeout(const Duration(seconds: 30)));
        if (res.statusCode == 200 || res.statusCode == 201) {
          final d = jsonDecode(res.body);
          if (d['status'] == true) {
            await DatabaseService().deletePendingVisit(localId);
            debugPrint("Synced visit $localId successfully");
          }
        }
      } catch (e) {
        debugPrint("Sync Error for visit ${v['id']}: $e");
      }
    }
  }

  static Future<void> syncPendingVisitsSilently() async {
    // Wrapper for connectivity listener to avoid spamming logs
    syncPendingVisits();
  }

  static Future<bool> updateFullCase(CustomerCase item) async {
    return updateCase(item.id, {'status': item.status, 'remark': item.remarks, 'payment_rec': item.collectedAmount, 'follow_up': item.ptpDate?.toIso8601String().split('T')[0]});
  }

  static Future<bool> deleteCase(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final res = await http.delete(Uri.parse('$collectionUrl/$id'), headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}).timeout(const Duration(seconds: 10));
      return res.statusCode == 200;
    } catch (_) { return false; }
  }

  static Future<List<Map<String, dynamic>>> fetchVisits({Map<String, dynamic>? filters, int page = 1, int perPage = 20}) async {
    final currentUser = await AuthService.getUserData();
    if (currentUser == null) return [];
    final String role = currentUser.role.toUpperCase().trim();
    if ((role == 'TL' || role.contains('LEADER')) && (filters == null || (!filters.containsKey('tl_name') && !filters.containsKey('exe_name')))) {
      final team = await _fetchAllPages(url: visitUrl, filters: {...?filters, 'tl_name': currentUser.name});
      final Map<dynamic, Map<String, dynamic>> m = {};
      for (var v in team) m[v['id']] = v;
      serverTotalCount = m.length;
      return m.values.toList().cast<Map<String, dynamic>>();
    }
    final Map<String, dynamic> f = Map.from(filters ?? {});
    if (!role.contains('ADMIN')) {
      bool hasSpecificFilter = f.containsKey('exe_name') || f.containsKey('tl_name') || f.containsKey('acm_name') || f.containsKey('tc_name');
      if (!hasSpecificFilter) {
        if (role == 'TL') f['tl_name'] = currentUser.name;
        else if (role == 'ACM' || role.contains('MANAGER')) f['acm_name'] = currentUser.name;
        else f['exe_name'] = currentUser.name;
      }
    }
    final res = await _fetchRaw(url: visitUrl, filters: f, page: page, perPage: perPage);
    serverTotalCount = res['total']; serverLastPage = res['last_page']; serverCurrentPage = page;
    final list = List<Map<String, dynamic>>.from(res['list']);
    if (page == 1) saveToCache(getCacheKey("visits", filters), list);
    return list;
  }

  static bool _isCurrentMonth(String date) {
    if (date.isEmpty || date == 'null') return false;
    try {
      final now = istNow;
      final parts = date.split(' ')[0].split(RegExp(r'[-/]'));
      if (parts.length < 3) return false;
      int year, month;
      if (parts[0].length == 4) { year = int.parse(parts[0]); month = int.parse(parts[1]); }
      else { year = int.parse(parts[2]); month = int.parse(parts[1]); }
      return year == now.year && month == now.month;
    } catch (_) { return false; }
  }

  static Future<List<CustomerCase>> fetchVisitedCases({Map<String, dynamic>? filters}) async {
    final List<dynamic> vRaw = await _fetchAllPages(url: visitUrl, filters: filters);
    Iterable<dynamic> filtered = vRaw;
    if (filters != null && filters['calling_remark'] != null) {
      final target = filters['calling_remark'].toString().toLowerCase();
      filtered = vRaw.where((item) => (item['calling_remark'] ?? '').toString().toLowerCase() == target);
    }
    if (filters != null && filters.containsKey('start_date')) {
      filtered = filtered.where((item) => _isCurrentMonth((item['today_entry_date'] ?? item['created_at'] ?? '').toString()));
    }
    if (filters != null && filters.containsKey('today_entry_date')) {
      final targetDate = filters['today_entry_date'].toString();
      filtered = filtered.where((item) {
        final dRaw = (item['today_entry_date'] ?? item['created_at'] ?? '').toString();
        return dRaw.split(' ')[0].split('T')[0] == targetDate;
      });
    }
    final list = filtered.map((item) => CustomerCase.fromJson({...Map<String, dynamic>.from(item), 'id': item['cust_id'] ?? item['customer_id'] ?? item['id'], 'name': item['customer_name'] ?? item['cust_name'] ?? item['name'], 'loan_no': item['loan_no'] ?? item['case_no'], 'status': 'Visited', 'overdue': item['overdue'] ?? item['total_recovery_required'] ?? 0.0, 'remark': item['visit_remark'] ?? item['remark'] ?? '', 'exe_name': item['exe_name'] ?? '', 'tc_name': item['tc_name'] ?? '', 'tl_name': item['tl_name'] ?? '', 'acm_name': item['acm_name'] ?? '', 'visit_image': item['visit_image'] ?? item['visit_photo'] ?? item['photo'] ?? '', 'visit_address': item['visit_address'] ?? item['location'] ?? '', 'latitude': item['latitude'] ?? item['lat'] ?? '', 'longitude': item['longitude'] ?? item['lng'] ?? ''})).toList();
    saveToCache(getCacheKey("visited_cases", filters), list.map((e) => e.rawJson).toList());
    return list;
  }

  static Future<Map<String, List<String>>> fetchHierarchyNames({bool forceRefresh = false}) async {
    if (!forceRefresh && _cachedHierarchy != null && _lastHierarchyFetch != null && DateTime.now().difference(_lastHierarchyFetch!).inMinutes < 15) {
      return _cachedHierarchy!;
    }
    
    final all = await fetchCollections(perPage: 2000, skipRoleFilter: true, enrich: false);
    final Set<String> exes = {}; final Set<String> tls = {}; final Set<String> acms = {};
    for (var c in all) {
      if (c.executive.isNotEmpty) exes.add(c.executive);
      if (c.tl.isNotEmpty) tls.add(c.tl);
      if (c.acm.isNotEmpty) acms.add(c.acm);
    }
    final result = {
      'executives': exes.toList()..sort(), 
      'tls': tls.toList()..sort(), 
      'acms': acms.toList()..sort()
    };
    _cachedHierarchy = result;
    _lastHierarchyFetch = DateTime.now();
    return result;
  }

  static Future<bool> assignTask(TaskModel task) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final currentUser = await AuthService.getUserData();
      final String role = currentUser?.role.toUpperCase() ?? "EXECUTIVE";

      var req = http.MultipartRequest('POST', Uri.parse(taskUrl));
      req.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      });

      // FIELD MAPPING SYNC
      req.fields['case_no'] = task.caseNo;
      req.fields['loan_no'] = task.caseNo; 
      req.fields['remark'] = task.remark;
      req.fields['due_date'] = DateFormat('yyyy-MM-dd').format(task.dueDate);
      
      // Assign recipient to exe_name
      req.fields['exe_name'] = task.toUser;
      req.fields['to_user'] = task.toUser;

      // Assign sender to appropriate hierarchy column
      final String fromName = currentUser?.name ?? task.fromUser;
      if (role.contains('TL')) {
        req.fields['tl_name'] = fromName;
      } else if (role.contains('ACM') || role.contains('MANAGER')) {
        req.fields['acm_name'] = fromName;
      } else {
        req.fields['from_user'] = fromName;
        req.fields['tc_name'] = fromName; // Often used for TC/Office roles
      }

      req.fields['status'] = 'pending';

      final streamedRes = await req.send().timeout(const Duration(seconds: 20));
      final res = await http.Response.fromStream(streamedRes);
      
      debugPrint("Assign Task ($role) -> ${task.toUser} | Status: ${res.statusCode}");
      debugPrint("Response Body: ${res.body}");

      if (res.statusCode == 200 || res.statusCode == 201) {
        final decoded = jsonDecode(res.body);
        if (decoded['status'] == true) {
          // Always update local DB for instant UI responsiveness
          try { await DatabaseService().insertTask({...task.toJson(), 'status': 'pending'}); } catch (_) {}
          return true;
        }
      }
      return false;
    } catch (e) { 
      debugPrint("Assign Task Exception: $e");
      return false; 
    }
  }

  static Future<List<TaskModel>> fetchMyTasks() async {
    try {
      final currentUser = await AuthService.getUserData();
      if (currentUser == null) return [];
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');

      // 1. Try Live Sync from Server
      try {
        final res = await http.get(
          Uri.parse('$taskUrl?exe_name=${Uri.encodeComponent(currentUser.name)}&status=pending'),
          headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}
        ).timeout(const Duration(seconds: 15));
        
        debugPrint("Fetch Tasks Status: ${res.statusCode}");
        
        if (res.statusCode == 200) {
          final decoded = jsonDecode(res.body);
          if (decoded['status'] == true && decoded['data'] != null) {
            final List serverList = decoded['data'];
            return serverList.map((e) => TaskModel.fromJson(e)).toList();
          }
        }
      } catch (e) {
        debugPrint("Server Task Fetch Failed (Offline?): $e");
      }

      // 2. Local Fallback
      final localData = await DatabaseService().getTasks(currentUser.name);
      return localData.map((e) => TaskModel.fromJson(e))
                     .where((t) => t.status == 'pending').toList();
    } catch (_) {}
    return [];
  }

  static Future<List<TaskModel>> fetchTasksSentByMe() async {
    try {
      final currentUser = await AuthService.getUserData();
      if (currentUser == null) return [];
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      final String role = currentUser.role.toUpperCase();

      String param = "from_user";
      if (role.contains('TL')) param = "tl_name";
      else if (role.contains('ACM') || role.contains('MANAGER')) param = "acm_name";

      final res = await http.get(
        Uri.parse('$taskUrl?$param=${Uri.encodeComponent(currentUser.name)}'),
        headers: {'Accept': 'application/json', if (token != null) 'Authorization': 'Bearer $token'}
      ).timeout(const Duration(seconds: 15));
      
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded['status'] == true && decoded['data'] != null) {
          final List list = decoded['data'];
          return list.map((e) => TaskModel.fromJson(e)).toList();
        }
      }
    } catch (_) {}
    return [];
  }

  static Future<bool> updateTaskStatus(int taskId, String status) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token');
      
      // Using POST with _method: PUT for better server compatibility
      var req = http.MultipartRequest('POST', Uri.parse('$taskUrl/$taskId'));
      req.headers.addAll({
        'Accept': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token'
      });
      req.fields['_method'] = 'PUT';
      req.fields['status'] = status;

      final streamedRes = await req.send().timeout(const Duration(seconds: 15));
      final res = await http.Response.fromStream(streamedRes);

      debugPrint("Update Task Status: ${res.statusCode}");
      debugPrint("Update Task Body: ${res.body}");

      if (res.statusCode == 200) {
        // Also Update Locally
        await DatabaseService().updateTaskStatus(taskId, status);
        return true;
      }
      return false;
    } catch (e) { 
      debugPrint("Update Task Exception: $e");
      return false; 
    }
  }

  static Future<List<CaseActivity>> fetchCaseVisitHistory(String loanNo) async {
    try {
      final now = istNow;
      final threeMonthsAgo = DateTime(now.year, now.month - 3, now.day);
      final String startDate = DateFormat('yyyy-MM-dd').format(threeMonthsAgo);
      final List<dynamic> raw = await _fetchAllPages(url: visitUrl, filters: {'start_date': startDate});
      final String targetLoan = loanNo.trim().toLowerCase();
      final List<CaseActivity> activities = [];
      for (var v in raw) {
        final map = Map<String, dynamic>.from(v);
        final String currentLoan = (map['loan_no'] ?? map['case_no'] ?? '').toString().trim().toLowerCase();
        if (currentLoan != targetLoan) continue;
        activities.add(CaseActivity(
          title: (map['subject'] ?? 'Visited').toString().toUpperCase(), description: (map['visit_remark'] ?? map['remark'] ?? '').toString(),
          dateTime: DateTime.tryParse((map['created_at'] ?? '').toString()) ?? DateTime.now(), amount: _double(map['payment_rec'] ?? map['amount']),
          photo: (map['visit_image'] ?? map['visit_photo'] ?? '').toString(), location: (map['visit_address'] ?? map['location'] ?? '').toString(),
          followUpDate: DateTime.tryParse((map['projection_date'] ?? map['ptp_date'] ?? '').toString()),
        ));
      }
      activities.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      saveToCache("case_history_$loanNo", activities.map((e) => {
        'title': e.title, 'description': e.description, 'dateTime': e.dateTime.toIso8601String(),
        'amount': e.amount, 'photo': e.photo, 'location': e.location,
        'followUpDate': e.followUpDate?.toIso8601String(),
      }).toList());
      return activities;
    } catch (e) { debugPrint("Fetch Case History Error: $e"); return []; }
  }
}
