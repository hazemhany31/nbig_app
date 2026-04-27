import 'package:cloud_firestore/cloud_firestore.dart';

class Donation {
  final String id;
  final String medicineName;
  final String imageUrl;
  final String? dosage;
  final List<String> verifiedBy;
  final String status; // available / pending / donated
  final int quantity;
  final DateTime expiryDate;
  final String phone;
  final String userId;
  final String userType; 
  final DateTime createdAt;
  final bool isRecommended;
  final String location;
  final String donorName;

  Donation({
    required this.id,
    required this.medicineName,
    this.dosage,
    required this.imageUrl,
    required this.quantity,
    required this.expiryDate,
    required this.phone,
    required this.userId,
    required this.userType,
    required this.createdAt,
    this.isRecommended = false,
    this.verifiedBy = const [],
    required this.location,
    required this.donorName,
    this.status = 'available',
  });

  factory Donation.fromMap(Map<String, dynamic> map, String documentId) {
    return Donation(
      id: documentId,
      medicineName: map['medicineName'] ?? '',
      dosage: map['dosage'],
      imageUrl: map['imageUrl'] ?? map['medicineImageUrl'] ?? '',
      quantity: int.tryParse(map['quantity']?.toString() ?? '0') ?? 0,
      expiryDate: (map['expiryDate'] as Timestamp).toDate(),
      phone: map['phone'] ?? '',
      userId: map['userId'] ?? map['donorId'] ?? '',
      userType: map['userType'] ?? 'patient',
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      isRecommended: map['isRecommended'] ?? false,
      verifiedBy: List<String>.from(map['verifiedBy'] ?? []),
      location: map['location'] ?? '',
      donorName: map['donorName'] ?? 'Anonymous',
      status: map['status'] ?? 'available',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'medicineName': medicineName,
      'dosage': dosage,
      'imageUrl': imageUrl,
      'quantity': quantity,
      'expiryDate': Timestamp.fromDate(expiryDate),
      'phone': phone,
      'userId': userId,
      'userType': userType,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRecommended': isRecommended,
      'verifiedBy': verifiedBy,
      'location': location,
      'donorName': donorName,
      'status': status,
    };
  }
}
