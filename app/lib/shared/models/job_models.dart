import 'user_profile.dart';

enum JobStatus {
  open,
  locked,
  inProgress,
  done,
  paid,
  cancelled;

  String toDbValue() {
    switch (this) {
      case JobStatus.open:
        return 'open';
      case JobStatus.locked:
        return 'locked';
      case JobStatus.inProgress:
        return 'in_progress';
      case JobStatus.done:
        return 'done';
      case JobStatus.paid:
        return 'paid';
      case JobStatus.cancelled:
        return 'cancelled';
    }
  }

  static JobStatus fromDbValue(String val) {
    switch (val) {
      case 'open':
        return JobStatus.open;
      case 'locked':
        return JobStatus.locked;
      case 'in_progress':
        return JobStatus.inProgress;
      case 'done':
        return JobStatus.done;
      case 'paid':
        return JobStatus.paid;
      case 'cancelled':
        return JobStatus.cancelled;
      default:
        return JobStatus.open;
    }
  }

  String get displayName {
    switch (this) {
      case JobStatus.open:
        return 'Terbuka';
      case JobStatus.locked:
        return 'Tukang Terpilih';
      case JobStatus.inProgress:
        return 'Sedang Dikerjakan';
      case JobStatus.done:
        return 'Selesai';
      case JobStatus.paid:
        return 'Lunas';
      case JobStatus.cancelled:
        return 'Dibatalkan';
    }
  }
}

enum ApplicationStatus {
  responded,
  selected,
  lockedOut;

  String toDbValue() {
    switch (this) {
      case ApplicationStatus.responded:
        return 'responded';
      case ApplicationStatus.selected:
        return 'selected';
      case ApplicationStatus.lockedOut:
        return 'locked_out';
    }
  }

  static ApplicationStatus fromDbValue(String val) {
    switch (val) {
      case 'responded':
        return ApplicationStatus.responded;
      case 'selected':
        return ApplicationStatus.selected;
      case 'locked_out':
        return ApplicationStatus.lockedOut;
      default:
        return ApplicationStatus.responded;
    }
  }

  String get displayName {
    switch (this) {
      case ApplicationStatus.responded:
        return 'Merespon';
      case ApplicationStatus.selected:
        return 'Terpilih';
      case ApplicationStatus.lockedOut:
        return 'Tidak Terpilih';
    }
  }
}

enum PaymentStatus {
  pending,
  paid;

  String toDbValue() {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.paid:
        return 'paid';
    }
  }

  static PaymentStatus fromDbValue(String val) {
    switch (val) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      default:
        return PaymentStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.pending:
        return 'Menunggu Pembayaran';
      case PaymentStatus.paid:
        return 'Lunas Disetujui';
    }
  }
}

class Job {
  final String id;
  final String customerId;
  final String categoryId;
  final String title;
  final String description;
  final double lat;
  final double lng;
  final JobStatus status;
  final String? selectedProviderId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryName;
  final String? customerName;
  final String? selectedProviderName;

  const Job({
    required this.id,
    required this.customerId,
    required this.categoryId,
    required this.title,
    required this.description,
    required this.lat,
    required this.lng,
    required this.status,
    this.selectedProviderId,
    required this.createdAt,
    required this.updatedAt,
    this.categoryName,
    this.customerName,
    this.selectedProviderName,
  });

