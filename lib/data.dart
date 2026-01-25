import 'package:flutter/material.dart';

// === داتا الدكاترة ===
final List<Map<String, dynamic>> doctors = [
  {
    "name": "Dr. Mohamed Ali",
    "specialty": "Cardiologist",
    "rating": "4.9",
    "image": "assets/images/doctor_big_preview.png",
    "reviews": "120",
    "about": "Expert in open heart surgeries with 15 years of experience.",
    "color": Colors.blue,
    "isFavorite": false,
  },
  {
    "name": "Dr. Sarah Ahmed",
    "specialty": "Dental",
    "rating": "4.8",
    "image": "assets/images/doctor_big_preview.png",
    "reviews": "85",
    "about": "Specialist in cosmetic dentistry and implants.",
    "color": Colors.redAccent,
    "isFavorite": false,
  },
  {
    "name": "Dr. Khaled Ibrahim",
    "specialty": "Eye Specialist",
    "rating": "4.6",
    "image": "assets/images/doctor_big_preview.png",
    "reviews": "60",
    "about": "LASIK and cataract surgery expert.",
    "color": Colors.orange,
    "isFavorite": false,
  },
  {
    "name": "Dr. Mona Zaki",
    "specialty": "Pediatrician",
    "rating": "5.0",
    "image": "assets/images/doctor_big_preview.png",
    "reviews": "200",
    "about": "Kids love her! She makes the checkup fun.",
    "color": Colors.pink,
    "isFavorite": false,
  },
];

// قوائم المواعيد
List<Map<String, String>> upcomingAppointments = [];
List<Map<String, String>> canceledAppointments = [];
