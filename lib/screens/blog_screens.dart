import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../language_config.dart';

class BlogPost {
  final String id;
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String subtitleAr;
  final String contentEn;
  final String contentAr;
  final String image;
  final String date;
  final String categoryEn;
  final String categoryAr;

  BlogPost({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.subtitleAr,
    required this.contentEn,
    required this.contentAr,
    required this.image,
    required this.date,
    required this.categoryEn,
    required this.categoryAr,
  });
}

final List<BlogPost> blogPosts = [
  BlogPost(
    id: '1',
    titleEn: 'STAY FLU-FREE THIS SEASON',
    titleAr: 'حافظ على صحتك في الشتاء',
    subtitleEn: 'Essential tips to avoid influenza and stay strong.',
    subtitleAr: 'نصائح هامة لتجنب الانفلونزا والحفاظ على قوتك.',
    categoryEn: 'Wellness',
    categoryAr: 'صحة عامة',
    date: 'Oct 12, 2023',
    image: 'https://images.unsplash.com/photo-1505751172876-fa1923c5c528?auto=format&fit=crop&w=800&q=80',
    contentEn: '''Influenza, commonly known as the flu, is a highly contagious respiratory illness caused by influenza viruses. It can cause mild to severe illness, and at times can lead to death.

Key tips for prevention:
1. Get Vaccinated: The yearly flu vaccine is the best way to protect yourself and others.
2. Wash Your Hands: Frequent handwashing with soap and water helps remove germs.
3. Boost Your Immunity: Eat a balanced diet rich in vitamins, stay hydrated, and get enough sleep.
4. Keep Your Distance: Avoid close contact with people who are sick.
''',
    contentAr: '''الأنفلونزا، والمعروفة باسم "البرد"، هي مرض تنفسي شديد العدوى تسببه فيروسات الأنفلونزا. يمكن أن يسبب مرضاً خفيفاً إلى شديداً، وقد يؤدي أحياناً إلى الوفاة.

نصائح أساسية للوقاية:
1. احصل على التطعيم: لقاح الأنفلونزا السنوي هو أفضل وسيلة لحماية نفسك والآخرين.
2. اغسل يديك دائماً: يساعد غسل اليدين المتكرر بالماء والصابون على إزالة الجراثيم.
3. عزز مناعتك: تناول نظاماً غذائياً متوازناً غنياً بالفيتامينات، وحافظ على شرب السوائل، واحصل على قسط كافٍ من النوم.
4. حافظ على مسافة آمنة: تجنب الاتصال الوثيق مع الأشخاص المرضى.
''',
  ),
  BlogPost(
    id: '2',
    titleEn: 'PREPARATION FOR CHEMOTHERAPY',
    titleAr: 'الاستعداد للعلاج الكيميائي',
    subtitleEn: 'Everything you need to know about the treatment process.',
    subtitleAr: 'كل ما تحتاج معرفته عن عملية العلاج والخطوات القادمة.',
    categoryEn: 'Medical Guide',
    categoryAr: 'دليل طبي',
    date: 'Oct 15, 2023',
    image: 'https://images.unsplash.com/photo-1576091160550-2173dba999ef?auto=format&fit=crop&w=800&q=80',
    contentEn: '''Chemotherapy affects everyone differently, but knowing what to expect can help you feel more prepared and in control.

Before Treatment:
- Financial Planning: Talk to your insurance provider and hospital about costs.
- Home Prep: Stock up on easy-to-digest foods and arrange for help with household chores.
- Medical Tests: Your doctor will run blood tests and scans to ensure you're ready.

During Treatment:
- Hydration is key. Drink plenty of water.
- Report side effects immediately to your medical team.
''',
    contentAr: '''يؤثر العلاج الكيميائي على كل شخص بشكل مختلف، لكن معرفة ما يمكن توقعه يمكن أن يساعدك على الشعور بمزيد من الاستعداد والسيطرة.

قبل العلاج:
- التخطيط المالي: تحدث مع شركة التأمين والمستشفى حول التكاليف.
- تجهيز المنزل: قم بتخزين الأطعمة سهلة الهضم ورتب للحصول على مساعدة في الأعمال المنزلية.
- الفحوصات الطبية: سيقوم طبيبك بإجراء فحوصات الدم والأشعة للتأكد من استعدادك.

أثناء العلاج:
- الترطيب هو المفتاح. اشرب الكثير من الماء.
- أبلغ عن الآثار الجانبية فوراً لفريقك الطبي.
''',
  ),
  BlogPost(
    id: '3',
    titleEn: 'MENTAL HEALTH & MEDITATION',
    titleAr: 'الصحة النفسية والتأمل',
    subtitleEn: 'Discover the power of mindfulness in your daily life.',
    subtitleAr: 'اكتشف قوة اليقظة الذهنية وتأثيرها في حياتك اليومية.',
    categoryEn: 'Mental Health',
    categoryAr: 'الصحة النفسية',
    date: 'Oct 20, 2023',
    image: 'https://images.unsplash.com/photo-1506126613408-eca07ce68773?auto=format&fit=crop&w=800&q=80',
    contentEn: '''In today's fast-paced world, taking care of your mental health is as important as physical health. Meditation can be a powerful tool to reduce stress and improve focus.

Simple Meditation Steps:
1. Find a Quiet Space: Somewhere you won't be disturbed.
2. Focus on Your Breath: Notice the air entering and leaving your body.
3. Observe thoughts without judgment: Let them pass like clouds in the sky.
4. Practice daily: Even 5-10 minutes can make a significant difference.
''',
    contentAr: '''في عالم اليوم المتسارع، العناية بصحتك النفسية لا تقل أهمية عن الصحة الجسدية. يمكن أن يكون التأمل أداة قوية لتقليل التوتر وتحسين التركيز.

خطوات بسيطة للتأمل:
1. ابحث عن مكان هادئ: حيث لن يزعجك أحد.
2. ركز على أنفاسك: لاحظ دخول الهواء وخروجه من جسدك.
3. راقب أفكارك دون حكم: اتركها تمر مثل السحب في السماء.
4. مارسها يومياً: حتى 5-10 دقائق يمكن أن تحدث فرقاً كبيراً.
''',
  ),
];

class BlogListScreen extends StatelessWidget {
  const BlogListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isArabic ? 'المدونة الطبية' : 'Medical Blog'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: blogPosts.length,
        itemBuilder: (context, index) {
          final post = blogPosts[index];
          return _buildBlogCard(context, post, isDark);
        },
      ),
    );
  }

  Widget _buildBlogCard(BuildContext context, BlogPost post, bool isDark) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => BlogDetailScreen(post: post)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              child: CachedNetworkImage(
                imageUrl: post.image,
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isArabic ? post.categoryAr : post.categoryEn,
                          style: const TextStyle(color: Colors.blue, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        post.date,
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isArabic ? post.titleAr : post.titleEn,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isArabic ? post.subtitleAr : post.subtitleEn,
                    style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BlogDetailScreen extends StatelessWidget {
  final BlogPost post;
  const BlogDetailScreen({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: CachedNetworkImage(
                imageUrl: post.image,
                fit: BoxFit.cover,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isArabic ? post.categoryAr : post.categoryEn,
                      style: const TextStyle(color: Colors.blue, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? post.titleAr : post.titleEn,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, height: 1.2),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: Colors.grey),
                      const SizedBox(width: 8),
                      Text(post.date, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Divider(),
                  ),
                  Text(
                    isArabic ? post.contentAr : post.contentEn,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.8,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
