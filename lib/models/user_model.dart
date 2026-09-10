import 'package:flutter/foundation.dart';

class UserModel {
  final int id;
  final String name;
  final String email;
  final String mobile;
  final String? profileImage;
  final String address;
  final String city;
  final String role;
  final int? roleId;
  final String? code;
  final Map<String, dynamic> rawJson;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.mobile,
    this.profileImage,
    required this.address,
    required this.city,
    required this.role,
    this.roleId,
    this.code,
    this.rawJson = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Extensive name search - Prioritizing 'NAME' as seen in the Manage Users table
    String getName() {
      final keys = [
        'NAME', 'name', 'full_name', 'FULL_NAME', 'username', 'user_name', 
        'display_name', 'exe_name', 'staff_name', 'emp_name', 'first_name', 
        'last_name', 'displayName', 'user_full_name'
      ];
      for (var key in keys) {
        final val = json[key];
        if (val != null && 
            val.toString().toLowerCase() != 'null' && 
            val.toString().trim().isNotEmpty &&
            val.toString().length > 1) {
          return val.toString();
        }
      }
      return 'User';
    }

    String displayName = getName().trim();
    
    // Absolute Search for Role: check every single value in the JSON for the word "TL"
    String discoverRole() {
      debugPrint("RAW USER JSON: $json");
      
      bool foundTL = false;
      json.forEach((key, value) {
        if (value != null) {
          final String v = value.toString().toUpperCase();
          // Match "TL" as a standalone word or "Team Leader"
          if (v == 'TL' || v.contains('TEAM LEADER') || v.contains('TEAM-LEADER') || 
              v.split(RegExp(r'[^A-Z]')).contains('TL')) {
            foundTL = true;
          }
        }
      });
      if (foundTL) return "TL";

      // 2. Default extraction logic for other roles
      String base = "";
      if (json['role'] != null) {
        if (json['role'] is Map) {
          base = json['role']['rolename'] ?? json['role']['name'] ?? '';
        } else {
          base = json['role'].toString();
        }
      }
      
      if (base.isEmpty || base.toLowerCase() == 'null' || base.toLowerCase() == 'user account') {
        base = json['position'] ?? 
               json['POSITION'] ??
               json['user_position'] ??
               json['rolename'] ?? 
               json['designation'] ?? 
               json['user_type'] ?? 
               json['type'] ?? '';
      }
      return base.trim();
    }

    String roleName = discoverRole();
    String roleLower = roleName.toLowerCase();
    
    bool isTL = roleName == "TL"; 
    bool isACM = roleLower.contains('acm') || roleLower.contains('manager');

    int rid = _int(json['role_id']);
    bool isAdmin = json['is_admin'] == 1 || 
                   json['is_admin'] == true || 
                   rid == 1 || 
                   roleLower.contains('admin');
    
    if (isAdmin && (roleName.isEmpty || roleLower == 'executive' || roleLower == 'employee' || roleLower == 'user account')) {
      roleName = 'Administrator';
    } else if (isTL) {
      roleName = 'TL';
    } else if (isACM) {
      roleName = 'ACM';
    } else {
      roleName = 'Executive';
    }

    if (roleName.isEmpty) roleName = 'Executive';

    return UserModel(
      id: _int(json['id']),
      name: displayName,
      email: _str(json['email']),
      mobile: _str(json['mobile']),
      profileImage: _str(json['profile_image'] ?? json['image']),
      address: _str(json['address']),
      city: _str(json['city']),
      roleId: rid,
      role: roleName,
      code: _str(json['code'] ?? json['Code'] ?? json['CODE'] ?? json['emp_code'] ?? json['staff_code']),
      rawJson: json,
    );
  }

  static String _str(dynamic v) => v == null || v == 'null' ? '' : v.toString();
  static int _int(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    return int.tryParse(v.toString()) ?? 0;
  }

  String get cleanName {
    if (name.isEmpty) return "";
    // Removes "e1470-" or "e1470_" or similar employee code prefixes
    final RegExp separator = RegExp(r'[-_]');
    if (name.contains(separator)) {
      final parts = name.split(separator);
      if (parts.length > 1) {
        return parts.sublist(1).join(' ').trim();
      }
    }
    return name.trim();
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'mobile': mobile,
      'profile_image': profileImage,
      'address': address,
      'city': city,
      'role_id': roleId,
      'role': role,
      'code': code,
      'rawJson': rawJson,
    };
  }
}
