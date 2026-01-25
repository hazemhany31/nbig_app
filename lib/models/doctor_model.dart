class Doctor {
  final String id;
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

  Doctor({
    required this.id,
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
  });

  factory Doctor.fromMap(Map<String, dynamic> json) {
    return Doctor(
      id: json['id']?.toString() ?? json['doctorId']?.toString() ?? '0',
      name: json['name']?.toString() ?? 'Unknown',
      nameAr:
          json['arName']?.toString() ?? json['name']?.toString() ?? 'غير معروف',
      specialty: json['speciality']?.toString() ?? 'General',
      specialtyAr: json['arSpeciality']?.toString() ?? 'عام',
      rating: json['rating']?.toString() ?? '4.8',
      image: json['image']?.toString() ?? '',
      gender: json['gender']?.toString() ?? 'Male',
      about: _stripHtml(json['introduction']?.toString() ?? 'No details.'),
      aboutAr: _stripHtml(
        json['arIntroduction']?.toString() ?? 'لا توجد تفاصيل.',
      ),
      reviews: int.tryParse(json['reviews']?.toString() ?? '120') ?? 120,
      patients: "500+",
      experience: "10 Yrs",
      isFavorite: false,
    );
  }

  static String _stripHtml(String htmlString) {
    RegExp exp = RegExp(r"<[^>]*>", multiLine: true, caseSensitive: true);
    return htmlString.replaceAll(exp, '').trim();
  }
}
