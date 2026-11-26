import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../widgets/neutral_avatar.dart';
import '../../services/appointment_service.dart';
import '../../models/appointment_model.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;

class DoctorAppointmentsScreen extends StatefulWidget {
  const DoctorAppointmentsScreen({super.key});

  @override
  State<DoctorAppointmentsScreen> createState() => _DoctorAppointmentsScreenState();
}

class _DoctorAppointmentsScreenState extends State<DoctorAppointmentsScreen> {
  final AppointmentService _appointmentService = AppointmentService();
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
    final String? doctorUserId = FirebaseAuth.instance.currentUser?.uid;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final isArabic = Directionality.of(context) == ui.TextDirection.rtl;

    if (doctorUserId == null) {
      return const Center(child: Text('Please login to view appointments'));
    }

    return Column(
      children: [
        // Tabs
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(isArabic ? 'الكل' : 'All', 0),
                  _buildTab(isArabic ? 'قيد الانتظار' : 'Pending', 1),
                  _buildTab(isArabic ? 'مؤكدة' : 'Confirmed', 2),
                  _buildTab(isArabic ? 'مكتملة' : 'Completed', 3),
                  _buildTab(isArabic ? 'ملغاة' : 'Cancelled', 4),
                  _buildTab(isArabic ? 'مرفوضة' : 'Rejected', 5),
                  _buildTab(isArabic ? 'منتهية' : 'Expired', 6),
                  _buildTab(isArabic ? 'معاد جدولتها' : 'Rescheduled', 7),
                ],
              ),
            ),
          ),
        ),
        
        Expanded(
          child: StreamBuilder<List<Appointment>>(
            stream: _appointmentService.getDoctorAppointments(doctorUserId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error: ${snapshot.error}'));
              }
              
              final appointments = snapshot.data ?? [];
              final filteredAppointments = appointments.where((a) {
                if (_tabIndex == 0) return true; // All
                if (_tabIndex == 1) return a.status == 'pending';
                if (_tabIndex == 2) return a.status == 'accepted' || a.status == 'confirmed';
                if (_tabIndex == 3) return a.status == 'completed';
                if (_tabIndex == 4) return a.status == 'cancelled';
                if (_tabIndex == 5) return a.status == 'rejected';
                if (_tabIndex == 6) return a.status == 'expired';
                if (_tabIndex == 7) return a.status == 'rescheduled';
                return false;
              }).toList();

              if (filteredAppointments.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        isArabic ? 'لا توجد مواعيد' : 'No appointments yet',
                        style: TextStyle(color: Colors.grey[600], fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredAppointments.length,
                itemBuilder: (context, index) {
                  return _buildAppointmentCard(filteredAppointments[index], isDark, isArabic);
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String title, int index) {
    bool isActive = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.grey[600],
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentCard(Appointment appointment, bool isDark, bool isArabic) {
    final accentColor = _getStatusColor(appointment.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
        border: Border(left: BorderSide(color: accentColor, width: 4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeutralAvatar(
                  photoUrl: appointment.patientPhotoUrl,
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.patientName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        appointment.type.toUpperCase(),
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                _getStatusBadge(appointment.status, isArabic),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                _buildInfoIcon(Icons.calendar_today, DateFormat('MMM d, yyyy').format(appointment.dateTime)),
                const SizedBox(width: 16),
                _buildInfoIcon(Icons.access_time, appointment.formattedTime),
              ],
            ),
            
            if (appointment.status == 'pending') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _appointmentService.acceptAppointment(appointment.id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isArabic ? 'قبول' : 'Accept'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _appointmentService.rejectAppointment(appointment.id),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.red[400]!),
                        foregroundColor: Colors.red[400],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(isArabic ? 'إلغاء' : 'Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoIcon(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
      ],
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'pending': return Colors.amber;
      case 'accepted':
      case 'confirmed': return Colors.green;
      case 'completed': return Colors.blue;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Widget _getStatusBadge(String status, bool isArabic) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        _getStatusText(status, isArabic),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _getStatusText(String status, bool isArabic) {
    switch (status) {
      case 'pending': return isArabic ? 'قيد الانتظار' : 'PENDING';
      case 'accepted':
      case 'confirmed': return isArabic ? 'مؤكد' : 'CONFIRMED';
      case 'completed': return isArabic ? 'مكتمل' : 'COMPLETED';
      case 'cancelled': return isArabic ? 'ملغي' : 'CANCELLED';
      default: return status.toUpperCase();
    }
  }
}
