import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_colors.dart';
import '../utils/format_utils.dart';
import '../services/location_service.dart';
import '../services/collection_api_service.dart';

class MapTrackingPage extends StatefulWidget {
  final double lat;
  final double lng;
  final String name;
  final int? executiveId;
  final bool initialHistoryMode;
  final DateTime? initialDate;

  const MapTrackingPage({
    super.key,
    required this.lat,
    required this.lng,
    required this.name,
    this.executiveId,
    this.initialHistoryMode = false,
    this.initialDate,
  });

  @override
  State<MapTrackingPage> createState() => _MapTrackingPageState();
}

class _MapTrackingPageState extends State<MapTrackingPage> {
  late double currentLat;
  late double currentLng;
  final MapController _mapController = MapController();
  Timer? _pollingTimer;
  StreamSubscription<Position>? _positionSubscription;

  bool isHistoryMode = false;
  List<Map<String, dynamic>> historyData = [];
  bool isLoadingHistory = false;
  DateTime selectedDate = DateTime.now();
  bool showOnlyVisits = false;
  double historyDistance = 0.0;
  int totalVisits = 0;

  @override
  void initState() {
    super.initState();
    currentLat = _isValid(widget.lat) ? widget.lat : 26.9124; // Default to Jaipur if invalid
    currentLng = _isValid(widget.lng) ? widget.lng : 75.7873;
    isHistoryMode = widget.initialHistoryMode;
    if (widget.initialDate != null) {
      selectedDate = widget.initialDate!;
    }

    if (isHistoryMode) {
      _fetchHistory();
    }

    if (widget.executiveId != null && !isHistoryMode) {
      _startPolling();
    } else if (widget.executiveId == null) {
      _startLocalTracking();
    }
  }

  bool _isValid(double val) => !val.isNaN && !val.isInfinite && val != 0.0;

  double _safeParse(dynamic v) {
    if (v == null) return 0.0;
    final double? p = double.tryParse(v.toString());
    if (p == null || p.isNaN || p.isInfinite) return 0.0;
    return p;
  }

  String _getLoanNo(Map<String, dynamic> map) {
    final keys = [
      'case no', 'Case No', 'CASE NO', 'case_no', 'loan_no', 'CaseNo', 'LoanNo', 'caseno', 'loanno'
    ];
    for (var key in keys) {
      if (map[key] != null && map[key].toString().isNotEmpty && map[key].toString() != 'null') {
        return map[key].toString();
      }
    }
    return '';
  }

  String _getCleanName(String name) {
    if (name.isEmpty) return "";
    final RegExp prefix = RegExp(r'^[eE]\d+[-_]');
    return name.replaceFirst(prefix, "").trim();
  }

