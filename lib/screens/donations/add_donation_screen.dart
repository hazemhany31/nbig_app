import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/donation_service.dart';
import '../../language_config.dart';

class AddDonationScreen extends StatefulWidget {
  const AddDonationScreen({super.key});

  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _phoneController = TextEditingController();
  final _locationController = TextEditingController();
  
  DateTime? _expiryDate;
  File? _imageFile;
  bool _isLoading = false;

  final DonationService _donationService = DonationService();
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 30)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 3650)), // 10 years
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF10B981),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _expiryDate) {
      setState(() {
        _expiryDate = picked;
      });
    }
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate() || _imageFile == null || _expiryDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isArabic ? 'يرجى ملء جميع الحقول واختيار صوره' : 'Please fill all fields and pick an image'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // 1. Get user data for donor info
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final donorName = userDoc.data()?['name'] ?? 'User';
      final userType = userDoc.data()?['role'] ?? 'patient';

      // 2. Upload Image
      final imageUrl = await _donationService.uploadDonationImage(_imageFile!);

      // 3. Create Donation
      await _donationService.createDonation(
        medicineName: _nameController.text.trim(),
        imageUrl: imageUrl,
        quantity: int.tryParse(_quantityController.text) ?? 1,
        expiryDate: _expiryDate!,
        phone: _phoneController.text.trim(),
        location: _locationController.text.trim(),
        donorName: donorName,
        userType: userType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تمت إضافة التبرع بنجاح!' : 'Donation added successfully!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isArabic ? 'إضافة تبرع جديد' : 'Add New Donation', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Picker Card
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      builder: (context) => SafeArea(
                        child: Wrap(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.camera_alt_rounded),
                              title: Text(isArabic ? 'الكاميرا' : 'Camera'),
                              onTap: () {
                                _pickImage(ImageSource.camera);
                                Navigator.pop(context);
                              },
                            ),
                            ListTile(
                              leading: const Icon(Icons.photo_library_rounded),
                              title: Text(isArabic ? 'المعرض' : 'Gallery'),
                              onTap: () {
                                _pickImage(ImageSource.gallery);
                                Navigator.pop(context);
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                      image: _imageFile != null
                          ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                          : null,
                    ),
                    child: _imageFile == null
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.add_a_photo_rounded, size: 50, color: Color(0xFF10B981)),
                              const SizedBox(height: 10),
                              Text(isArabic ? 'أضف صورة الدواء' : 'Add Medicine Photo', style: const TextStyle(color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                            ],
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 24),

                // Name Field
                _buildFieldTitle(isArabic ? 'اسم الدواء' : 'Medicine Name'),
                TextFormField(
                  controller: _nameController,
                  decoration: _inputDecoration(isArabic ? 'مثلاً: بانادول 500 ملجم' : 'Example: Panadol 500mg', Icons.medication_rounded, isDark),
                  validator: (v) => v!.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                ),
                const SizedBox(height: 16),

                // Quantity Field
                _buildFieldTitle(isArabic ? 'الكمية' : 'Quantity'),
                TextFormField(
                  controller: _quantityController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(isArabic ? 'العدد' : 'Number', Icons.numbers_rounded, isDark),
                  validator: (v) => v!.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                ),
                const SizedBox(height: 16),

                // Phone Field
                _buildFieldTitle(isArabic ? 'رقم التواصل' : 'Contact Phone'),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: _inputDecoration(isArabic ? 'رقم الهاتف' : 'Phone Number', Icons.phone_rounded, isDark),
                  validator: (v) => v!.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                ),
                const SizedBox(height: 16),

                // Location Field
                _buildFieldTitle(isArabic ? 'الموقع' : 'Location'),
                TextFormField(
                  controller: _locationController,
                  decoration: _inputDecoration(isArabic ? 'مثل: القاهرة، مدينة نصر' : 'Example: Cairo, Nasr City', Icons.location_on_rounded, isDark),
                  validator: (v) => v!.isEmpty ? (isArabic ? 'مطلوب' : 'Required') : null,
                ),
                const SizedBox(height: 16),

                // Expiry Date Picker
                _buildFieldTitle(isArabic ? 'تاريخ الانتهاء' : 'Expiry Date'),
                GestureDetector(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, color: Color(0xFF10B981)),
                        const SizedBox(width: 12),
                        Text(
                          _expiryDate == null
                              ? (isArabic ? 'اختر التاريخ' : 'Select Date')
                              : DateFormat('yyyy-MM-dd').format(_expiryDate!),
                          style: TextStyle(
                            color: _expiryDate == null ? Colors.grey : (isDark ? Colors.white : Colors.black),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            isArabic ? 'مشاركة التبرع' : 'Share Donation',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4, right: 4),
      child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF64748B))),
    );
  }

  InputDecoration _inputDecoration(String hint, IconData icon, bool isDark) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF10B981)),
      filled: true,
      fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: Color(0xFF10B981), width: 2),
      ),
    );
  }
}
