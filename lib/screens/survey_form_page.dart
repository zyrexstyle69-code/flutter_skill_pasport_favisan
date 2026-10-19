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
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

// theme
abstract class _SurveyFormTheme {
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

  static const double mobileBreakpoint = 600.0;
  static const double desktopBreakpoint = 1024.0;
  static const double maxContentWidth = 840.0; // Tidak dipakai lagi jika full
  static const double cardRadius = 16.0;
  static const double inputRadius = 12.0;
  static const double buttonRadius = 12.0;

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

// category model
class SurveyCategory {
  final int id;
  final String name;

  const SurveyCategory({
    required this.id,
    required this.name,
  });

  factory SurveyCategory.fromJson(Map<String, dynamic> json) {
    return SurveyCategory(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
    );
  }
}

class SurveyFormPage extends StatefulWidget {
  final Survey? survey;

  const SurveyFormPage({
    super.key,
    this.survey,
  });

  @override
  State<SurveyFormPage> createState() => _SurveyFormPageState();
}

class _SurveyFormPageState extends State<SurveyFormPage> {
  final _formKey = GlobalKey<FormState>();

  // api
  static const String _baseUrl = 'https://sijala.biz.id/api/v1';
  static const String _saveEndpoint = '$_baseUrl/surveys/save';
  static const String _categoriesEndpoint = '$_baseUrl/categories';
  static const String _imageEndpoint = 'https://sijala.biz.id/api/image';

  // default lokasi: Tasikmalaya
  static const LatLng _defaultLocation = LatLng(-7.3274, 108.2207);

  // controller
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _latitudeController;
  late final TextEditingController _longitudeController;
  late final MapController _mapController;

  // state
  bool get isEdit => widget.survey != null;

  int? _selectedCategoryId;
  List<SurveyCategory> _categories = [];
  bool _isLoadingCategories = true;
  String? _categoryError;
  bool _isSubmitting = false;

  // image
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  String? _existingPhoto;
  Future<Uint8List?>? _existingPhotoImageFuture;

  // map
  LatLng? _selectedLocation;

  // init
  @override
  void initState() {
    super.initState();

    final survey = widget.survey;

    _titleController = TextEditingController(text: survey?.title ?? '');

    _descriptionController = TextEditingController(
      text: (survey?.description == '-' ? '' : survey?.description) ?? '',
    );

    _latitudeController = TextEditingController(
      text: survey?.latitude != null ? survey!.latitude.toString() : '',
    );

    _longitudeController = TextEditingController(
      text: survey?.longitude != null ? survey!.longitude.toString() : '',
    );

    _mapController = MapController();

    if (survey != null && survey.categoryId > 0) {
      _selectedCategoryId = survey.categoryId;
    }

    if (survey?.latitude != null && survey?.longitude != null) {
      _selectedLocation = LatLng(survey!.latitude!, survey.longitude!);
    }

    _existingPhoto = survey?.photo;

    if (_existingPhoto != null && _existingPhoto!.trim().isNotEmpty) {
      _existingPhotoImageFuture = _fetchExistingSurveyImage(_existingPhoto!.trim());
    }

    _latitudeController.addListener(_onCoordinateInputChanged);
    _longitudeController.addListener(_onCoordinateInputChanged);

    _fetchCategories();
  }

  // dispose
  @override
  void dispose() {
    _latitudeController.removeListener(_onCoordinateInputChanged);
    _longitudeController.removeListener(_onCoordinateInputChanged);

    _titleController.dispose();
    _descriptionController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();

    _mapController.dispose();

    super.dispose();
  }

  // coord listener
  void _onCoordinateInputChanged() {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());

    if (lat != null && lng != null && _isValidCoordinate(lat, lng)) {
      final newPoint = LatLng(lat, lng);

      if (_selectedLocation?.latitude != newPoint.latitude ||
          _selectedLocation?.longitude != newPoint.longitude) {
        setState(() {
          _selectedLocation = newPoint;
        });
      }
    }
  }

  // validasi coord
  bool _isValidCoordinate(double lat, double lng) {
    return lat >= -90.0 && lat <= 90.0 && lng >= -180.0 && lng <= 180.0;
  }

