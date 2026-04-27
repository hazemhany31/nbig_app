import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/donation_model.dart';
import '../../services/donation_service.dart';
import '../../services/chat_service.dart';
import '../chat/chat_screen.dart';
import '../../models/chat.dart';
import 'add_donation_screen.dart';
import '../../language_config.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class DonationFeedScreen extends StatefulWidget {
  const DonationFeedScreen({super.key});

  @override
  State<DonationFeedScreen> createState() => _DonationFeedScreenState();
}

class _DonationFeedScreenState extends State<DonationFeedScreen> {
  final DonationService _donationService = DonationService();
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isVerifiedDoctor = false;

  @override
  void initState() {
    super.initState();
    _checkDoctorStatus();
  }

  Future<void> _checkDoctorStatus() async {
    final status = await _donationService.isCurrentDoctorVerified();
    if (mounted) {
      setState(() => _isVerifiedDoctor = status);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isArabic ? 'سوق الخير - التبرعات' : 'Donation Feed', style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF10B981)),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AddDonationScreen())),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
              decoration: InputDecoration(
                hintText: isArabic ? 'ابحث عن دواء...' : 'Search for medicine...',
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF10B981)),
                filled: true,
                fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
            ),
          ),

          // Feed List
          Expanded(
            child: StreamBuilder<List<Donation>>(
              stream: _donationService.getActiveDonations(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final donations = snapshot.data ?? [];
                final filteredDonations = donations.where((d) => 
                  d.medicineName.toLowerCase().contains(_searchQuery)
                ).toList();

                if (filteredDonations.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.medical_services_outlined, size: 60, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(isArabic ? 'لا توجد تبرعات متاحة حالياً' : 'No donations available yet', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredDonations.length,
                  itemBuilder: (context, index) {
                    final donation = filteredDonations[index];
                    return _DonationCard(
                      donation: donation,
                      isMine: donation.userId == user?.uid,
                      isVerifiedDoctor: _isVerifiedDoctor,
                      onChatTap: () => _handleChat(donation),
                      onDeleteTap: () => _donationService.deleteDonation(donation.id),
                      onRecommendTap: () => _donationService.toggleRecommendation(donation.id, !donation.isRecommended),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChat(Donation donation) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (user.uid == donation.userId) return;

    try {
      // Show loading
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: CircularProgressIndicator()));

      // 1. Get current user data
      final myDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final myName = myDoc.data()?['name'] ?? 'User';

      // 2. We treat the donor as the "doctor" in the chat system for simplicity (peer-to-peer)
      final chatId = await _chatService.createOrGetChat(
        doctorId: donation.userId, 
        doctorUserId: donation.userId,
        doctorName: donation.donorName,
        patientId: user.uid,
        patientName: myName,
      );

      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      final chat = Chat.fromFirestore(chatDoc);

      if (mounted) {
        Navigator.pop(context); // Close loading
        Navigator.push(context, MaterialPageRoute(builder: (context) => ChatScreen(chat: chat)));
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Chat Error: $e')));
      }
    }
  }
}

class _DonationCard extends StatelessWidget {
  final Donation donation;
  final bool isMine;
  final bool isVerifiedDoctor;
  final VoidCallback onChatTap;
  final VoidCallback onDeleteTap;
  final VoidCallback onRecommendTap;

  const _DonationCard({
    required this.donation,
    required this.isMine,
    required this.isVerifiedDoctor,
    required this.onChatTap,
    required this.onDeleteTap,
    required this.onRecommendTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final daysToExpiry = donation.expiryDate.difference(DateTime.now()).inDays;
    final isUrgent = daysToExpiry < 30;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image with Badges
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                child: CachedNetworkImage(
                  imageUrl: donation.imageUrl,
                  height: 180,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(color: Colors.grey[200]),
                  errorWidget: (context, url, error) => const Icon(Icons.error),
                ),
              ),
              if (donation.isRecommended)
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B82F6),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.verified_rounded, color: Colors.white, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          isArabic ? 'موثق طبياً' : 'Doctor Recommended',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${isArabic ? 'الكمية:' : 'Qty:'} ${donation.quantity}',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        donation.medicineName,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A)),
                      ),
                    ),
                    if (isUrgent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(isArabic ? 'تنتهي قريباً' : 'Expiring Soon', style: const TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(donation.location, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    const SizedBox(width: 16),
                    const Icon(Icons.event_note_rounded, size: 14, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(
                      '${isArabic ? 'تنتهي:' : 'Exp:'} ${DateFormat('MMM yyyy').format(donation.expiryDate)}',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  children: [
                    CircleAvatar(radius: 14, backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1), child: const Icon(Icons.person_rounded, size: 16, color: Color(0xFF10B981))),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(donation.donorName, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF0F172A))),
                          Text(donation.userType == 'doctor' ? (isArabic ? 'طبيب موثق' : 'Verified Doctor') : (isArabic ? 'مريض' : 'Patient'), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                    ),
                    if (isVerifiedDoctor)
                      IconButton(
                        onPressed: onRecommendTap,
                        icon: Icon(
                          donation.isRecommended ? Icons.verified_rounded : Icons.verified_outlined,
                          color: donation.isRecommended ? const Color(0xFF3B82F6) : Colors.grey,
                        ),
                        tooltip: isArabic ? 'توصية الطبيب' : 'Doctor Recommendation',
                      ),
                    if (isMine)
                      IconButton(onPressed: onDeleteTap, icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent))
                    else
                      ElevatedButton.icon(
                        onPressed: onChatTap,
                        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                        label: Text(isArabic ? 'أنا أحتاج هذا' : 'I Need This'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
