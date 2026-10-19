import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/models/survey.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// theme
abstract class _SurveyTheme {
  static const Color primary = Color(0xFF7A1025);
  static const Color primaryLight = Color(0xFFF8E9EC);
  static const Color background = Color(0xFFFCF8F9);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color error = Color(0xFFE53935);
  static const Color errorBg = Color(0xFFFFEBEE);
  static const Color success = Color(0xFF16A34A);

  static const double mobileBreakpoint = 600;
  static const double desktopBreakpoint = 1024;
  static const double maxContentWidth = 1150;
  static const double cardRadius = 16;
  static const double badgeRadius = 8;

  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 20);
    }
    if (screenWidth >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 16);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  }
}

class SurveyPage extends StatefulWidget {
  const SurveyPage({super.key});

  @override
  State<SurveyPage> createState() => _SurveyPageState();
}

class _SurveyPageState extends State<SurveyPage> {
  // api
  static const String _surveyEndpoint = 'https://sijala.biz.id/api/v1/surveys';

  // state
  List<Survey> _surveys = [];
  bool _isLoading = true;
  bool _isFetching = false;
  String? _errorMessage;

  // init
  @override
  void initState() {
    super.initState();
    _fetchSurveys();
  }

  // fetch surveys
  Future<void> _fetchSurveys({bool isRefresh = false}) async {
    if (_isFetching) return;

    _isFetching = true;

    if (!isRefresh && mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      final response = await http.get(
        Uri.parse(_surveyEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 401) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      if (response.statusCode == 403) {
        throw Exception(
          'Akses ditolak. Anda tidak memiliki izin untuk melihat daftar survey.',
        );
      }

      if (response.statusCode == 404) {
        throw Exception('Layanan daftar survey tidak ditemukan (404).');
      }

      if (response.statusCode == 422) {
        throw Exception('Permintaan daftar survey tidak valid (422).');
      }

      if (response.statusCode >= 500) {
        throw Exception('Terjadi masalah pada server. Silakan coba lagi nanti.');
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map<String, dynamic> && decoded['status'] == true) {
          final dynamic dataList = decoded['data'];
          final List<Survey> loadedSurveys = [];

          if (dataList is List) {
            for (final item in dataList) {
              if (item is Map<String, dynamic>) {
                loadedSurveys.add(Survey.fromJson(item));
              }
            }
          }

          if (!mounted) return;

          setState(() {
            _surveys = loadedSurveys;
            _isLoading = false;
            _errorMessage = null;
          });

          return;
        } else {
          final String message =
              decoded is Map<String, dynamic> && decoded['message'] != null
                  ? decoded['message'].toString()
                  : 'Gagal memuat daftar survey.';
          throw Exception(message);
        }
      }

      throw Exception('Gagal memuat survey (Kode: ${response.statusCode}).');
    } on TimeoutException {
      if (!mounted) return;
      _handleFetchError('Koneksi waktu habis. Silakan coba lagi.', isRefresh: isRefresh);
    } on FormatException {
      if (!mounted) return;
      _handleFetchError('Format data dari server tidak valid.', isRefresh: isRefresh);
    } catch (e) {
      if (!mounted) return;

      final rawMessage = e.toString().replaceFirst('Exception: ', '');
      final lower = rawMessage.toLowerCase();

      String userMessage = rawMessage;

      if (lower.contains('socket') ||
          lower.contains('failed to connect') ||
          lower.contains('clientexception') ||
          lower.contains('network') ||
          lower.contains('xmlhttprequest') ||
          lower.contains('connection failed')) {
        userMessage = 'Tidak dapat terhubung ke server. Periksa koneksi internet Anda.';
      }

      _handleFetchError(userMessage, isRefresh: isRefresh);
    } finally {
      _isFetching = false;

      if (mounted && _isLoading) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // unauthorized
  Future<void> _handleUnauthorized(SharedPreferences prefs) async {
    await prefs.remove('token');
    await prefs.remove('user');

    if (!mounted) return;

    _showModernSnackBar(
      message: 'Sesi telah berakhir. Silakan login kembali.',
      isSuccess: false,
    );

    context.go(AppRoutes.login);
  }

  // fetch error
  void _handleFetchError(String message, {required bool isRefresh}) {
    if (!mounted) return;

    setState(() {
      _isLoading = false;
      if (!isRefresh || _surveys.isEmpty) {
        _errorMessage = message;
      }
    });

    if (isRefresh) {
      _showModernSnackBar(message: message, isSuccess: false);
    }
  }

  // tap card
  Future<void> _handleCardTap(Survey survey) async {
    final result = await context.push(
      AppRoutes.surveyDetail,
      extra: survey.id,
    );

    if (result == true && mounted) {
      await _fetchSurveys();
    }
  }

  // tambah survey
  Future<void> _handleAddSurvey() async {
    final result = await context.push(AppRoutes.addSurvey);

    if (result == true && mounted) {
      await _fetchSurveys();
    }
  }

  // snackbar
  void _showModernSnackBar({
    required String message,
    required bool isSuccess,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? _SurveyTheme.success : _SurveyTheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // build
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pagePadding = _SurveyTheme.getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor: _SurveyTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: _SurveyTheme.primary,
                backgroundColor: _SurveyTheme.surface,
                onRefresh: () => _fetchSurveys(isRefresh: true),
                child: _buildBodyContent(
                  screenWidth: screenWidth,
                  padding: pagePadding,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  // header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: const BoxDecoration(
        color: _SurveyTheme.surface,
        border: Border(
          bottom: BorderSide(color: _SurveyTheme.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: _SurveyTheme.primaryLight,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.assignment_outlined,
              color: _SurveyTheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Daftar hasil survei',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w400,
                  color: _SurveyTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // body
  Widget _buildBodyContent({
    required double screenWidth,
    required EdgeInsets padding,
  }) {
    if (_isLoading) return _buildLoadingState();

    if (_errorMessage != null && _surveys.isEmpty) return _buildErrorState();

    if (_surveys.isEmpty) return _buildEmptyState();

    return _buildResponsiveSurveyList(
      screenWidth:screenWidth,
      padding:padding);
  }

  // responsive list
  Widget _buildResponsiveSurveyList({
    required double screenWidth,
    required EdgeInsets padding,
  }) {
    final contentPadding = padding.copyWith(bottom: padding.bottom + 90 ,left: 16, right: 16);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth;

        // desktop
        if (screenWidth >= _SurveyTheme.desktopBreakpoint || availableWidth >= 900) {
          if (_surveys.length == 1) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: contentPadding,
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: _buildSurveyCard(_surveys.first),
                  ),
                ),
              ],
            );
          }

          final columns = availableWidth >= 1000 ? 3 : 2;

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: contentPadding,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 1,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
              mainAxisExtent: 205,
            ),
            itemCount: _surveys.length,
            itemBuilder: (context, index) {
              return _buildSurveyCard(_surveys[index]);
            },
          );
        }

        // tablet
        if (screenWidth >= _SurveyTheme.mobileBreakpoint || availableWidth >= 600) {
          if (_surveys.length == 1) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: contentPadding,
              children: [
                   _buildSurveyCard(_surveys.first),
              ],
            );
          }

