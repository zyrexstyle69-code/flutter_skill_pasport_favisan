import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_appl_latihan/models/survey.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

// theme
abstract class _SurveyDetailTheme {
  // colors
  static const Color primary = Color(0xFF7A1025);
  static const Color primaryDark = Color(0xFF650D20);
  static const Color primaryLight = Color(0xFFA63A50);
  static const Color background = Color(0xFFFCF8F9);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);
  static const Color border = Color(0xFFE2E8F0);
  static const Color borderFocused = Color(0xFF7A1025);
  static const Color error = Color(0xFFE53935);
  static const Color errorBg = Color(0xFFFFF1F2);
  static const Color success = Color(0xFF16A34A);

  // layout
  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
  static const double maxContentWidth = 840.0; // Tidak dipakai lagi jika full
  static const double cardRadius = 16.0;
  static const double badgeRadius = 8.0;

  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= desktopBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 32, vertical: 24);
    }
    if (screenWidth >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(horizontal: 24, vertical: 20);
    }
    return const EdgeInsets.symmetric(horizontal: 16, vertical: 16);
  }
}

class SurveyDetailPage extends StatefulWidget {
  final int surveyId;

  const SurveyDetailPage({super.key, required this.surveyId});

  @override
  State<SurveyDetailPage> createState() => _SurveyDetailPageState();
}

class _SurveyDetailPageState extends State<SurveyDetailPage> {
  // api
  static const String _baseUrl = 'https://sijala.biz.id/api/v1/surveys';
  static const String _imageEndpoint = 'https://sijala.biz.id/api/image';

  // state
  Survey? _survey;
  Future<Uint8List?>? _surveyImageFuture;
  bool _isLoading = true;
  bool _isFetching = false;
  bool _isNotFound = false;
  String? _errorMessage;

  // init
  @override
  void initState() {
    super.initState();
    _fetchSurveyDetail();
  }