  void _startLocalTracking() {
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted && !isHistoryMode) {
        setState(() {
          currentLat = position.latitude;
          currentLng = position.longitude;
        });
        _mapController.move(LatLng(currentLat, currentLng), _mapController.camera.zoom);
      }
    });
  }

  void _startPolling() {
    _fetchHistory();

    _pollingTimer = Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (isHistoryMode) return;
      
      final latest = await LocationService().fetchLatestLocation(widget.executiveId ?? 0);
      if (latest != null && mounted) {
        final double lat = _safeParse(latest['latitude'] ?? latest['lat']);
        final double lng = _safeParse(latest['longitude'] ?? latest['lng']);
        
        if (lat != 0.0 && (lat != currentLat || lng != currentLng)) {
          setState(() {
            currentLat = lat;
            currentLng = lng;
            
            final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
            final selectedDateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
            
            if (todayStr == selectedDateStr) {
              bool exists = historyData.any((h) => 
                h['latitude']?.toString() == lat.toString() && 
                h['longitude']?.toString() == lng.toString()
              );
              
              if (!exists) {
                historyData.add(Map<String, dynamic>.from(latest));
                
                final action = latest['action']?.toString().toLowerCase() ?? '';
                final loanNo = latest['loan_no']?.toString() ?? latest['case_no']?.toString() ?? '';
                if (action.contains('visit') || action.contains('submit') || loanNo.isNotEmpty) {
                  totalVisits++;
                }

                if (historyData.length > 1) {
                  final lastPoint = historyData[historyData.length - 2];
                  final pLat = _safeParse(lastPoint['latitude'] ?? lastPoint['lat']);
                  final pLng = _safeParse(lastPoint['longitude'] ?? lastPoint['lng']);
                  if (pLat != 0.0) {
                    final d = Geolocator.distanceBetween(pLat, pLng, lat, lng);
                    if (d.isFinite) historyDistance += d / 1000.0;
                  }
                }
              }
            }
          });
          _mapController.move(
            LatLng(currentLat, currentLng), 
            _mapController.camera.zoom.isFinite ? _mapController.camera.zoom : 15.0
          );
        }
      }
    });
  }

  Future<void> _fetchHistory() async {
    setState(() {
      isLoadingHistory = true;
      historyData = [];
      historyDistance = 0.0;
      totalVisits = 0;
    });

    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(selectedDate);
      final cleanName = _getCleanName(widget.name);
      
      // 1. Fetch raw movement (for polyline)
      final movementList = await LocationService().fetchLocationHistory(widget.executiveId ?? 0, date: dateStr);
      
      // 2. Fetch specific visits (Primary + Joint)
      final Future<List<Map<String, dynamic>>> primaryVisitsFuture = CollectionApiService.fetchVisits(
        filters: {'exe_name': widget.name, 'today_entry_date': dateStr},
        perPage: 1000
      );
      
      final Future<List<Map<String, dynamic>>> jointVisitsFuture = CollectionApiService.fetchVisits(
        filters: {'tc_name': widget.name, 'today_entry_date': dateStr},
        perPage: 1000
      );

      final List<List<Map<String, dynamic>>> results = await Future.wait([primaryVisitsFuture, jointVisitsFuture]);
      final List<Map<String, dynamic>> primaryVisits = results[0];
      final List<Map<String, dynamic>> jointVisits = results[1];

      debugPrint("API returned ${movementList.length} movements, ${primaryVisits.length} primary visits and ${jointVisits.length} joint visits");

      // Merge and sort by time, de-duplicate visits by ID
      final Map<dynamic, Map<String, dynamic>> visitMap = {};
      for (var v in primaryVisits) {
        visitMap[v['id']] = {...v, 'is_visit': true, 'is_joint': false};
      }
      for (var v in jointVisits) {
        if (!visitMap.containsKey(v['id'])) {
          visitMap[v['id']] = {...v, 'is_visit': true, 'is_joint': true};
        }
      }

      final List<Map<String, dynamic>> combined = [
        ...movementList.map((e) => {...Map<String, dynamic>.from(e), 'is_visit': false, 'is_joint': false}),
        ...visitMap.values
      ];

      if (combined.isNotEmpty) {
        final List<Map<String, dynamic>> filteredMapped = [];
        final List<LatLng> points = [];
        double totalDist = 0.0;
        int visitCount = 0;
        LatLng? prev;

        // Sort combined data by time to draw continuous path
        combined.sort((a, b) {
          final t1 = DateTime.tryParse((a['time'] ?? a['created_at'] ?? a['timestamp'] ?? '').toString()) ?? DateTime(2000);
          final t2 = DateTime.tryParse((b['time'] ?? b['created_at'] ?? b['timestamp'] ?? '').toString()) ?? DateTime(2000);
          return t1.compareTo(t2);
        });

        for (var item in combined) {
          final double lat = _safeParse(item['latitude'] ?? item['lat'] ?? item['visit_lat']);
          final double lng = _safeParse(item['longitude'] ?? item['lng'] ?? item['visit_long']);
          
          if (lat != 0.0 && lat.isFinite && lng.isFinite) {
            final String rawDate = (item['today_entry_date'] ?? item['time'] ?? item['created_at'] ?? item['timestamp'] ?? '').toString();
            if (rawDate.isNotEmpty) {
              if (!rawDate.contains(dateStr)) continue;
            }

            final curr = LatLng(lat, lng);
            filteredMapped.add(item);
            points.add(curr);
            
            if (prev != null) {
              final double d = Geolocator.distanceBetween(prev.latitude, prev.longitude, curr.latitude, curr.longitude);
              if (d.isFinite) totalDist += d / 1000.0;
            }
            prev = curr;

            final bool isVisit = item['is_visit'] == true;
            final loanNo = _getLoanNo(item);
            if (isVisit || loanNo.isNotEmpty) {
              visitCount++;
            }
          }
        }

        if (mounted) {
          setState(() {
            historyData = filteredMapped;
            historyDistance = totalDist.isFinite ? totalDist : 0.0;
            totalVisits = visitCount;
            
            if (points.isNotEmpty) {
              final last = points.last;
              currentLat = last.latitude;
              currentLng = last.longitude;
            }
          });

          if (points.isNotEmpty) {
            try {
              final validPoints = points.where((p) => p.latitude.isFinite && p.longitude.isFinite).toList();
              if (validPoints.length > 1) {
                final bounds = LatLngBounds.fromPoints(validPoints);
                _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80)));
              } else if (validPoints.length == 1) {
                _mapController.move(validPoints.first, 15.0);
              }
            } catch (e) {
              if (points.isNotEmpty) _mapController.move(points.last, 15.0);
            }
          }
        }
      }
