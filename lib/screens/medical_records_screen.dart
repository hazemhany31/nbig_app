import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/medical_record.dart';
import '../services/medical_records_service.dart';
import '../widgets/upload_medical_record_sheet.dart';

class MedicalRecordsScreen extends StatelessWidget {
  final String? patientId;
  final bool isDoctorView;

  const MedicalRecordsScreen({
    super.key,
    this.patientId,
    this.isDoctorView = false,
  });

  Future<void> _completePendingDelete(
    BuildContext context,
    MedicalRecordsService medicalService,
    String uid,
    MedicalRecord record,
    bool isArabic,
  ) async {
    try {
      await medicalService.completePendingDelete(
        patientId: uid,
        record: record,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'تم إكمال حذف الملف بنجاح ✅' : 'Record deletion completed ✅',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isArabic ? 'الحذف لم يكتمل، حاول مرة أخرى' : 'Deletion incomplete, please try again',
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _openRecord(
    BuildContext context,
    MedicalRecordsService medicalService,
    String uid,
    MedicalRecord record,
    bool isArabic,
  ) async {
    if (record.pendingDelete) {
      await _completePendingDelete(context, medicalService, uid, record, isArabic);
      return;
    }

    if (record.url.isEmpty) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final bytes = await medicalService.downloadMedicalRecordBytes(url: record.url);
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      if (!context.mounted) return;

      final ext = record.type.toLowerCase();
      if (['jpg', 'jpeg', 'png', 'webp'].contains(ext)) {
        await showDialog(
          context: context,
          builder: (ctx) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(12),
            child: Stack(
              children: [
                InteractiveViewer(
                  child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ],
            ),
          ),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = record.name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final file = File('${tempDir.path}/$safeName.$ext');
      await file.writeAsBytes(bytes, flush: true);

      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'لا يوجد تطبيق لفتح هذا الملف' : 'No app available to open this file'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } on MedicalRecordDownloadException catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isArabic ? 'فشل فتح الملف: $e' : 'Failed to open file: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = patientId ?? FirebaseAuth.instance.currentUser?.uid;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == TextDirection.rtl;
    final medicalService = MedicalRecordsService();

    if (uid == null || uid.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isArabic ? 'الملفات الطبية' : 'Medical Records'),
          centerTitle: true,
        ),
        body: Center(
          child: Text(isArabic ? 'غير مسجل دخول' : 'Not logged in'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isArabic ? 'الملفات الطبية' : 'Medical Records',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: !isDoctorView
          ? FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const UploadMedicalRecordSheet(),
                );
              },
              backgroundColor: const Color(0xFF8B5CF6),
              icon: const Icon(Icons.upload_file_rounded, color: Colors.white),
              label: Text(
                isArabic ? 'رفع ملف جديد' : 'Upload Record',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            )
          : null,
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('medical_records')
            .orderBy('date', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                isArabic ? 'خطأ في تحميل الملفات' : 'Error loading records',
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF8B5CF6)));
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 80,
                    color: isDark ? Colors.white24 : Colors.black12,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    isArabic ? 'لا توجد ملفات طبية مرفوعة' : 'No medical records uploaded yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final record = MedicalRecord.fromFirestore(doc);

              return MedicalRecordListItem(
                record: record,
                isDark: isDark,
                isArabic: isArabic,
                onOpen: () => _openRecord(context, medicalService, uid, record, isArabic),
                onCompletePendingDelete: () =>
                    _completePendingDelete(context, medicalService, uid, record, isArabic),
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(isArabic ? 'حذف الملف' : 'Delete Record'),
                      content: Text(
                        isArabic
                            ? 'هل أنت تأكد من حذف هذا الملف النهائياً من السحابة؟'
                            : 'Are you sure you want to delete this record permanently?',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Text(
                            isArabic ? 'حذف' : 'Delete',
                            style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      await medicalService.deleteMedicalRecord(
                        patientId: uid,
                        recordId: record.id,
                        fileUrl: record.url,
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic ? 'تم حذف الملف بنجاح ✅' : 'Record deleted successfully ✅',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isArabic ? 'فشل حذف الملف: $e' : 'Failed to delete record: $e',
                            ),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class MedicalRecordListItem extends StatelessWidget {
  final MedicalRecord record;
  final bool isDark;
  final bool isArabic;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  final VoidCallback onCompletePendingDelete;

  const MedicalRecordListItem({
    super.key,
    required this.record,
    required this.isDark,
    required this.isArabic,
    required this.onOpen,
    required this.onDelete,
    required this.onCompletePendingDelete,
  });

  @override
  Widget build(BuildContext context) {
    IconData iconData = Icons.insert_drive_file_rounded;
    Color iconColor = const Color(0xFF3B82F6);
    final type = record.type.toLowerCase();

    if (type == 'pdf') {
      iconData = Icons.picture_as_pdf_rounded;
      iconColor = const Color(0xFFEF4444);
    } else if (type == 'png' || type == 'jpg' || type == 'jpeg') {
      iconData = Icons.image_rounded;
      iconColor = const Color(0xFF10B981);
    } else if (type == 'doc' || type == 'docx') {
      iconData = Icons.description_rounded;
      iconColor = const Color(0xFF3B82F6);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: record.pendingDelete
              ? Colors.orange.withValues(alpha: 0.6)
              : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: record.pendingDelete ? onCompletePendingDelete : onOpen,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: (record.pendingDelete ? Colors.orange : iconColor).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            record.pendingDelete ? Icons.warning_amber_rounded : iconData,
            color: record.pendingDelete ? Colors.orange : iconColor,
            size: 28,
          ),
        ),
        title: Text(
          record.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white : const Color(0xFF0F172A),
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${record.type.toUpperCase()} • ${record.date.day}/${record.date.month}/${record.date.year}',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            if (record.pendingDelete) ...[
              const SizedBox(height: 4),
              Text(
                isArabic ? 'الحذف لم يكتمل' : 'Deletion incomplete',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.orange,
                ),
              ),
            ],
          ],
        ),
        trailing: record.pendingDelete
            ? IconButton(
                icon: const Icon(Icons.delete_forever_rounded, color: Colors.orange),
                tooltip: isArabic ? 'إكمال الحذف' : 'Complete deletion',
                onPressed: onCompletePendingDelete,
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF8B5CF6)),
                    tooltip: isArabic ? 'عرض' : 'Open',
                    onPressed: onOpen,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: isArabic ? 'حذف' : 'Delete',
                    onPressed: onDelete,
                  ),
                ],
              ),
      ),
    );
  }
}
