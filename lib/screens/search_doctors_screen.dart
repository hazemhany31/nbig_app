import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui' as ui;
import '../models/doctor_model.dart';
import 'dart:async';
import 'sub_screens.dart';

class SearchDoctorsScreen extends StatefulWidget {
  const SearchDoctorsScreen({super.key});

  @override
  State<SearchDoctorsScreen> createState() => _SearchDoctorsScreenState();
}

class _SearchDoctorsScreenState extends State<SearchDoctorsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  
  List<Doctor> _results = [];
  bool _isLoading = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) setState(() { _results = []; _isLoading = false; });
      return;
    }

    if (mounted) setState(() => _isLoading = true);

    try {
      final String searchLower = query.trim().toLowerCase();
      // Fetch all to filter locally for better text matching
      final snapshot = await FirebaseFirestore.instance.collection('doctors').get();
      final List<Doctor> allDocs = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Doctor.fromMap(data);
      }).toList();

      final filtered = allDocs.where((doc) {
        final matchesName = doc.name.toLowerCase().contains(searchLower);
        final matchesSpec = doc.specialty.toLowerCase().contains(searchLower);
        return matchesName || matchesSpec;
      }).toList();

      if (mounted) {
        setState(() {
          _results = filtered;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: isDark ? Colors.white : Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Hero(
          tag: 'search_bar',
          child: Material(
            color: Colors.transparent,
            child: TextField(
              controller: _searchController,
              focusNode: _focusNode,
              onChanged: _onSearchChanged,
              style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 16),
              decoration: InputDecoration(
                hintText: 'ابحث عن طبيب أو تخصص...', // "Search doctor or specialty..."
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
              ),
              textDirection: ui.TextDirection.rtl, // Fixed prefix
            ),
          ),
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: Icon(Icons.clear_rounded, color: Colors.grey[400]),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0EA5E9)),
      );
    }

    if (_searchController.text.trim().isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'ابحث عن أطباء أو تخصصات', // "Search docs or specialties"
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off_rounded, size: 80, color: Colors.grey.withValues(alpha: 0.3)),
            const SizedBox(height: 16),
            Text(
              'لم نتمكن من العثور على نتائج', // "Couldn't find results"
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final doc = _results[index];
        return _buildDoctorCard(doc, isDark);
      },
    );
  }

  Widget _buildDoctorCard(Doctor doc, bool isDark) {
    // A simplified elegant card for search results
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorDetailsScreen(doctor: doc.toMap()),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFF0EA5E9).withValues(alpha: 0.1),
              backgroundImage: (doc.image.isNotEmpty)
                  ? NetworkImage(doc.image)
                  : null,
              child: (doc.image.isEmpty)
                  ? const Icon(Icons.person_rounded, color: Color(0xFF0EA5E9), size: 30)
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doc.specialty,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF0EA5E9),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
