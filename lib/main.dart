import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'screens/auth/auth_check.dart';
import 'services/notification_service.dart';
import 'services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // === تهيئة Firebase مع الإعدادات الصحيحة ===
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await NotificationService().init();

  // === حذف الدكاترة القديمة بناءً على طلب المستخدم ===
  await DatabaseHelper().recreateDoctorsTable();

  // === إضافة الدكتور مجدي (البيانات الجديدة) ===
  await DatabaseHelper().insertDoctor({
    'name': 'Dr. Magdy Mohammad Fakhr Hussein',
    'arName': 'د. مجدي محمد فخر حسين',
    'speciality': 'Biotechnology & Analysis Specialist',
    'arSpeciality': 'أخصائي تحاليل بيولوجية وتكنولوجيا حيوية',
    'rating': '5.0',
    'image': 'assets/images/dr_magdy.png',
    'introduction':
        'Highly qualified specialist with a PhD in Biotechnology from the University of Sadat City and an M.Sc. in Genetic Engineering & Biotechnology (GEBRI). Holds a Diploma in Biology Analysis from Al-Azhar University and a BSc in Chemistry & Physics from Cairo University. Certified expert in PCR (Molecular Biology for DNA) and Chromatography techniques. Additionally holds Diplomas in Total Quality Management (ISO 9001 & ISO 14001) and Internal Audit (ISO 19011/2018). Formerly Production Planning Section Head at a leading Pharmaceutical company.',
    'arIntroduction':
        'أخصائي قدير حاصل على الدكتوراه في التكنولوجيا الحيوية من جامعة مدينة السادات، وماجستير في الهندسة الوراثية والتكنولوجيا الحيوية (GEBRI). حاصل على دبلومة التحاليل البيولوجية من جامعة الأزهر وبكالوريوس العلوم (كيمياء وفيزياء) من جامعة القاهرة. خبير معتمد في تقنيات تفاعل البوليميراز المتسلسل (PCR) والكروماتوغرافيا. بالإضافة إلى ذلك، حاصل على دبلومات في إدارة الجودة الشاملة (ISO 9001 و ISO 14001) والمراجعة الداخلية (ISO 19011/2018). شغل سابقاً منصب رئيس قسم تخطيط الإنتاج في إحدى شركات الأدوية الكبرى.',
    'reviews': '320',
    'gender': 'Male',
  });

  // === إضافة دكتورة شهد (البيانات الجديدة) ===
  await DatabaseHelper().insertDoctor({
    'name': 'Dr. Shahd Al-Hamadani',
    'arName': 'د. شهد الحمداني',
    'speciality': 'Dentist',
    'arSpeciality': 'طبيبة أسنان',
    'rating': '4.9',
    'image': 'assets/images/dr_shahd.png',
    'introduction':
        'Expert Dentist with over 11 years of experience in comprehensive dental care covering all treatments. Holds the prestigious Italian Fellowship in Laser Dentistry applications. Proudly certified by the American Dental Association (ADA) in both Endodontics (Root Canal) and Dental Implants. Committed to providing pain-free and cutting-edge dental solutions.',
    'arIntroduction':
        'خبرة أكثر من 11 سنة في جميع مجالات وعلاجات طب الأسنان. حاصلة على الزمالة الإيطالية المرموقة في تطبيقات الليزر في طب الأسنان. طبيبة معتمدة رسمياً من جمعية طب الأسنان الأمريكية (ADA) في تخصصي حشوات العصب وزراعة الأسنان. نلتزم بتقديم أحدث الحلول العلاجية بأعلى معايير الجودة وبدون ألم.',
    'reviews': '215',
    'gender': 'Female',
  });

  // === إضافة د. أحمد جميل (البيانات الجديدة) ===
  await DatabaseHelper().insertDoctor({
    'name': 'Dr. Ahmed Gamil',
    'arName': 'د. أحمد جميل',
    'speciality': 'Dentist & Surgeon',
    'arSpeciality': 'طبيب وجراح أسنان',
    'rating': '4.8',
    'image': 'assets/images/dr_ahmed.png',
    'introduction':
        'Dentist and Dental Surgeon. Holds postgraduate degrees in Pediatric Dentistry and Dental Implants, with extensive practical experience in major dental centers. Worked for 2 years at Shiny White Centers and 4 years at Dr. Haitham Centers, gaining wide expertise in diverse clinical cases. Owns a private clinic established 7 years ago, with a second branch in Al-Haram area. Committed to providing precise and safe medical care, prioritizing patient comfort and long-term treatment quality.',
    'arIntroduction':
        'طبيب وجراح أسنان. حاصل على دراسات عليا في طب أسنان الأطفال، ودراسات عليا في زراعة الأسنان، مع خبرة عملية ممتدة في العمل داخل كبرى مراكز طب الأسنان. عملت لمدة سنتين في مراكز شايني وايت، ولمدة أربع سنوات في مراكز د. هيثم، مما أتاح لي خبرة واسعة في التعامل مع مختلف الحالات السريرية. أمتلك عيادة خاصة منذ سبع سنوات، ولدي فرع ثانٍ للعيادة بمنطقة الهرم، وأسعى دائمًا لتقديم خدمة طبية دقيقة وآمنة.',
    'reviews': '180',
    'gender': 'Male',
  });

  // === إضافة د. يوسف طاهر محمد (البيانات الجديدة) ===
  await DatabaseHelper().insertDoctor({
    'name': 'Dr. Youssef Taher Mohamed',
    'arName': 'د. يوسف طاهر محمد',
    'speciality': 'Dentist',
    'arSpeciality': 'طبيب أسنان',
    'rating': '4.7',
    'image': 'assets/images/dr_youssef.png',
    'introduction':
        'Dedicated Dentist providing high-quality dental care with a focus on patient comfort. Experienced in routine checkups, fillings, extractions, and cosmetic dentistry. Uses modern techniques to ensure the best oral health outcomes for all ages.',
    'arIntroduction':
        'طبيب أسنان متخصص يقدم رعاية طبية عالية الجودة مع التركيز على راحة المريض. خبرة في الفحوصات الروتينية، الحشوات، الخلع، وتجميل الأسنان. يستخدم أحدث التقنيات لضمان أفضل صحة فم للكبار والأطفال.',
    'reviews': '150',
    'gender': 'Male',
  });

  // === إضافة د. أحمد خالد (البيانات الجديدة) ===
  await DatabaseHelper().insertDoctor({
    'name': 'Dr. Ahmed Khaled',
    'arName': 'د. أحمد خالد',
    'speciality': 'Orthodontist',
    'arSpeciality': 'أخصائي تقويم الأسنان',
    'rating': '4.9',
    'image': 'assets/images/dr_ahmed_khaled.png',
    'introduction':
        'Specialist in Orthodontics with an MSc from Cairo University. Member of the British Orthodontic Society (Fellowship). Former faculty member at the Faculty of Dentistry, Cairo University. Dedicated to providing top-tier orthodontic treatments.',
    'arIntroduction':
        'ماجستير تقويم الأسنان - جامعة القاهرة. حاصل على الزمالة البريطانية في تقويم الأسنان. عضو سابق في هيئة التدريس بطب الأسنان - جامعة القاهرة.',
    'reviews': '200',
    'gender': 'Male',
  });

  // === إضافة د. أدهم عز الدين (البيانات الجديدة) ===
  await DatabaseHelper().insertDoctor({
    'name': 'Dr. Adham Ezz El-Din',
    'arName': 'د. أدهم عز الدين',
    'speciality': 'Neurosurgeon & Spine Consultant',
    'arSpeciality': 'استشاري جراحة المخ والأعصاب والعمود الفقري',
    'rating': '4.9',
    'image': 'assets/images/dr_adham_ezz.png',
    'introduction':
        'Consultant of Neurosurgery and Spine Surgery. Holds a PhD in Neurosurgery from Cairo University Faculty of Medicine. Lecturer of Neurosurgery and Spine Surgery at Kasr Al Ainy and Abu El Rish Hospitals. Expert in treating complex brain and spinal conditions.',
    'arIntroduction':
        'استشاري جراحة المخ والأعصاب والعمود الفقري. حاصل على دكتوراه جراحة المخ والأعصاب من كلية الطب - جامعة القاهرة. مدرس جراحة المخ والأعصاب والعمود الفقري بمستشفيات القصر العيني وأبو الريش.',
    'reviews': '185',
    'gender': 'Male',
  });

  runApp(const DoctorApp());
}

class DoctorApp extends StatefulWidget {
  const DoctorApp({super.key});
  @override
  State<DoctorApp> createState() => _DoctorAppState();
}

class _DoctorAppState extends State<DoctorApp> {
  bool _isDark = false;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isDark = prefs.getBool('isDarkMode') ?? false;
    });
  }

  void _toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final newValue = !_isDark;
    // حفظ التفضيل أولاً قبل تحديث الحالة
    await prefs.setBool('isDarkMode', newValue);
    // الآن نحدث الحالة بعد التأكد من الحفظ
    if (mounted) {
      setState(() {
        _isDark = newValue;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Doctor App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.grey[900],
        cardColor: Colors.grey[800],
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      themeMode: _isDark ? ThemeMode.dark : ThemeMode.light,
      home: AuthCheck(toggleTheme: _toggleTheme, isDark: _isDark),
      // Handle any incoming route by showing AuthCheck, which redirects based on auth state
      onGenerateRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) =>
              AuthCheck(toggleTheme: _toggleTheme, isDark: _isDark),
        );
      },
    );
  }
}