          return GridView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: contentPadding,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 205,
            ),
            itemCount: _surveys.length,
            itemBuilder: (context, index) {
              return _buildSurveyCard(_surveys[index]);
            },
          );
        }

        // mobile
        return ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: contentPadding,
          itemCount: _surveys.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _buildSurveyCard(_surveys[index]);
          },
        );
      },
    );
  }

  // survey card
  Widget _buildSurveyCard(Survey survey) {
    return Container(
      decoration: BoxDecoration(
        color: _SurveyTheme.surface,
        borderRadius: BorderRadius.circular(_SurveyTheme.cardRadius),
        border: Border.all(color: _SurveyTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(_SurveyTheme.cardRadius),
          onTap: () => _handleCardTap(survey),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // top
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: _SurveyTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.assignment_outlined,
                        size: 19,
                        color: _SurveyTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            survey.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
                              color: _SurveyTheme.textPrimary,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _SurveyTheme.primaryLight,
                              borderRadius: BorderRadius.circular(
                                _SurveyTheme.badgeRadius,
                              ),
                            ),
                            child: Text(
                              survey.categoryName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: _SurveyTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: _SurveyTheme.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // desc
                Text(
                  survey.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w400,
                    color: _SurveyTheme.textSecondary,
                    height: 1.4,
                  ),
                ),

                const Spacer(),

                // divider
                const SizedBox(height: 10),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: _SurveyTheme.border,
                ),
                const SizedBox(height: 10),

                // footer
                Row(
                  children: [
                    const Icon(
                      Icons.location_on_outlined,
                      size: 15,
                      color: _SurveyTheme.primary,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        survey.formattedCoordinates,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: _SurveyTheme.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_outlined,
                      size: 14,
                      color: _SurveyTheme.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        survey.formattedDate,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: _SurveyTheme.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // loading
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: _SurveyTheme.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Memuat daftar survey...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _SurveyTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // error
  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _SurveyTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cloud_off_outlined,
                  color: _SurveyTheme.error,
                  size: 30,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Gagal Memuat Survey',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Periksa koneksi internet Anda dan coba lagi.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _SurveyTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () => _fetchSurveys(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  'Coba Lagi',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // empty
  Widget _buildEmptyState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            children: [
              Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: _SurveyTheme.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  color: _SurveyTheme.primary,
                  size: 34,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Belum Ada Survey',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Belum ada data survey yang tersedia saat ini.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: _SurveyTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _handleAddSurvey,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 11,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  'Tambah Survey',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // fab
  Widget _buildFloatingActionButton() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 78),
      child: FloatingActionButton.extended(
        onPressed: _handleAddSurvey,
        backgroundColor: _SurveyTheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded, size: 21),
        label: Text(
          'Tambah Survey',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}