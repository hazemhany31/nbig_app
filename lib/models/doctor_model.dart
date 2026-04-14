class Doctor {
  final String id;
  final String userId; // Firebase Auth UID
  final String name;
  final String nameAr; // الاسم العربي
  final String specialty;
  final String specialtyAr; // التخصص العربي
  final String rating;
  final String image;
  final String gender;
  final String about;
  final String aboutAr; // النبذة العربي
  final int reviews;
  final String patients;
  final String experience;
  bool isFavorite;
  final bool isOnline;
  final DateTime? lastSeen;
  final String price; // سعر الكشف
  final String phone; // رقم الهاتف
  final String workingHours; // ساعات العمل
  final Map<String, dynamic> schedule; // جدول المواعيد المتاح
  final String? facebook;
  final String? instagram;
  final String? linkedin;
  final String? twitter;

  static const Map<String, String> _specializationTranslations = {
    'Internal Medicine': 'باطنة',
    'Pediatrics': 'أطفال',
    'Obstetrics & Gynecology': 'نساء وتوليد',
    'General Surgery': 'جراحة عامة',
    'Orthopedics': 'عظام',
    'Cardiology': 'قلب',
    'ENT': 'أنف وأذن وحنجرة',
    'Dermatology': 'جلدية',
    'Ophthalmology': 'عيون',
    'Dentistry': 'أسنان',
    'Neurology': 'مخ وأعصاب',
    'Psychiatry': 'نفسية',
    'Other': 'أخرى',
    'General': 'عام',
  };

  static String getSpecialtyAr(String en) {
    if (_specializationTranslations.containsKey(en)) {
      return _specializationTranslations[en]!;
    }
    // If not in map, maybe it's already Arabic or a custom English string
    return en;
  }

  Doctor({
    required this.id,
    required this.userId,
    required this.name,
    required this.nameAr,
    required this.specialty,
    required this.specialtyAr,
    required this.rating,
    required this.image,
    required this.gender,
    required this.about,
    required this.aboutAr,
    required this.reviews,
    required this.patients,
    required this.experience,
    this.isFavorite = false,
    this.isOnline = false,
    this.lastSeen,
    this.price = '',
    this.phone = '',
    this.workingHours = '',
    this.schedule = const {},
    this.facebook,
    this.instagram,
    this.linkedin,
    this.twitter,
  });

  factory Doctor.fromMap(Map<String, dynamic> json) {
    return Doctor(
      id: json['id']?.toString() ?? json['doctorId']?.toString() ?? '0',
      userId: json['userId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Unknown',
      nameAr:
          json['arName']?.toString() ??
          json['nameAr']?.toString() ??
          json['name']?.toString() ??
          'غير معروف',
      specialty:
          json['specialization']?.toString() ??
          json['speciality']?.toString() ??
          json['specialty']?.toString() ??
          'General',
      specialtyAr:
          json['specialtyAr']?.toString() ??
          json['arSpeciality']?.toString() ??
          json['specializationAr']?.toString() ??
          getSpecialtyAr(
            json['specialization']?.toString() ??
            json['speciality']?.toString() ??
            json['specialty']?.toString() ??
            'General',
          ),
      rating: json['rating']?.toString() ?? '4.8',
      image: json['image']?.toString() ?? json['photoUrl']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'Male',
      about: _stripHtml(
        json['about']?.toString() ??
            json['introduction']?.toString() ??
            json['bio']?.toString() ??
            'No details.',
      ),
      aboutAr: _stripHtml(
        json['aboutAr']?.toString() ??
            json['arIntroduction']?.toString() ??
            json['bio']?.toString() ??
            'لا توجد تفاصيل.',
      ),
      reviews:
          int.tryParse(
            json['reviews']?.toString() ??
                json['reviewsCount']?.toString() ??
                '120',
          ) ??
          120,
      patients: json['patients']?.toString() ?? "500+",
      experience:
          json['experience']?.toString() ??
          (json['yearsOfExperience'] != null
              ? '${json['yearsOfExperience']} Yrs'
              : '10 Yrs'),
      isFavorite: json['isFavorite'] == true,
      isOnline: json['isOnline'] == true,
      lastSeen: json['lastSeen'] != null
          ? (json['lastSeen'] is DateTime
                ? json['lastSeen']
                : DateTime.tryParse(json['lastSeen'].toString()))
          : null,
      price:
          (json['clinicInfo'] is Map && (json['clinicInfo'] as Map)['fees'] != null)
              ? (json['clinicInfo'] as Map)['fees'].toString()
              : (json['clinicInfo'] is Map && (json['clinicInfo'] as Map)['price'] != null)
                  ? (json['clinicInfo'] as Map)['price'].toString()
                  : json['consultationFee']?.toString() ??
                      json['price']?.toString() ??
                      json['fee']?.toString() ??
                      '',
      phone:
          json['phone']?.toString() ??
          json['phoneNumber']?.toString() ??
          json['mobile']?.toString() ??
          ((json['clinicInfo'] is Map && (json['clinicInfo'] as Map)['phone'] != null)
              ? (json['clinicInfo'] as Map)['phone'].toString()
              : ''),
      workingHours:
          (json['clinicInfo'] is Map &&
              (json['clinicInfo'] as Map)['workingHours'] != null)
          ? (json['clinicInfo'] as Map)['workingHours'].toString()
          : json['workingHours']?.toString() ?? '',
      schedule: (json['schedule'] as Map?)?.cast<String, dynamic>() ?? {},
      facebook: json['facebook']?.toString(),
      instagram: json['instagram']?.toString(),
      linkedin: json['linkedin']?.toString(),
      twitter: json['twitter']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'nameAr': nameAr,
      'specialization': specialty,
      'specialtyAr': specialtyAr,
      'rating': rating,
      'image': image,
      'photoUrl': image,
      'gender': gender,
      'introduction': about,
      'arIntroduction': aboutAr,
      'about': about,
      'aboutAr': aboutAr,
      'reviews': reviews,
      'patients': patients,
      'experience': experience,
      'isFavorite': isFavorite,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'price': price,
      'phone': phone,
      'workingHours': workingHours,
      'schedule': schedule,
      'facebook': facebook,
      'instagram': instagram,
      'linkedin': linkedin,
      'twitter': twitter,
    };
  }

  static String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }
}
