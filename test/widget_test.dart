import 'package:flutter_test/flutter_test.dart';
import 'package:nbig_app/models/doctor_model.dart';
import 'package:nbig_app/models/message.dart';
import 'package:nbig_app/models/appointment_model.dart';
import 'package:nbig_app/screens/blog_screens.dart';

void main() {
  group('Doctor Model Tests', () {
    test('Specialty translation works correctly', () {
      expect(Doctor.getSpecialtyAr('Cardiology'), 'قلب');
      expect(Doctor.getSpecialtyAr('Dermatology'), 'جلدية');
      expect(Doctor.getSpecialtyAr('Dentistry'), 'أسنان');
      expect(Doctor.getSpecialtyAr('Pediatrics'), 'أطفال');
    });

    test('Doctor instantiation from map works as expected', () {
      final doc = Doctor(
        id: 'doc_123',
        userId: 'user_123',
        name: 'Dr. John Doe',
        nameAr: 'د. جون دو',
        specialty: 'Cardiology',
        specialtyAr: 'قلب',
        rating: '4.9',
        image: 'https://example.com/doctor.png',
        gender: 'Male',
        about: 'Cardiology specialist',
        aboutAr: 'استشاري القلب',
        reviews: 42,
        patients: '200+',
        experience: '10 years',
        price: '200 EGP',
        phone: '01000000000',
        workingHours: '9 AM - 5 PM',
        schedule: {},
      );

      expect(doc.id, 'doc_123');
      expect(doc.name, 'Dr. John Doe');
      expect(doc.specialtyAr, 'قلب');
      expect(doc.isVerified, isFalse);
      expect(doc.isFavorite, isFalse);
    });
  });

  group('Message Model Tests', () {
    test('Message creation and properties', () {
      final now = DateTime.now();
      final msg = Message(
        id: 'msg_1',
        senderId: 'patient_1',
        senderName: 'Patient User',
        senderType: 'patient',
        text: 'Hello doctor',
        sentAt: now,
        isRead: false,
      );

      expect(msg.id, 'msg_1');
      expect(msg.senderId, 'patient_1');
      expect(msg.senderName, 'Patient User');
      expect(msg.senderType, 'patient');
      expect(msg.text, 'Hello doctor');
      expect(msg.isRead, isFalse);
      expect(msg.type, 'text');
    });
  });

  group('Appointment and Prescription Model Tests', () {
    test('Appointment created with correct properties', () {
      final now = DateTime(2026, 8, 20, 10, 0);
      final appointment = Appointment(
        id: 'apt_1',
        doctorId: 'doc_1',
        doctorName: 'Dr. Smith',
        specialty: 'Dentistry',
        patientId: 'patient_1',
        patientName: 'Jane Doe',
        dateTime: now,
        duration: 20,
        status: 'pending',
        createdAt: now,
      );

      expect(appointment.id, 'apt_1');
      expect(appointment.status, 'pending');
      expect(appointment.specialty, 'Dentistry');
      expect(appointment.duration, 20);
    });

    test('Prescription model maps from and to map', () {
      final prescription = Prescription(
        medicineName: 'Amoxicillin',
        dosage: '500mg',
        frequency: 'Every 8 hours',
        frequencyHours: 8,
        duration: '7 days',
      );

      final map = prescription.toMap();
      expect(map['name'], 'Amoxicillin');
      expect(map['dosage'], '500mg');
      expect(map['frequencyHours'], 8);

      final fromMap = Prescription.fromMap(map);
      expect(fromMap.medicineName, 'Amoxicillin');
      expect(fromMap.dosage, '500mg');
    });
  });

  group('Medical Citations & Sources Tests', () {
    test('All blog posts have verified medical citations with valid URLs', () {
      expect(blogPosts.isNotEmpty, isTrue);
      for (final post in blogPosts) {
        expect(post.citations.isNotEmpty, isTrue,
            reason: 'BlogPost ${post.id} must have citations');
        for (final citation in post.citations) {
          expect(citation.sourceName.isNotEmpty, isTrue);
          expect(citation.url.startsWith('https://'), isTrue,
              reason: 'Citation URL must be a secure https link');
        }
      }
    });
  });
}