else {
        debugPrint("No data items to display after parsing.");
      }
    } catch (e) {
      debugPrint("History Fetch Error: $e");
    } finally {
      if (mounted) setState(() => isLoadingHistory = false);
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _positionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Expanded(child: Text(isHistoryMode ? 'History: ${widget.name}' : 'Live: ${widget.name}', overflow: TextOverflow.ellipsis)),
            if (!isHistoryMode)
              Container(
                margin: const EdgeInsets.only(left: 8),
                width: 10, height: 10,
                decoration: const BoxDecoration(color: Colors.greenAccent, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4, spreadRadius: 2)]),
              ),
          ],
        ),
        backgroundColor: primaryRed,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(isHistoryMode ? Icons.sensors : Icons.history),
            onPressed: () {
              setState(() {
                isHistoryMode = !isHistoryMode;
                if (isHistoryMode) _fetchHistory();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCenter: LatLng(
                      currentLat.isFinite ? currentLat : 26.9124, 
                      currentLng.isFinite ? currentLng : 75.7873
                    ),
                    initialZoom: 15.0,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
                      userAgentPackageName: 'com.example.safl',
                    ),
                    if (historyData.isNotEmpty)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: historyData.map((e) {
                              final double lat = _safeParse(e['latitude'] ?? e['lat']);
                              final double lng = _safeParse(e['longitude'] ?? e['lng']);
                              if (lat == 0.0 || !lat.isFinite || !lng.isFinite) return null;
                              return LatLng(lat, lng);
                            }).whereType<LatLng>().toList(),
                            strokeWidth: 4,
                            color: primaryBlue,
                          ),
                        ],
                      ),
                    if (historyData.isNotEmpty)
                      MarkerLayer(
                        markers: [
                          ...historyData.asMap().entries.map((entry) {
                            final index = entry.key;
                            final e = entry.value;
                            final double lat = _safeParse(e['latitude'] ?? e['lat']);
                            final double lng = _safeParse(e['longitude'] ?? e['lng']);
                            if (lat == 0.0 || !lat.isFinite || !lng.isFinite) return null;

                            final action = e['action']?.toString().toLowerCase() ?? '';
                            final loanNo = _getLoanNo(e);
                            final bool isVisit = e['is_visit'] == true;
                            final bool isJoint = e['is_joint'] == true;
                            
                            final isCaseAction = isVisit || 
                                               action.contains('visit') || 
                                               action.contains('submit') || 
                                               action.contains('ptp') ||
                                               loanNo.isNotEmpty;
                            
                            if (isCaseAction) {
                              return Marker(
                                point: LatLng(lat, lng),
                                width: 70,
                                height: 70,
                                child: GestureDetector(
                                  onTap: () => _openInExternalMap(lat, lng),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (loanNo.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(4),
                                            boxShadow: const [BoxShadow(blurRadius: 2, color: Colors.black26)],
                                          ),
                                          child: Text(
                                            loanNo,
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.red),
                                          ),
                                        ),
                                      Icon(
                                        Icons.person_pin_circle_rounded, 
                                        color: index == 0 ? successGreen : primaryRed, 
                                        size: 34
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }
                            return null;
                          }).whereType<Marker>(),
                          if (historyData.isNotEmpty)
                            Marker(
                              point: () {
                                final lat = _safeParse(historyData.first['latitude'] ?? historyData.first['lat']);
                                final lng = _safeParse(historyData.first['longitude'] ?? historyData.first['lng']);
                                return LatLng(lat, lng);
                              }(),
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  final double lat = _safeParse(historyData.first['latitude'] ?? historyData.first['lat']);
                                  final double lng = _safeParse(historyData.first['longitude'] ?? historyData.first['lng']);
                                  if (lat != 0.0) _openInExternalMap(lat, lng);
                                },
                                child: const Icon(Icons.location_on_rounded, color: successGreen, size: 36)
                              ),
                            ),
                          if (historyData.isNotEmpty)
                            Marker(
                              point: () {
                                final lat = _safeParse(historyData.last['latitude'] ?? historyData.last['lat']);
                                final lng = _safeParse(historyData.last['longitude'] ?? historyData.last['lng']);
                                return LatLng(lat, lng);
                              }(),
                              width: 50,
                              height: 50,
                              child: GestureDetector(
                                onTap: () {
                                  final double lat = _safeParse(historyData.last['latitude'] ?? historyData.last['lat']);
                                  final double lng = _safeParse(historyData.last['longitude'] ?? historyData.last['lng']);
                                  if (lat != 0.0) _openInExternalMap(lat, lng);
                                },
                                child: const Icon(Icons.location_on_rounded, color: primaryRed, size: 36)
                              ),
                            ),
                        ],
                      ),
                    if (!isHistoryMode || (isHistoryMode && historyData.isEmpty))
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(currentLat, currentLng),
                            width: 80,
                            height: 80,
                            child: GestureDetector(
                              onTap: () => _openInExternalMap(currentLat, currentLng),
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black26)],
                                    ),
                                    child: Text(
                                      widget.name,
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: textHeading),
                                    ),
                                  ),
                                  const Icon(Icons.location_on, color: primaryRed, size: 40),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                if (isHistoryMode)
                  Positioned(
                    top: 16,
                    left: 16,
                    right: 16,
                    child: Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 20, color: primaryRed),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(selectedDate),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            TextButton(
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate,
                                  firstDate: DateTime(2023),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setState(() => selectedDate = picked);
                                  _fetchHistory();
                                }
                              },
                              child: const Text('CHANGE', style: TextStyle(color: primaryRed, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                if (isLoadingHistory)
                  const Center(child: CircularProgressIndicator(color: primaryRed)),
              ],
            ),
          ),
          if (isHistoryMode && historyData.isNotEmpty)
            Container(
              height: 320,
              decoration: BoxDecoration(
                color: surfaceWhite,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15)],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40, height: 4, decoration: BoxDecoration(color: bodyBg, borderRadius: BorderRadius.circular(2)),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _summaryStat("DISTANCE", "${FormatUtils.safeFixed(historyDistance, 1)} KM", Icons.route_rounded, primaryBlue),
                        const SizedBox(width: 12),
                        _summaryStat("TOTAL VISITS", "$totalVisits", Icons.location_history_rounded, primaryRed),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Row(
                      children: [
                        _filterTab("ALL MOVEMENT", !showOnlyVisits, () => setState(() => showOnlyVisits = false)),
                        const SizedBox(width: 10),
                        _filterTab("ONLY VISITS", showOnlyVisits, () => setState(() => showOnlyVisits = true)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: historyData.isEmpty 
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.history_toggle_off_rounded, size: 48, color: textMuted),
                              SizedBox(height: 12),
                              Text("No movement data found for this date.", style: TextStyle(color: textMuted, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          itemCount: historyData.length,
                          itemBuilder: (context, index) {
                            final item = historyData[index];
                            final actionRaw = item['action']?.toString() ?? 'Movement';
                            final time = item['time']?.toString() ?? item['timestamp']?.toString() ?? '';
                            final loanNo = _getLoanNo(item);
                            final bool isVisit = item['is_visit'] == true;
                            final bool isJoint = item['is_joint'] == true;
                            
                            final isCaseAction = isVisit ||
                                               actionRaw.toLowerCase().contains('visit') || 
                                               actionRaw.toLowerCase().contains('submit') || 
                                               actionRaw.toLowerCase().contains('ptp') ||
                                               loanNo.isNotEmpty;

                            String action = isCaseAction ? "VISIT" : actionRaw;
                            if (isJoint) action = "JOINT VISIT";

                            if (showOnlyVisits && !isCaseAction) return const SizedBox.shrink();

                            String displayTime = time;
                            try {
                              if (time.isNotEmpty) {
                                final dt = DateTime.parse(time);
                                displayTime = DateFormat('hh:mm a').format(dt);
                              }
                            } catch (_) {}

                            return IntrinsicHeight(
                              child: Row(
                                children: [
                                  Column(
                                    children: [
                                      Container(width: 10, height: 10, decoration: BoxDecoration(
                                        color: isCaseAction ? primaryRed : (index == 0 ? successGreen : (index == historyData.length - 1 ? primaryRed : primaryBlue)), 
                                        shape: BoxShape.circle
                                      )),
                                      if (index != historyData.length - 1) Expanded(child: Container(width: 2, color: bodyBg)),
                                    ],
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(bottom: 16),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(action.toUpperCase(), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: textHeading)),
                                              Text(displayTime, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: primaryBlue)),
                                            ],
                                          ),
                                          if (loanNo.isNotEmpty)
                                            Text("Loan: $loanNo", style: const TextStyle(fontSize: 12, color: Colors.red, fontWeight: FontWeight.w900)),
                                          Text("${_safeParse(item['latitude'] ?? item['lat'])}, ${_safeParse(item['longitude'] ?? item['lng'])}", style: const TextStyle(fontSize: 11, color: textMuted)),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (isHistoryMode && historyData.isNotEmpty) {
            final last = historyData.last;
            final double lat = _safeParse(last['latitude'] ?? last['lat']);
            final double lng = _safeParse(last['longitude'] ?? last['lng']);
            if (lat != 0.0) {
              _mapController.move(LatLng(lat, lng), 15.0);
            }
          } else if (_isValid(currentLat) && currentLat.isFinite && currentLng.isFinite) {
            _mapController.move(LatLng(currentLat, currentLng), 15.0);
          }
        },
        backgroundColor: primaryRed,
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }

  Widget _summaryStat(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(val, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 15)),
                Text(label, style: const TextStyle(color: textMuted, fontSize: 8, fontWeight: FontWeight.bold)),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _filterTab(String label, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isSelected ? null : Border.all(color: bodyBg),
          ),
          alignment: Alignment.center,
          child: Text(
            label, 
            style: TextStyle(
              color: isSelected ? Colors.white : textMuted, 
              fontWeight: FontWeight.bold, 
              fontSize: 10
            )
          ),
        ),
      ),
    );
  }

  Future<void> _openInExternalMap(double lat, double lng) async {
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps"), backgroundColor: Colors.red)
        );
      }
    }
  }
}