  // fetch categories
  Future<void> _fetchCategories() async {
    setState(() {
      _isLoadingCategories = true;
      _categoryError = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse(_categoriesEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);
        final dynamic data = decoded is Map ? decoded['data'] : null;

        if (data is List) {
          final categoriesList = data
              .whereType<Map>()
              .map((item) => SurveyCategory.fromJson(Map<String, dynamic>.from(item)))
              .toList();

          if (!mounted) return;

          setState(() {
            _categories = categoriesList;
            _isLoadingCategories = false;

            if (isEdit && widget.survey != null) {
              final exists = _categories.any((c) => c.id == widget.survey!.categoryId);

              if (exists) {
                _selectedCategoryId = widget.survey!.categoryId;
              } else if (widget.survey!.categoryId > 0) {
                _categories.insert(
                  0,
                  SurveyCategory(
                    id: widget.survey!.categoryId,
                    name: widget.survey!.categoryName.isNotEmpty
                        ? widget.survey!.categoryName
                        : 'Kategori ID #${widget.survey!.categoryId}',
                  ),
                );

                _selectedCategoryId = widget.survey!.categoryId;
              }
            }
          });

          return;
        }
      }

      throw Exception('Gagal memuat kategori survey.');
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingCategories = false;
        _categoryError = 'Gagal memuat daftar kategori.';
      });
    }
  }

  // pick image
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();

      final pickedFile = await picker.pickImage(
        source: source,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes = await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          _selectedImage = pickedFile;
          _selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;

      _showModernSnackBar(
        message: 'Gagal mengambil gambar. Pastikan izin akses telah diberikan.',
        isSuccess: false,
      );
    }
  }

  // remove image
  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // fetch image lama
  Future<Uint8List?> _fetchExistingSurveyImage(String fileName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token') ?? '';

      final Uri uri;
      if (fileName.startsWith('http://') || fileName.startsWith('https://')) {
        uri = Uri.parse(fileName);
      } else {
        uri = Uri.parse('$_imageEndpoint/$fileName');
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
      if (kDebugMode) debugPrint('EXISTING IMAGE FETCH ERROR: $e');
      return null;
    }
  }

  // submit
  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      _showModernSnackBar(
        message: 'Silakan lengkapi formulir dengan benar.',
        isSuccess: false,
      );
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId == 0) {
      _showModernSnackBar(
        message: 'Kategori survey wajib dipilih.',
        isSuccess: false,
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (token == null || token.trim().isEmpty) {
        await _handleUnauthorized(prefs);
        return;
      }

      final uri = Uri.parse(_saveEndpoint);
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';
      request.headers['Authorization'] = 'Bearer $token';

      request.fields['title'] = _titleController.text.trim();
      request.fields['category_id'] = _selectedCategoryId.toString();
      request.fields['description'] = _descriptionController.text.trim();

      final latStr = _latitudeController.text.trim();
      final lngStr = _longitudeController.text.trim();

      if (latStr.isNotEmpty) request.fields['latitude'] = latStr;
      if (lngStr.isNotEmpty) request.fields['longitude'] = lngStr;

      if (isEdit) {
        request.fields['id'] = widget.survey!.id.toString();
        request.fields['_method'] = 'PUT';
      }

      if (_selectedImage != null && _selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            _selectedImageBytes!,
            filename: _selectedImage!.name,
          ),
        );
      }

      if (kDebugMode) {
        debugPrint('========== SUBMIT SURVEY ==========');
        debugPrint('Mode: ${isEdit ? "EDIT" : "TAMBAH"}');
        debugPrint('URL: $uri');
        debugPrint('Fields: ${request.fields}');
        debugPrint('Has Photo: ${_selectedImageBytes != null}');
        debugPrint('===================================');
      }

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 25),
      );

      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) {
        debugPrint('Submit Response Code: ${response.statusCode}');
        debugPrint('Submit Response Body: ${response.body}');
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        dynamic decoded;

        try {
          decoded = jsonDecode(response.body);
        } catch (_) {}

        if (decoded is Map && decoded['status'] == false) {
          throw Exception(decoded['message'] ?? 'Gagal menyimpan data survey.');
        }

        if (!mounted) return;

        final successMessage = isEdit
            ? 'Survey berhasil diperbarui.'
            : 'Survey berhasil ditambahkan.';

        _showModernSnackBar(message: successMessage, isSuccess: true);
        context.pop(true);
        return;
      }

      if (response.statusCode == 422) {
        dynamic errDecoded;

        try {
          errDecoded = jsonDecode(response.body);
        } catch (_) {}

        String errorText = '';

        if (errDecoded is Map && errDecoded['errors'] is Map) {
          final errorsMap = errDecoded['errors'] as Map;

          for (var key in errorsMap.keys) {
            final val = errorsMap[key];

            if (val is List) {
              for (var msg in val) {
                errorText += '$msg\n';
              }
            } else if (val != null) {
              errorText += '$val\n';
            }
          }
        }

        if (errorText.trim().isEmpty) {
          errorText = errDecoded is Map && errDecoded['message'] != null
              ? errDecoded['message'].toString()
              : 'Data yang dikirim tidak valid (422).';
        }

        throw Exception(errorText.trim());
      }

      if (response.statusCode == 401) {
        if (!mounted) return;
        await _handleUnauthorized(prefs);
        return;
      }

      if (response.statusCode == 403) {
        throw Exception('Anda tidak memiliki hak akses untuk menyimpan survey.');
      }

      if (response.statusCode == 404) {
        throw Exception('Layanan penyimpanan survey tidak ditemukan (404).');
      }

      if (response.statusCode >= 500) {
        throw Exception('Terjadi masalah pada server. Silakan coba lagi nanti.');
      }

      throw Exception('Gagal menyimpan survey (Kode HTTP: ${response.statusCode}).');
    } on TimeoutException {
      if (!mounted) return;
      _showModernSnackBar(
        message: 'Koneksi waktu habis. Silakan periksa koneksi internet Anda.',
        isSuccess: false,
      );
    } catch (e) {
      if (!mounted) return;
      final rawMsg = e.toString().replaceFirst('Exception: ', '');
      _showModernSnackBar(message: rawMsg, isSuccess: false);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
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
        backgroundColor: isSuccess ? _SurveyFormTheme.success : _SurveyFormTheme.error,
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

  // dialog pilih sumber foto
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _SurveyFormTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _SurveyFormTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pilih Sumber Foto',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: _SurveyFormTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _buildImageSourceTile(
                        icon: Icons.photo_library_rounded,
                        label: 'Galeri Foto',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickImage(ImageSource.gallery);
                        },
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _buildImageSourceTile(
                        icon: Icons.camera_alt_rounded,
                        label: 'Kamera',
                        onTap: () {
                          Navigator.pop(sheetContext);
                          _pickImage(ImageSource.camera);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // tile sumber foto
  Widget _buildImageSourceTile({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _SurveyFormTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SurveyFormTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 18),
            child: Column(
              children: [
                Icon(icon, size: 28, color: _SurveyFormTheme.primary),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _SurveyFormTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // build
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final pagePadding = _SurveyFormTheme.getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor: _SurveyFormTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: pagePadding,
                // PERUBAHAN: Center & ConstrainedBox dihapus agar full layar
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // data utama
                      _buildSectionCard(
                        icon: Icons.assignment_outlined,
                        title: 'Data Utama Survey',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildTitleField(),
                            const SizedBox(height: 16),
                            _buildCategoryDropdown(),
                            const SizedBox(height: 16),
                            _buildDescriptionField(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      // foto
                      _buildSectionCard(
                        icon: Icons.photo_camera_back_outlined,
                        title: 'Foto Dokumentasi Survey',
                        child: _buildPhotoSection(),
                      ),
                      const SizedBox(height: 18),

                      // lokasi
                      _buildSectionCard(
                        icon: Icons.location_on_outlined,
                        title: 'Lokasi Survey',
                        child: _buildLocationSection(),
                      ),
                      const SizedBox(height: 24),

                      // submit
                      _buildSubmitButton(),
                      const SizedBox(height: 32),
                    ],
                  ),
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
        color: _SurveyFormTheme.surface,
        border: Border(
          bottom: BorderSide(color: _SurveyFormTheme.border, width: 1),
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
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _SurveyFormTheme.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _SurveyFormTheme.border),
                  ),
                  child: const Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: _SurveyFormTheme.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Text(
            isEdit ? 'Edit Survey' : 'Tambah Survey',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _SurveyFormTheme.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }

  // section card
  Widget _buildSectionCard({
    required IconData icon,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _SurveyFormTheme.surface,
        borderRadius: BorderRadius.circular(_SurveyFormTheme.cardRadius),
        border: Border.all(color: _SurveyFormTheme.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _SurveyFormTheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 19, color: _SurveyFormTheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _SurveyFormTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  // title
  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label: 'Judul Survey', isRequired: true),
        const SizedBox(height: 6),
        TextFormField(
          controller: _titleController,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _SurveyFormTheme.textPrimary,
          ),
          decoration: _buildInputDecoration(
            hintText: 'Contoh: Jalan Berlubang di Sukamaju',
            prefixIcon: Icons.title_rounded,
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Judul survey wajib diisi.';
            }
            if (value.trim().length > 255) {
              return 'Judul survey maksimal 255 karakter.';
            }
            return null;
          },
        ),
      ],
    );
  }

  // dropdown kategori
  Widget _buildCategoryDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label: 'Kategori Survey', isRequired: true),
        const SizedBox(height: 6),

        if (_isLoadingCategories)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: _SurveyFormTheme.background,
              borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
              border: Border.all(color: _SurveyFormTheme.border),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _SurveyFormTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Memuat kategori...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _SurveyFormTheme.textSecondary,
                  ),
                ),
              ],
            ),
          )
        else if (_categoryError != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  _categoryError!,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    color: _SurveyFormTheme.error,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _fetchCategories,
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Coba Lagi'),
              ),
            ],
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            isExpanded: true,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _SurveyFormTheme.textPrimary,
            ),
            icon: const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _SurveyFormTheme.textSecondary,
            ),
            decoration: _buildInputDecoration(
              hintText: 'Pilih Kategori Survey',
              prefixIcon: Icons.category_outlined,
            ),
            items: _categories
                .map(
                  (cat) => DropdownMenuItem<int>(
                    value: cat.id,
                    child: Text(cat.name),
                  ),
                )
                .toList(),
            onChanged: (val) {
              setState(() => _selectedCategoryId = val);
            },
            validator: (value) {
              if (value == null || value == 0) {
                return 'Kategori survey wajib dipilih.';
              }
              return null;
            },
          ),
      ],
    );
  }

  // deskripsi
  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildFieldLabel(label: 'Deskripsi Survey', isRequired: false),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          minLines: 3,
          maxLines: 6,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.5,
            fontWeight: FontWeight.w400,
            color: _SurveyFormTheme.textPrimary,
            height: 1.4,
          ),
          decoration: _buildInputDecoration(
            hintText: 'Tuliskan rincian hasil observasi atau kondisi lokasi...',
            prefixIcon: Icons.notes_rounded,
            alignLabelWithHint: true,
          ),
        ),
      ],
    );
  }

  // foto
  Widget _buildPhotoSection() {
    // foto baru
    if (_selectedImageBytes != null) {
      return Column(
        children: [
          Container(
            height: 220,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _SurveyFormTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.memory(
              _selectedImageBytes!,
              fit: BoxFit.cover,
              width: double.infinity,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImageSourceDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _SurveyFormTheme.border),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(
                    Icons.photo_library_rounded,
                    size: 16,
                    color: _SurveyFormTheme.primary,
                  ),
                  label: Text(
                    'Ganti Foto',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _SurveyFormTheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _removeSelectedImage,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: _SurveyFormTheme.errorBg),
                  backgroundColor: _SurveyFormTheme.errorBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: 16,
                  color: _SurveyFormTheme.error,
                ),
                label: Text(
                  'Hapus',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _SurveyFormTheme.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // foto lama (edit mode)
    if (isEdit &&
        _existingPhoto != null &&
        _existingPhoto!.isNotEmpty &&
        _existingPhotoImageFuture != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FutureBuilder<Uint8List?>(
            future: _existingPhotoImageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: _SurveyFormTheme.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _SurveyFormTheme.border),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _SurveyFormTheme.primary,
                      ),
                    ),
                  ),
                );
              }

              if (snapshot.hasData && snapshot.data != null) {
                return Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _SurveyFormTheme.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                    width: double.infinity,
                  ),
                );
              }

              return _buildEmptyPhotoUploadBox();
            },
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showImageSourceDialog,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _SurveyFormTheme.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(
                Icons.add_photo_alternate_outlined,
                size: 16,
                color: _SurveyFormTheme.primary,
              ),
              label: Text(
                'Ganti dengan Foto Baru',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _SurveyFormTheme.primary,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return _buildEmptyPhotoUploadBox();
  }

  // empty photo box
  Widget _buildEmptyPhotoUploadBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _SurveyFormTheme.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _SurveyFormTheme.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: _showImageSourceDialog,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _SurveyFormTheme.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.add_a_photo_outlined,
                    size: 24,
                    color: _SurveyFormTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unggah Foto Survey',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _SurveyFormTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ketuk untuk memilih dari galeri atau kamera',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: _SurveyFormTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // lokasi
  Widget _buildLocationSection() {
    final lat = double.tryParse(_latitudeController.text.trim());
    final lng = double.tryParse(_longitudeController.text.trim());

    final bool hasValidCoords =
        lat != null && lng != null && _isValidCoordinate(lat, lng);

    final LatLng centerPoint =
        hasValidCoords ? LatLng(lat, lng) : (_selectedLocation ?? _defaultLocation);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // map
        Container(
          height: 240,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _SurveyFormTheme.border),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: centerPoint,
                  initialZoom: 15.0,
                  minZoom: 4.0,
                  maxZoom: 19.0,
                  onTap: (tapPosition, point) {
                    setState(() {
                      _selectedLocation = point;
                      _latitudeController.text =
                          point.latitude.toStringAsFixed(7);
                      _longitudeController.text =
                          point.longitude.toStringAsFixed(7);
                    });
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.example.flutter_appl_latihan',
                  ),
                  if (_selectedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _selectedLocation!,
                          width: 44,
                          height: 44,
                          alignment: Alignment.topCenter,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: _SurveyFormTheme.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _SurveyFormTheme.primary
                                      .withValues(alpha: 0.30),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.location_on_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Positioned(
                bottom: 10,
                left: 10,
                right: 10,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Ketuk peta untuk menentukan titik koordinat',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // lat & lng
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(label: 'Latitude', isRequired: false),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _latitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _SurveyFormTheme.textPrimary,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: '-7.3274000',
                      prefixIcon: Icons.my_location_rounded,
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed < -90.0 || parsed > 90.0) {
                          return 'Latitude harus antara -90 dan 90';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(label: 'Longitude', isRequired: false),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _longitudeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      signed: true,
                      decimal: true,
                    ),
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: _SurveyFormTheme.textPrimary,
                    ),
                    decoration: _buildInputDecoration(
                      hintText: '108.2207000',
                      prefixIcon: Icons.explore_outlined,
                    ),
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty) {
                        final parsed = double.tryParse(val.trim());
                        if (parsed == null || parsed < -180.0 || parsed > 180.0) {
                          return 'Longitude harus antara -180 dan 180';
                        }
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // submit button
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: _SurveyFormTheme.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: _SurveyFormTheme.primary.withValues(
            alpha: 0.55,
          ),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(_SurveyFormTheme.buttonRadius),
          ),
        ),
        child: _isSubmitting
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Menyimpan Survey...',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isEdit ? 'Simpan Perubahan' : 'Simpan Survey',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // label field
  Widget _buildFieldLabel({
    required String label,
    required bool isRequired,
  }) {
    return Row(
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _SurveyFormTheme.textPrimary,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              color: _SurveyFormTheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ],
    );
  }

  // input decoration
  InputDecoration _buildInputDecoration({
    required String hintText,
    IconData? prefixIcon,
    bool alignLabelWithHint = false,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: _SurveyFormTheme.textMuted,
      ),
      prefixIcon: prefixIcon != null
          ? Icon(
              prefixIcon,
              size: 18,
              color: _SurveyFormTheme.textSecondary,
            )
          : null,
      alignLabelWithHint: alignLabelWithHint,
      filled: true,
      fillColor: _SurveyFormTheme.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: const BorderSide(color: _SurveyFormTheme.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: const BorderSide(color: _SurveyFormTheme.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: const BorderSide(
          color: _SurveyFormTheme.borderFocused,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: const BorderSide(color: _SurveyFormTheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(_SurveyFormTheme.inputRadius),
        borderSide: const BorderSide(
          color: _SurveyFormTheme.error,
          width: 1.5,
        ),
      ),
    );
  }
}