  // fetch detail
  Future<void> _fetchSurveyDetail({bool isRefresh = false}) async {
    if (_isFetching) return;
    _isFetching = true;

    if (!isRefresh) {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _errorMessage = null;
          _isNotFound = false;
          _surveyImageFuture = null;
        });
      }
    }

    if (kDebugMode) {
      debugPrint('========== DETAIL SURVEY ==========');
      debugPrint('Survey ID: ${widget.surveyId}');
      debugPrint('===================================');
    }

    if (widget.surveyId <= 0) {
      if (kDebugMode) {
        debugPrint('ERROR: Survey ID tidak valid: ${widget.surveyId}');
      }
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isNotFound = false;
          _errorMessage =
              'ID Survey tidak valid (${widget.surveyId}). Silakan pilih survey dari daftar.';
        });
      }
      _isFetching = false;
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (kDebugMode) {
        debugPrint('Token tersedia: ${token != null && token.trim().isNotEmpty}');
      }

      if (token == null || token.trim().isEmpty) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      final uri = Uri.parse('$_baseUrl/${widget.surveyId}');

      if (kDebugMode) {
        debugPrint('Request URL: $uri');
      }

      final response = await http.get(
        uri,
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (kDebugMode) {
        debugPrint('========== API DETAIL SURVEY ==========');
        debugPrint('URL: $uri');
        debugPrint('Status Code: ${response.statusCode}');
        debugPrint('Response Body: ${response.body}');
        debugPrint('=======================================');
      }

      if (response.statusCode == 401) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      if (response.statusCode == 403) {
        throw Exception('Anda tidak memiliki akses untuk melihat survey ini.');
      }

      if (response.statusCode == 404) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isNotFound = true;
          _errorMessage = 'Data survey tidak ditemukan.';
        });
        return;
      }

      if (response.statusCode == 422) {
        dynamic errDecoded;
        try {
          errDecoded = jsonDecode(response.body);
        } catch (_) {}
        final String msg = errDecoded is Map && errDecoded['message'] != null
            ? errDecoded['message'].toString()
            : 'Permintaan detail survey tidak valid (422).';
        throw Exception(msg);
      }

      if (response.statusCode >= 500 && response.statusCode <= 599) {
        throw Exception('Terjadi masalah pada server. Silakan coba lagi.');
      }

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (kDebugMode) {
          debugPrint('Decoded Type: ${decoded.runtimeType}');
          if (decoded is Map) {
            debugPrint('Data Field Type: ${decoded['data']?.runtimeType}');
          }
        }

        Map<String, dynamic>? surveyMap;

        if (decoded is Map) {
          final dynamic data = decoded['data'];

          if (data is Map) {
            if (data['survey'] is Map) {
              surveyMap = Map<String, dynamic>.from(data['survey'] as Map);
            } else {
              surveyMap = Map<String, dynamic>.from(data);
            }
          } else if (data is List) {
            for (var item in data) {
              if (item is Map) {
                final itemId = int.tryParse(item['id']?.toString() ?? '');
                if (itemId == widget.surveyId) {
                  surveyMap = Map<String, dynamic>.from(item);
                  break;
                }
              }
            }
            if (surveyMap == null && data.isNotEmpty && data.first is Map) {
              surveyMap = Map<String, dynamic>.from(data.first as Map);
            }
          } else if (decoded['id'] != null) {
            surveyMap = Map<String, dynamic>.from(decoded);
          }
        }

        if (surveyMap != null) {
          final parsedSurvey = Survey.fromJson(surveyMap);

          if (kDebugMode) {
            debugPrint('Survey Parsed Successfully: ${parsedSurvey.title}');
            debugPrint('Survey Photo: ${parsedSurvey.photo}');
          }

          final photo = parsedSurvey.photo;
          Future<Uint8List?>? imgFuture;
          if (photo != null && photo.trim().isNotEmpty) {
            imgFuture = _fetchSurveyImage(photo.trim());
          }

          if (!mounted) return;
          setState(() {
            _survey = parsedSurvey;
            _surveyImageFuture = imgFuture;
            _isLoading = false;
            _isNotFound = false;
            _errorMessage = null;
          });
          return;
        } else {
          if (kDebugMode) {
            debugPrint('ERROR: Gagal mengekstrak Map survey dari response: $decoded');
          }
          final String serverMessage = decoded is Map && decoded['message'] != null
              ? decoded['message'].toString()
              : 'Gagal membaca data detail survey.';
          throw Exception(serverMessage);
        }
      }

      throw Exception('Gagal memuat detail survey (Kode: ${response.statusCode}).');
    } on TimeoutException {
      if (!mounted) return;
      _handleFetchError('Koneksi waktu habis. Silakan coba lagi.', isRefresh: isRefresh);
    } on FormatException catch (e) {
      if (kDebugMode) {
        debugPrint('JSON FormatException: $e');
      }
      if (!mounted) return;
      _handleFetchError(
        'Gagal membaca data detail survey (Format JSON tidak valid).',
        isRefresh: isRefresh,
      );
    } catch (e) {
      if (!mounted) return;
      final String rawMsg = e.toString().replaceFirst('Exception: ', '');
      final String lower = rawMsg.toLowerCase();

      String userMessage = rawMsg;
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
    setState(() {
      _isLoading = false;
      _isNotFound = false;
      if (!isRefresh || _survey == null) {
        _errorMessage = message;
      }
    });

    if (isRefresh) {
      _showModernSnackBar(message: message, isSuccess: false);
    }
  }

  // fetch image
  Future<Uint8List?> _fetchSurveyImage(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final Uri uri;
      if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
        uri = Uri.parse(fileName);
      } else {
        uri = Uri.parse('$_imageEndpoint/$fileName');
      }

      if (kDebugMode) {
        debugPrint('Fetching Survey Image: $uri');
      }

      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }
      return null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('SURVEY IMAGE FETCH ERROR: $e');
      }
      return null;
    }
  }

  // preview image
  void _showImagePreviewDialog(
    BuildContext context,
    Uint8List imageBytes,
    String title,
  ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    tooltip: 'Tutup',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.72,
                    maxWidth: 800,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.8,
                    maxScale: 4.0,
                    child: Center(
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Gunakan dua jari untuk zoom & geser gambar',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // maps
  Future<void> _openGoogleMaps(double latitude, double longitude) async {
    final url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );

    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(url, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      if (!mounted) return;
      _showModernSnackBar(
        message: 'Tidak dapat membuka Google Maps.',
        isSuccess: false,
      );
    }
  }

  // copy coord
  Future<void> _copyCoordinates(double latitude, double longitude) async {
    final text = '$latitude, $longitude';
    await Clipboard.setData(ClipboardData(text: text));

    if (!mounted) return;
    _showModernSnackBar(
      message: 'Koordinat berhasil disalin: $text',
      isSuccess: true,
    );
  }

  // validasi coord
  bool _isValidCoordinate(double? lat, double? lng) {
    if (lat == null || lng == null) return false;
    if (lat < -90.0 || lat > 90.0) return false;
    if (lng < -180.0 || lng > 180.0) return false;
    return true;
  }

  // edit
  Future<void> _handleEditSurvey() async {
    if (_survey == null) return;
    final result = await context.push(
      AppRoutes.editSurvey,
      extra: _survey,
    );

    if (result == true && mounted) {
      await _fetchSurveyDetail(isRefresh: true);
    }
  }

  // delete
  Future<void> _handleDeleteSurvey() async {
    if (_survey == null) return;

    final confirm = await _showDeleteConfirmationDialog();
    if (confirm != true) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.trim().isEmpty) {
        await _handleUnauthorized(prefs);
        return;
      }

      final response = await http.post(
        Uri.parse('https://sijala.biz.id/api/v1/surveys/${widget.surveyId}/delete'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        if (!mounted) return;
        _showModernSnackBar(
          message: 'Survey berhasil dihapus.',
          isSuccess: true,
        );
        context.pop(true);
        return;
      }

      if (response.statusCode == 401) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      throw Exception('Gagal menghapus survey (Kode HTTP: ${response.statusCode}).');
    } catch (e) {
      if (!mounted) return;
      final rawMsg = e.toString().replaceFirst('Exception: ', '');
      _showModernSnackBar(message: rawMsg, isSuccess: false);
    }
  }

  // dialog delete
  Future<bool?> _showDeleteConfirmationDialog() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: _SurveyDetailTheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_SurveyDetailTheme.cardRadius),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: _SurveyDetailTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.delete_forever_rounded,
                    color: _SurveyDetailTheme.error,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Hapus Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Apakah Anda yakin ingin menghapus survey ini? Tindakan ini tidak dapat dibatalkan.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: _SurveyDetailTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: _SurveyDetailTheme.border),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: Text(
                        'Batal',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _SurveyDetailTheme.textSecondary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _SurveyDetailTheme.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: Text(
                        'Hapus',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // snackbar
  void _showModernSnackBar({
    required String message,
    required bool isSuccess,
  }) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? _SurveyDetailTheme.success : _SurveyDetailTheme.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        duration: const Duration(seconds: 3),
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13.5,
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
    final pagePadding = _SurveyDetailTheme.getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor: _SurveyDetailTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                color: _SurveyDetailTheme.primary,
                backgroundColor: _SurveyDetailTheme.surface,
                onRefresh: () => _fetchSurveyDetail(isRefresh: true),
                child: _buildBodyContent(
                  screenWidth: screenWidth,
                  padding: pagePadding,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // header
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: _SurveyDetailTheme.surface,
        border: Border(
          bottom: BorderSide(color: _SurveyDetailTheme.border, width: 1),
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _SurveyDetailTheme.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _SurveyDetailTheme.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: _SurveyDetailTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Text(
            'Detail Survey',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _SurveyDetailTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
          if (_survey != null)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _handleEditSurvey,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _SurveyDetailTheme.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _SurveyDetailTheme.primary.withValues(alpha: 0.18),
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_outlined,
                          size: 18,
                          color: _SurveyDetailTheme.primary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: _handleDeleteSurvey,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _SurveyDetailTheme.errorBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _SurveyDetailTheme.error.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Icon(
                          Icons.delete_outline_rounded,
                          size: 18,
                          color: _SurveyDetailTheme.error,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
    if (_isNotFound) return _buildNotFoundState();
    if (_errorMessage != null || _survey == null) return _buildErrorState();

    final survey = _survey!;
    final bool isWide = screenWidth >= _SurveyDetailTheme.desktopBreakpoint;

    
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: padding,
      child: isWide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSurveyHeaderCard(survey),
                      const SizedBox(height: 18),
                      _buildSurveyPhotoCard(survey),
                      const SizedBox(height: 18),
                      _buildDescriptionCard(survey),
                      const SizedBox(height: 18),
                      _buildInformationCard(survey),
                    ],
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  flex: 6,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildLocationSectionCard(survey),
                      const SizedBox(height: 18),
                      _buildActionSectionCard(survey),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSurveyHeaderCard(survey),
                const SizedBox(height: 16),
                _buildSurveyPhotoCard(survey),
                const SizedBox(height: 16),
                _buildDescriptionCard(survey),
                const SizedBox(height: 16),
                _buildInformationCard(survey),
                const SizedBox(height: 16),
                _buildLocationSectionCard(survey),
                const SizedBox(height: 16),
                _buildActionSectionCard(survey),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  // card decoration
  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _SurveyDetailTheme.surface,
      borderRadius: BorderRadius.circular(_SurveyDetailTheme.cardRadius),
      border: Border.all(
        color: _SurveyDetailTheme.border.withValues(alpha: 0.8),
        width: 1,
      ),
      boxShadow: [
        BoxShadow(
          color: const Color(0xFF1E293B).withValues(alpha: 0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  // action card
  Widget _buildActionSectionCard(Survey survey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.settings_outlined,
                size: 18,
                color: _SurveyDetailTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Kelola Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 46,
                  child: ElevatedButton.icon(
                    onPressed: _handleEditSurvey,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SurveyDetailTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.edit_rounded, size: 16),
                    label: Text(
                      'Edit Survey',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton.icon(
                    onPressed: _handleDeleteSurvey,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _SurveyDetailTheme.errorBg),
                      backgroundColor: _SurveyDetailTheme.errorBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 16,
                      color: _SurveyDetailTheme.error,
                    ),
                    label: Text(
                      'Hapus',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: _SurveyDetailTheme.error,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // header card
  Widget _buildSurveyHeaderCard(Survey survey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      _SurveyDetailTheme.primaryLight,
                      _SurveyDetailTheme.primaryDark,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _SurveyDetailTheme.primary.withValues(alpha: 0.22),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.assignment_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _SurveyDetailTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          _SurveyDetailTheme.badgeRadius,
                        ),
                        border: Border.all(
                          color: _SurveyDetailTheme.primary.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Text(
                        survey.categoryName,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _SurveyDetailTheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'ID Survei: #${survey.id}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _SurveyDetailTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            survey.title,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _SurveyDetailTheme.textPrimary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  // photo card
  Widget _buildSurveyPhotoCard(Survey survey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.photo_camera_back_outlined,
                    size: 18,
                    color: _SurveyDetailTheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Foto Survey',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _SurveyDetailTheme.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_surveyImageFuture != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: _SurveyDetailTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.image_rounded,
                        size: 12,
                        color: _SurveyDetailTheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Dokumentasi',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _SurveyDetailTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _buildSurveyPhotoContent(survey),
        ],
      ),
    );
  }

  // photo content
  Widget _buildSurveyPhotoContent(Survey survey) {
    if (_surveyImageFuture == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: _SurveyDetailTheme.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _SurveyDetailTheme.border.withValues(alpha: 0.8),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _SurveyDetailTheme.border.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 24,
                color: _SurveyDetailTheme.textMuted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Foto survey belum tersedia',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: _SurveyDetailTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Belum ada foto dokumentasi yang diunggah untuk survey ini.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: _SurveyDetailTheme.textMuted,
              ),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _surveyImageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              color: _SurveyDetailTheme.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _SurveyDetailTheme.border),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _SurveyDetailTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Memuat foto survey...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: _SurveyDetailTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final bytes = snapshot.data!;
          return Container(
            height: 240,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _SurveyDetailTheme.border.withValues(alpha: 0.8),
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.memory(
                  bytes,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  errorBuilder: (context, error, stackTrace) {
                    return _buildImageErrorPlaceholder(survey);
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.65),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.zoom_in_rounded,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Ketuk untuk memperbesar',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Preview',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => _showImagePreviewDialog(
                        context,
                        bytes,
                        survey.title,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return _buildImageErrorPlaceholder(survey);
      },
    );
  }

  // image error
  Widget _buildImageErrorPlaceholder(Survey survey) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: _SurveyDetailTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SurveyDetailTheme.border),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: _SurveyDetailTheme.errorBg,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.broken_image_rounded,
              size: 22,
              color: _SurveyDetailTheme.error,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Foto survey tidak dapat dimuat',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _SurveyDetailTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gagal mengunduh gambar dari server.',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: _SurveyDetailTheme.textSecondary,
            ),
          ),
          if (survey.photo != null && survey.photo!.isNotEmpty) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _surveyImageFuture = _fetchSurveyImage(survey.photo!);
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: _SurveyDetailTheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: const BorderSide(
                    color: _SurveyDetailTheme.primary,
                    width: 1,
                  ),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: Text(
                'Coba Muat Ulang Foto',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // description
  Widget _buildDescriptionCard(Survey survey) {
    final String desc = survey.description.trim();
    final bool isEmptyDesc = desc.isEmpty || desc == '-';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 18,
                color: _SurveyDetailTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Deskripsi Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isEmptyDesc ? 'Tidak ada deskripsi.' : desc,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w400,
              color: isEmptyDesc
                  ? _SurveyDetailTheme.textMuted
                  : _SurveyDetailTheme.textSecondary,
              fontStyle: isEmptyDesc ? FontStyle.italic : FontStyle.normal,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }

  // info
  Widget _buildInformationCard(Survey survey) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: _SurveyDetailTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Informasi Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildInfoItem(
            icon: Icons.tag_rounded,
            label: 'ID Survey',
            value: '#${survey.id}',
          ),
          const SizedBox(height: 10),
          _buildInfoItem(
            icon: Icons.category_outlined,
            label: 'Kategori',
            value: survey.categoryName,
          ),
          const SizedBox(height: 10),
          _buildInfoItem(
            icon: Icons.calendar_today_rounded,
            label: 'Tanggal Survey',
            value: survey.formattedDate,
          ),
        ],
      ),
    );
  }

  // info item
  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _SurveyDetailTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _SurveyDetailTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: _SurveyDetailTheme.textSecondary),
          const SizedBox(width: 10),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: _SurveyDetailTheme.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              softWrap: true,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _SurveyDetailTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // location
  Widget _buildLocationSectionCard(Survey survey) {
    final bool hasCoords = _isValidCoordinate(
      survey.latitude,
      survey.longitude,
    );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 20,
                color: _SurveyDetailTheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Lokasi Survey',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            height: 270,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _SurveyDetailTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasCoords
                ? FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(
                        survey.latitude!,
                        survey.longitude!,
                      ),
                      initialZoom: 16.0,
                      minZoom: 4.0,
                      maxZoom: 19.0,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName:
                            'com.example.flutter_appl_latihan',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(
                              survey.latitude!,
                              survey.longitude!,
                            ),
                            width: 48,
                            height: 48,
                            alignment: Alignment.topCenter,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: _SurveyDetailTheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _SurveyDetailTheme.primary
                                        .withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.location_on_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                : Container(
                    color: _SurveyDetailTheme.background,
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_off_rounded,
                            size: 36,
                            color: _SurveyDetailTheme.textMuted,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Lokasi survey tidak dapat ditampilkan karena koordinat tidak valid.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: _SurveyDetailTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _SurveyDetailTheme.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _SurveyDetailTheme.border),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Latitude: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _SurveyDetailTheme.textSecondary,
                            ),
                          ),
                          Text(
                            survey.latitude != null
                                ? survey.latitude.toString()
                                : '-',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _SurveyDetailTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            'Longitude: ',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _SurveyDetailTheme.textSecondary,
                            ),
                          ),
                          Text(
                            survey.longitude != null
                                ? survey.longitude.toString()
                                : '-',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: _SurveyDetailTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (hasCoords)
                  IconButton(
                    onPressed: () => _copyCoordinates(
                      survey.latitude!,
                      survey.longitude!,
                    ),
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: 18,
                      color: _SurveyDetailTheme.primaryLight,
                    ),
                    tooltip: 'Salin Koordinat',
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (hasCoords)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () => _openGoogleMaps(
                  survey.latitude!,
                  survey.longitude!,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyDetailTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.map_rounded, size: 18),
                label: Text(
                  'Buka di Google Maps',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
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
            width: 36,
            height: 36,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(
                _SurveyDetailTheme.primary,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Memuat detail survey...',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: _SurveyDetailTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // not found
  Widget _buildNotFoundState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _SurveyDetailTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.search_off_rounded,
                    color: _SurveyDetailTheme.error,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Data Survey Tidak Ditemukan',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Survey yang Anda cari tidak tersedia atau telah dihapus.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: _SurveyDetailTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _SurveyDetailTheme.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: Text(
                  'Kembali ke Daftar Survey',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
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

  // error
  Widget _buildErrorState() {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 60),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: _SurveyDetailTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.cloud_off_rounded,
                    color: _SurveyDetailTheme.error,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Gagal Memuat Detail Survey',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _SurveyDetailTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? 'Data survey tidak dapat dimuat.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: _SurveyDetailTheme.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: _SurveyDetailTheme.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(
                      Icons.arrow_back_rounded,
                      size: 18,
                      color: _SurveyDetailTheme.textPrimary,
                    ),
                    label: Text(
                      'Kembali',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _SurveyDetailTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => _fetchSurveyDetail(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _SurveyDetailTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(
                      'Coba Lagi',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}