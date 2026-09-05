enum UserRole {
  customer,
  tukang,
}

enum PaymentMethod {
  cash,
  ewallet,
  bankTransfer;

  String toDbValue() {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.ewallet:
        return 'ewallet';
      case PaymentMethod.bankTransfer:
        return 'bank_transfer';
    }
  }

  static PaymentMethod fromDbValue(String value) {
    switch (value) {
      case 'cash':
        return PaymentMethod.cash;
      case 'ewallet':
        return PaymentMethod.ewallet;
      case 'bank_transfer':
        return PaymentMethod.bankTransfer;
      default:
        return PaymentMethod.cash;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Tunai (Cash)';
      case PaymentMethod.ewallet:
        return 'E-Wallet';
      case PaymentMethod.bankTransfer:
        return 'Transfer Bank';
    }
  }
}

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? avatarUrl;
  final bool isCustomer;
  final bool isTukang;
  final bool isAdmin;
  final bool isSuspended;
  final bool isOnline;
  final double? lat;
  final double? lng;
  final DateTime createdAt;
  final DateTime updatedAt;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.avatarUrl,
    required this.isCustomer,
    required this.isTukang,
    required this.isAdmin,
    required this.isSuspended,
    required this.isOnline,
    this.lat,
    this.lng,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasDualRole => isCustomer && isTukang;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      isCustomer: json['is_customer'] as bool? ?? false,
      isTukang: json['is_tukang'] as bool? ?? false,
      isAdmin: json['is_admin'] as bool? ?? false,
      isSuspended: json['is_suspended'] as bool? ?? false,
      isOnline: json['is_online'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'phone': phone,
      'avatar_url': avatarUrl,
      'is_customer': isCustomer,
      'is_tukang': isTukang,
      'is_admin': isAdmin,
      'is_suspended': isSuspended,
      'is_online': isOnline,
      'lat': lat,
      'lng': lng,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? fullName,
    String? phone,
    String? avatarUrl,
    bool? isCustomer,
    bool? isTukang,
    bool? isAdmin,
    bool? isSuspended,
    bool? isOnline,
    double? lat,
    double? lng,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      isCustomer: isCustomer ?? this.isCustomer,
      isTukang: isTukang ?? this.isTukang,
      isAdmin: isAdmin ?? this.isAdmin,
      isSuspended: isSuspended ?? this.isSuspended,
      isOnline: isOnline ?? this.isOnline,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class TukangProfile {
  final String profileId;
  final String bio;
  final List<String> serviceTypeIds;
  final List<PaymentMethod> paymentMethods;
  final Map<String, dynamic> paymentDetails;
  final int serviceRadiusKm;
  final double ratingAvg;
  final int jobCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TukangProfile({
    required this.profileId,
    required this.bio,
    required this.serviceTypeIds,
    required this.paymentMethods,
    this.paymentDetails = const {},
    this.serviceRadiusKm = 50,
    required this.ratingAvg,
    required this.jobCount,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TukangProfile.fromJson(Map<String, dynamic> json) {
    final rawServices = json['service_type_ids'];
    final serviceIds = rawServices is List
        ? rawServices.map((e) => e.toString()).toList()
        : <String>[];

    final rawMethods = json['payment_methods'];
    final methods = rawMethods is List
        ? rawMethods
            .map((e) => PaymentMethod.fromDbValue(e.toString()))
            .toList()
        : <PaymentMethod>[];

    final details = json['payment_details'] is Map<String, dynamic>
        ? json['payment_details'] as Map<String, dynamic>
        : <String, dynamic>{};

    return TukangProfile(
      profileId: json['profile_id'] as String,
      bio: json['bio'] as String? ?? '',
      serviceTypeIds: serviceIds,
      paymentMethods: methods,
      paymentDetails: details,
      serviceRadiusKm: json['service_radius_km'] as int? ?? 50,
      ratingAvg: (json['rating_avg'] as num?)?.toDouble() ?? 0.0,
      jobCount: json['job_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'profile_id': profileId,
      'bio': bio,
      'service_type_ids': serviceTypeIds,
      'payment_methods': paymentMethods.map((m) => m.toDbValue()).toList(),
      'payment_details': paymentDetails,
      'service_radius_km': serviceRadiusKm,
      'rating_avg': ratingAvg,
      'job_count': jobCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ServiceCategory {
  final String id;
  final String name;
  final String slug;
  final String? icon;
  final int sortOrder;
  final DateTime createdAt;

  const ServiceCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.icon,
    required this.sortOrder,
    required this.createdAt,
  });

  factory ServiceCategory.fromJson(Map<String, dynamic> json) {
    return ServiceCategory(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      icon: json['icon'] as String?,
      sortOrder: json['sort_order'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'icon': icon,
      'sort_order': sortOrder,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
