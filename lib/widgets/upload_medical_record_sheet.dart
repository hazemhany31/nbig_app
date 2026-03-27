import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../services/medical_records_service.dart';
import '../language_config.dart';

class UploadMedicalRecordSheet extends StatefulWidget {
  const UploadMedicalRecordSheet({super.key});

  @override
  State<UploadMedicalRecordSheet> createState() => _UploadMedicalRecordSheetState();
}

class _UploadMedicalRecordSheetState extends State<UploadMedicalRecordSheet> {
  final _nameController = TextEditingController();
  File? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileName;
  String? _fileType; // 'pdf', 'png', 'jpg'
  bool _isUploading = false;
  final _medicalRecordsService = MedicalRecordsService();

  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
        allowMultiple: false,
      );

      if (result != null) {
        final ext = result.files.single.extension?.toLowerCase() ?? 'pdf';
        setState(() {
          _selectedFileName = result.files.single.name;
          _selectedFileBytes = result.files.single.bytes;
          if (!kIsWeb && result.files.single.path != null) {
            _selectedFile = File(result.files.single.path!);
          }
          _fileType = ext;
        });
      }
    } catch (e) {
      debugPrint('Error picking document: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: source);
      if (image != null) {
        final ext = image.path.toLowerCase().endsWith('png') ? 'png' : 'jpg';
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedFileName = image.name;
          _selectedFileBytes = bytes;
          if (!kIsWeb) {
            _selectedFile = File(image.path);
          }
          _fileType = ext;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
    }
  }

  Future<void> _upload() async {
    if (_selectedFile == null && _selectedFileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'يرجى اختيار ملف أو صورة أولاً' : 'Please select a file or image first')),
      );
      return;
    }
    
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isArabic ? 'يرجى إدخال اسم للملف' : 'Please enter a name for the record')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() { _isUploading = true; });

    try {
      await _medicalRecordsService.uploadMedicalRecord(
        patientId: user.uid,
        name: name,
        type: _fileType ?? 'unknown',
        file: _selectedFile,
        bytes: _selectedFileBytes,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'تم رفع الملف بنجاح و سيظهر للطبيب!' : 'Record uploaded successfully and visible to doctors!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isUploading = false; });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(28),
          topRight: Radius.circular(28),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: isDark ? Colors.grey[600] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isArabic ? 'رفع ملف طبي' : 'Upload Medical Record',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isArabic ? 'اسم الملف' : 'Record Name',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: TextStyle(color: isDark ? Colors.white : Colors.black),
              decoration: InputDecoration(
                hintText: isArabic ? 'مثال: نتيجة تحليل دم' : 'e.g. Blood Test Results',
                hintStyle: TextStyle(color: isDark ? Colors.grey[600] : Colors.grey[400]),
                prefixIcon: const Icon(Icons.description_rounded, color: Color(0xFF8B5CF6)),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.grey[100],
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              isArabic ? 'اختر ملفاً واحداً (صورة أو PDF)' : 'Choose a file (Image or PDF)',
              style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _UploadOptionBtn(
                    icon: Icons.camera_alt_rounded,
                    label: isArabic ? 'كاميرا' : 'Camera',
                    onTap: () => _pickImage(ImageSource.camera),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _UploadOptionBtn(
                    icon: Icons.photo_library_rounded,
                    label: isArabic ? 'معرض' : 'Gallery',
                    onTap: () => _pickImage(ImageSource.gallery),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _UploadOptionBtn(
                    icon: Icons.picture_as_pdf_rounded,
                    label: 'PDF',
                    onTap: _pickDocument,
                    isDark: isDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_selectedFile != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _selectedFileName ?? '',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF10B981),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _upload,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                child: _isUploading
                    ? const SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                    : Text(isArabic ? 'رفع الملف' : 'Upload Record',
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UploadOptionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _UploadOptionBtn({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFF8B5CF6), size: 24),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
