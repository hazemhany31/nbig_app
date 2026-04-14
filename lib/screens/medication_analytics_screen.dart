import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/medication_provider.dart';
import '../services/medication_tracking_service.dart';
import '../language_config.dart';

class MedicationAnalyticsScreen extends ConsumerStatefulWidget {
  const MedicationAnalyticsScreen({super.key});

  @override
  ConsumerState<MedicationAnalyticsScreen> createState() =>
      _MedicationAnalyticsScreenState();
}

class _MedicationAnalyticsScreenState extends ConsumerState<MedicationAnalyticsScreen> {
  final MedicationTrackingService _trackingService = MedicationTrackingService();
  bool _isLoading = true;
  Map<String, dynamic>? _analyticsData;

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    final appointmentsAsync = ref.read(patientMedicationsProvider);
    if (appointmentsAsync.value != null) {
      final data = await _trackingService.calculateStreakAndAnalytics(appointmentsAsync.value!);
      if (mounted) {
        setState(() {
          _analyticsData = data;
          _isLoading = false;
        });
      }
    } else {
      // Wait for provider to load
      ref.listenManual(patientMedicationsProvider, (previous, next) async {
        if (next.hasValue && _isLoading) {
          final data = await _trackingService.calculateStreakAndAnalytics(next.value!);
          if (mounted) {
            setState(() {
              _analyticsData = data;
              _isLoading = false;
            });
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isArabic ? 'إحصائيات الأدوية' : 'Medication Analytics'),
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        elevation: 0,
        foregroundColor: isDark ? Colors.white : Colors.black,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _analyticsData == null
              ? Center(child: Text(isArabic ? 'خطأ في تحميل البيانات' : 'Error loading data'))
              : _buildContent(isDark, _analyticsData!),
    );
  }

  Widget _buildContent(bool isDark, Map<String, dynamic> data) {
    final int streak = data['streak'] ?? 0;
    final List<double> weekly = data['weekly'] as List<double>? ?? List.filled(7, 0.0);
    // Use last 7 days from monthly for a cleaner chart if monthly is not fully needed, 
    // but requirement said "weekly and monthly adherence analytics with charts".
    final List<double> monthly = data['monthly'] as List<double>? ?? List.filled(30, 0.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildStreakCard(streak, isDark),
          const SizedBox(height: 24),
          Text(
            isArabic ? 'الالتزام الأسبوعي' : 'Weekly Adherence',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildBarChart(weekly, isDark, isWeekly: true),
          const SizedBox(height: 32),
          Text(
            isArabic ? 'الالتزام الشهري' : 'Monthly Adherence',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          _buildBarChart(monthly, isDark, isWeekly: false),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildStreakCard(int streak, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFF97316), Color(0xFFEA580C)], // Orange gradient
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF97316).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'أيام متتالية' : 'Daily Streak',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  isArabic ? '$streak يوم' : '$streak Days',
                  style: const TextStyle(
                    fontSize: 32,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBarChart(List<double> data, bool isDark, {required bool isWeekly}) {
    // data is ordered from oldest to newest in calculating logic (actually it was subtracted, let's check).
    // In our logic: for i=0..6, date = now - (6-i). So i=0 is 6 days ago, i=6 is today.
    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 1.0,
          minY: 0,
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (double value, TitleMeta meta) {
                  int index = value.toInt();
                  if (isWeekly) {
                    // We just use an arbitrary cyclic day or 'D-$index'
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        (index + 1).toString(), 
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    );
                  } else {
                    // Monthly: Show only some labels
                    if (index % 5 == 0 || index == 29) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: isDark ? Colors.grey[400] : Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Text('');
                  return Text(
                    '${(value * 100).toInt()}%',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 10,
                    ),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          barGroups: data.asMap().entries.map((entry) {
            int index = entry.key;
            double pct = entry.value;
            // clamp pct between 0 and 1
            if (pct > 1) pct = 1.0;
            if (pct < 0) pct = 0.0;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: pct,
                  color: pct == 1.0 
                    ? const Color(0xFF10B981) 
                    : (pct > 0.5 ? const Color(0xFF0EA5E9) : const Color(0xFFF43F5E)),
                  width: isWeekly ? 16 : 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 1.0,
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[200],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
