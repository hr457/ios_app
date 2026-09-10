import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'collection_api_service.dart';
import 'attendance_service.dart';
import 'target_service.dart';
import 'auth_service.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  factory SyncService() => _instance;
  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;
  StreamSubscription? _connectivitySubscription;

  void init() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        debugPrint("🌐 Internet Restored. Triggering pending visit sync...");
        CollectionApiService.syncPendingVisits();
      }
    });
  }

  void dispose() {
    _connectivitySubscription?.cancel();
  }

  Future<void> performFullSync({bool force = false}) async {
    if (_isSyncing) return;
    
    final user = await AuthService.getUserData();
    if (user == null) return;

    _isSyncing = true;
    debugPrint("🚀 Starting Global Background Sync...");

    try {
      // Always try to push pending visits first when starting a sync
      await CollectionApiService.syncPendingVisits();

      // Priority 1: Main Dashboard Data (Fastest & most visible)
      await Future.wait([
        CollectionApiService.fetchDashboardData(),
        CollectionApiService.fetchOutcomeCounts(),
      ]);
      debugPrint("⚡ Priority 1 Sync Completed (Dashboard)");

      // Priority 2: Enhanced Stats & Default Lists (Heavier)
      final heavyTask = () async {
        // Fetch recent visits (90 days) first so collections can be enriched instantly
        await CollectionApiService.fetchRecentVisits(force: force);
        
        await Future.wait([
          CollectionApiService.fetchEnhancedDashboardStats(),
          // Fetch ALL collections for master cache (No page limit)
          CollectionApiService.fetchCollections(filters: {'all_data': '1'}, page: 1, enrich: true),
          AttendanceService().getAttendanceSummary(),
          AttendanceService().getAttendanceData(),
          TargetService.fetchTargetMasters(force: force),
          CollectionApiService.fetchMyTasks(),
        ]);
        debugPrint("✅ Global Background Sync Fully Completed.");
      };

      if (force) {
        // If forced (manual sync), wait for everything to ensure data is in storage
        await heavyTask();
      } else {
        // Otherwise run in background
        Future(heavyTask);
      }
      
    } catch (e) {
      debugPrint("❌ Global Sync Error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  /// Checks if a sync is needed based on the 11:00 AM rule.
  Future<void> checkScheduledSync() async {
    final now = DateTime.now();
    
    // Define the cutoff: 11:00 AM today
    final cutoff = DateTime(now.year, now.month, now.day, 11, 0);
    
    if (now.isAfter(cutoff)) {
      final lastSyncStr = await CollectionApiService.loadFromCacheFull("global_sync_ts");
      final lastSync = lastSyncStr != null ? DateTime.tryParse(lastSyncStr['ts'] ?? '') : null;
      
      // If we haven't synced today AFTER 11 AM, do it now
      if (lastSync == null || lastSync.isBefore(cutoff)) {
        debugPrint("⏰ 11:00 AM cutoff reached. Triggering auto-refresh...");
        await performFullSync(force: true);
        await CollectionApiService.saveToCache("global_sync_ts", "synced");
      }
    }
  }
}