  factory Job.fromJson(Map<String, dynamic> json) {
    return Job(
      id: json['id'] as String,
      customerId: json['customer_id'] as String,
      categoryId: json['category_id'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      status: JobStatus.fromDbValue(json['status'] as String? ?? 'open'),
      selectedProviderId: json['selected_provider_id'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      categoryName: json['service_categories'] != null
          ? json['service_categories']['name'] as String?
          : null,
      customerName: json['customer_profile'] != null
          ? json['customer_profile']['full_name'] as String?
          : null,
      selectedProviderName: json['provider_profile'] != null
          ? json['provider_profile']['full_name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'customer_id': customerId,
      'category_id': categoryId,
      'title': title,
      'description': description,
      'lat': lat,
      'lng': lng,
      'status': status.toDbValue(),
      'selected_provider_id': selectedProviderId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Job copyWith({
    String? id,
    String? customerId,
    String? categoryId,
    String? title,
    String? description,
    double? lat,
    double? lng,
    JobStatus? status,
    String? selectedProviderId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? categoryName,
    String? customerName,
    String? selectedProviderName,
  }) {
    return Job(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      categoryId: categoryId ?? this.categoryId,
      title: title ?? this.title,
      description: description ?? this.description,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      status: status ?? this.status,
      selectedProviderId: selectedProviderId ?? this.selectedProviderId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      categoryName: categoryName ?? this.categoryName,
      customerName: customerName ?? this.customerName,
      selectedProviderName: selectedProviderName ?? this.selectedProviderName,
    );
  }
}

class JobApplication {
  final String id;
  final String jobId;
  final String providerId;
  final ApplicationStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? providerName;
  final double? providerRating;
  final String? providerBio;

  const JobApplication({
    required this.id,
    required this.jobId,
    required this.providerId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.providerName,
    this.providerRating,
    this.providerBio,
  });

  factory JobApplication.fromJson(Map<String, dynamic> json) {
    String? name;
    double? rating;
    String? bio;

    if (json['profiles'] != null && json['profiles'] is Map) {
      final p = json['profiles'] as Map<String, dynamic>;
      name = p['full_name'] as String?;
    }

    if (json['tukang_profiles'] != null && json['tukang_profiles'] is Map) {
      final tp = json['tukang_profiles'] as Map<String, dynamic>;
      rating = (tp['rating_avg'] as num?)?.toDouble();
      bio = tp['bio'] as String?;
    }

    return JobApplication(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      providerId: json['provider_id'] as String,
      status: ApplicationStatus.fromDbValue(json['status'] as String? ?? 'responded'),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
      providerName: name,
      providerRating: rating,
      providerBio: bio,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'provider_id': providerId,
      'status': status.toDbValue(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PriceAgreement {
  final String id;
  final String jobId;
  final String customerId;
  final String providerId;
  final int amount;
  final PaymentMethod paymentMethod;
  final PaymentStatus status;
  final bool voided;
  final DateTime createdAt;
  final DateTime? paidAt;
  final String? providerName;

  const PriceAgreement({
    required this.id,
    required this.jobId,
    required this.customerId,
    required this.providerId,
    required this.amount,
    required this.paymentMethod,
    required this.status,
    required this.voided,
    required this.createdAt,
    this.paidAt,
    this.providerName,
  });

  factory PriceAgreement.fromJson(Map<String, dynamic> json) {
    return PriceAgreement(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      customerId: json['customer_id'] as String,
      providerId: json['provider_id'] as String,
      amount: json['amount'] as int? ?? 0,
      paymentMethod: PaymentMethod.fromDbValue(json['payment_method'] as String? ?? 'cash'),
      status: PaymentStatus.fromDbValue(json['status'] as String? ?? 'pending'),
      voided: json['voided'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      paidAt: json['paid_at'] != null
          ? DateTime.parse(json['paid_at'] as String)
          : null,
      providerName: json['profiles'] != null
          ? json['profiles']['full_name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'customer_id': customerId,
      'provider_id': providerId,
      'amount': amount,
      'payment_method': paymentMethod.toDbValue(),
      'status': status.toDbValue(),
      'voided': voided,
      'created_at': createdAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
    };
  }
}

class ChatMessage {
  final String id;
  final String jobId;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final String? senderName;

  const ChatMessage({
    required this.id,
    required this.jobId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.senderName,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      jobId: json['job_id'] as String,
      senderId: json['sender_id'] as String,
      body: json['body'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      senderName: json['profiles'] != null
          ? json['profiles']['full_name'] as String?
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_id': jobId,
      'sender_id': senderId,
      'body': body,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class AppNotificationItem {
  final String id;
  final String userId;
  final String type;
  final String? jobId;
  final String body;
  final bool read;
  final DateTime createdAt;

  const AppNotificationItem({
    required this.id,
    required this.userId,
    required this.type,
    this.jobId,
    required this.body,
    required this.read,
    required this.createdAt,
  });

  factory AppNotificationItem.fromJson(Map<String, dynamic> json) {
    return AppNotificationItem(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      type: json['type'] as String? ?? 'info',
      jobId: json['job_id'] as String?,
      body: json['body'] as String? ?? '',
      read: json['read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'job_id': jobId,
      'body': body,
      'read': read,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
