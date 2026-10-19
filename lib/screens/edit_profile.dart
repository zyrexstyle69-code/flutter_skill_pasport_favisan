import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class _EditProfileTheme {
  static const Color primary = Color(0xFF7A1025);
  static const Color background = Color(0xFFFCF8F9);
  static const Color surface = Colors.white;

  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  static const Color inputBackground = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);

  static const Color error = Color(0xFFE53935);
  static const Color success = Color(0xFF16A34A);

  static const double maxContentWidth = 600; // Tidak dipakai lagi

  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= 800) {
      return const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 24,
      );
    }

    return const EdgeInsets.symmetric(
      horizontal: 20,
      vertical: 18,
    );
  }
}

class EditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? profile;

  const EditProfilePage({
    super.key,
    this.profile,
  });

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nameController;
  late TextEditingController emailController;
  late TextEditingController phoneController;
  late TextEditingController birthPlaceController;
  late TextEditingController birthDateController;

  String? gender;
  String? apiBirthDate;

  XFile? selectedImage;
  Uint8List? selectedImageBytes;

  Future<Uint8List?>? oldProfileImageFuture;

  bool isLoading = false;

  static const String baseUrl =
      'https://sijala.biz.id/api/v1';

  static const String profileUpdateEndpoint =
      '$baseUrl/profile/update';

  static const String imageEndpoint =
      'https://sijala.biz.id/api/image';

  @override
  void initState() {
    super.initState();

    final profile = widget.profile ?? {};

    nameController = TextEditingController(
      text: profile['name']?.toString() ?? '',
    );

    emailController = TextEditingController(
      text: profile['email']?.toString() ?? '',
    );

    phoneController = TextEditingController(
      text: profile['phone']?.toString() ?? '',
    );

    birthPlaceController = TextEditingController(
      text: profile['birth_place']?.toString() ?? '',
    );

    // Jenis kelamin
    if (profile['gender'] != null) {
      final g = profile['gender'].toString().toLowerCase();

      if (g.startsWith('l')) {
        gender = 'L';
      } else if (g.startsWith('p')) {
        gender = 'P';
      }
    }

    // Tanggal lahir
    String displayBirthDate = '';

    final String? rawDate =
        profile['birth_date']?.toString();

    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        DateTime? parsedDate;

        if (rawDate.contains('-')) {
          final parts = rawDate.split('-');

          if (parts.length == 3) {
            if (parts[0].length == 4) {
              // YYYY-MM-DD
              parsedDate = DateTime.parse(rawDate);
            } else if (parts[2].length == 4) {
              // DD-MM-YYYY
              final day = int.parse(parts[0]);
              final month = int.parse(parts[1]);
              final year = int.parse(parts[2]);

              parsedDate = DateTime(
                year,
                month,
                day,
              );
            }
          }
        }

        if (parsedDate != null) {
          final day = parsedDate.day
              .toString()
              .padLeft(2, '0');

          final month = parsedDate.month
              .toString()
              .padLeft(2, '0');

          final year = parsedDate.year.toString();

          displayBirthDate =
              '$day-$month-$year';

          apiBirthDate =
              '$year-$month-$day';
        } else {
          displayBirthDate = rawDate;
          apiBirthDate = rawDate;
        }
      } catch (_) {
        displayBirthDate = rawDate;
        apiBirthDate = rawDate;
      }
    }

    birthDateController =
        TextEditingController(
      text: displayBirthDate,
    );

    // Foto lama
    final oldPhoto =
        profile['photo']?.toString();

    if (oldPhoto != null &&
        oldPhoto.isNotEmpty) {
      oldProfileImageFuture =
          fetchProfileImage(oldPhoto);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    birthPlaceController.dispose();
    birthDateController.dispose();

    super.dispose();
  }

  dynamic safeJsonDecode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

// pilih foto
  Future<void> pickImage() async {
    try {
      final picker = ImagePicker();

      final pickedFile =
          await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final bytes =
            await pickedFile.readAsBytes();

        if (!mounted) return;

        setState(() {
          selectedImage = pickedFile;
          selectedImageBytes = bytes;
        });
      }
    } catch (e) {
      if (!mounted) return;

      _showSnackBar(
        message:
            'Gagal mengambil gambar dari galeri.',
        isSuccess: false,
      );
    }
  }

//  buat ambil foto lama
  Future<Uint8List?> fetchProfileImage(
    String fileName,
  ) async {
    try {
      final prefs =
          await SharedPreferences.getInstance();

      final token =
          prefs.getString('token') ?? '';

      final response = await http.get(
        Uri.parse('$imageEndpoint/$fileName'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        return response.bodyBytes;
      }

      return null;
    } catch (e) {
      debugPrint(
        'IMAGE FETCH ERROR: $e',
      );

      return null;
    }
  }

//  pilih tanggal lahir

  Future<void> selectBirthDate() async {
    DateTime initialDate =
        DateTime.now().subtract(
      const Duration(days: 365 * 10),
    );

    if (apiBirthDate != null &&
        apiBirthDate!.isNotEmpty) {
      try {
        initialDate =
            DateTime.parse(apiBirthDate!);
      } catch (_) {}
    }

    final DateTime? picked =
        await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime.now().subtract(
        const Duration(days: 1),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary:
                  _EditProfileTheme.primary,
              onPrimary: Colors.white,
              onSurface:
                  _EditProfileTheme.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final day =
          picked.day.toString().padLeft(2, '0');

      final month =
          picked.month.toString().padLeft(2, '0');

      final year =
          picked.year.toString();

      setState(() {
        birthDateController.text =
            '$day-$month-$year';

        apiBirthDate =
            '$year-$month-$day';
      });
    }
  }

  // simpan proofil

  Future<void> saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (gender == null) {
      _showSnackBar(
        message:
            'Silakan pilih jenis kelamin.',
        isSuccess: false,
      );

      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final token =
          prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'Token tidak ditemukan. Silakan login kembali.',
        );
      }

      final request =
          http.MultipartRequest(
        'POST',
        Uri.parse(profileUpdateEndpoint),
      );

      request.headers['Accept'] =
          'application/json';

      request.headers['Authorization'] =
          'Bearer $token';

      request.fields['name'] =
          nameController.text.trim();

      request.fields['email'] =
          emailController.text.trim();

      request.fields['phone'] =
          phoneController.text.trim();

      request.fields['gender'] =
          gender!;

      request.fields['birth_place'] =
          birthPlaceController.text.trim();

      if (apiBirthDate != null) {
        request.fields['birth_date'] =
            apiBirthDate!;
      }

      // Foto baru
      if (selectedImage != null &&
          selectedImageBytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'photo',
            selectedImageBytes!,
            filename: selectedImage!.name,
          ),
        );
      }

      final streamedResponse =
          await request.send().timeout(
        const Duration(seconds: 15),
      );

      final response =
          await http.Response.fromStream(
        streamedResponse,
      );

      final data =
          safeJsonDecode(response.body);

      // Berhasil
      if (streamedResponse.statusCode == 200) {
        if (data != null &&
            data['status'] == true) {
          if (data['data'] != null) {
            await prefs.setString(
              'user',
              jsonEncode(data['data']),
            );
          }

          if (!mounted) return;

          _showSnackBar(
            message:
                'Profil berhasil diperbarui.',
            isSuccess: true,
          );

          Navigator.pop(context, true);

          return;
        } else {
          throw Exception(
            data?['message'] ??
                'Gagal memperbarui profil.',
          );
        }
      }

      // Validasi 422
      else if (streamedResponse.statusCode ==
          422) {
        String validationErrors = '';

        if (data != null &&
            data['errors'] != null &&
            data['errors'] is Map) {
          final errorsMap =
              data['errors'] as Map;

          for (var key in errorsMap.keys) {
            final List messages =
                errorsMap[key];

            for (var msg in messages) {
              validationErrors +=
                  '$msg\n';
            }
          }
        }

        if (validationErrors.isEmpty) {
          validationErrors =
              data?['message'] ??
                  'Validasi gagal.';
        }

        throw Exception(
          validationErrors.trim(),
        );
      }

      // Token expired
      else if (streamedResponse.statusCode ==
          401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        _showSnackBar(
          message:
              'Sesi telah berakhir. Silakan login kembali.',
          isSuccess: false,
        );

        context.go(
          AppRoutes.login,
        );

        return;
      }

      // Error lainnya
      else {
        throw Exception(
          'Gagal memperbarui profil. '
          'Error Code: ${streamedResponse.statusCode}',
        );
      }
    } catch (e) {
      if (!mounted) return;

      String msg =
          e.toString().replaceAll(
                'Exception: ',
                '',
              );

      if (msg.toLowerCase().contains(
                'socket',
              ) ||
          msg.toLowerCase().contains(
                'failed to connect',
              ) ||
          msg.toLowerCase().contains(
                'clientexception',
              )) {
        msg =
            'Tidak dapat terhubung ke server. '
            'Periksa koneksi internet Anda.';
      }

      _showSnackBar(
        message: msg,
        isSuccess: false,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // SnackBar

  void _showSnackBar({
    required String message,
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? _EditProfileTheme.success
            : _EditProfileTheme.error,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(10),
        ),
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons
                      .check_circle_outline
                  : Icons.error_outline,
              color: Colors.white,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style:
                    GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
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
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final pagePadding =
        _EditProfileTheme
            .getPagePadding(screenWidth);

    return Scaffold(
      backgroundColor:
          _EditProfileTheme.background,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,

                padding: pagePadding,
                child: Form(
                  key: _formKey,

                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .stretch,

                    children: [
                      _buildPhotoSection(),

                      const SizedBox(
                        height: 22,
                      ),

                      _buildFormCard(),

                      const SizedBox(
                        height: 18,
                      ),

                      _buildSaveButton(),

                      const SizedBox(
                        height: 20,
                      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),

      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color:
                _EditProfileTheme.border,
          ),
        ),
      ),

      child: Row(
        children: [
          IconButton(
            onPressed: () {
              Navigator.pop(context);
            },

            icon: const Icon(
              Icons.arrow_back_rounded,
              color:
                  _EditProfileTheme
                      .textPrimary,
            ),
          ),

          const SizedBox(width: 4),

          Text(
            'Edit Profil',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight:
                  FontWeight.w700,
              color:
                  _EditProfileTheme
                      .textPrimary,
            ),
          ),
        ],
      ),
    );
  }

//  foto profil

  Widget _buildPhotoSection() {
    final oldPhoto =
        widget.profile?['photo']
            ?.toString();

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,

          decoration:
              const BoxDecoration(
            color:
                _EditProfileTheme.primary,
            shape: BoxShape.circle,
          ),

          padding:
              const EdgeInsets.all(3),

          child: Container(
            decoration:
                const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),

            child: ClipOval(
              child:
                  selectedImageBytes != null
                      ? Image.memory(
                          selectedImageBytes!,
                          width: 94,
                          height: 94,
                          fit: BoxFit.cover,
                        )
                      : (
                          oldPhoto != null &&
                                  oldPhoto
                                      .isNotEmpty
                              ? FutureBuilder<
                                  Uint8List?>(
                                  future:
                                      oldProfileImageFuture,
                                  builder:
                                      (
                                    context,
                                    snapshot,
                                  ) {
                                    if (snapshot
                                            .connectionState ==
                                        ConnectionState
                                            .waiting) {
                                      return const Center(
                                        child:
                                            SizedBox(
                                          width: 22,
                                          height: 22,
                                          child:
                                              CircularProgressIndicator(
                                            strokeWidth:
                                                2.2,
                                            valueColor:
                                                AlwaysStoppedAnimation<
                                                    Color>(
                                              _EditProfileTheme
                                                  .primary,
                                            ),
                                          ),
                                        ),
                                      );
                                    }

                                    if (snapshot
                                            .hasData &&
                                        snapshot
                                                .data !=
                                            null) {
                                      return Image
                                          .memory(
                                        snapshot.data!,
                                        width: 94,
                                        height: 94,
                                        fit: BoxFit
                                            .cover,
                                      );
                                    }

                                    return const Icon(
                                      Icons
                                          .person_rounded,
                                      size: 48,
                                      color:
                                          _EditProfileTheme
                                              .primary,
                                    );
                                  },
                                )
                              : const Icon(
                                  Icons
                                      .person_rounded,
                                  size: 48,
                                  color:
                                      _EditProfileTheme
                                          .primary,
                                )
                        ),
            ),
          ),
        ),

        const SizedBox(height: 12),

        InkWell(
          onTap:
              isLoading ? null : pickImage,

          borderRadius:
              BorderRadius.circular(10),

          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 8,
            ),

            decoration: BoxDecoration(
              color:
                  _EditProfileTheme
                      .primary
                      .withOpacity(0.08),

              borderRadius:
                  BorderRadius.circular(10),
            ),

            child: Row(
              mainAxisSize:
                  MainAxisSize.min,

              children: [
                const Icon(
                  Icons
                      .camera_alt_outlined,
                  size: 17,
                  color:
                      _EditProfileTheme
                          .primary,
                ),

                const SizedBox(width: 7),

                Text(
                  'Ubah Foto',
                  style: GoogleFonts
                      .plusJakartaSans(
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w600,
                    color:
                        _EditProfileTheme
                            .primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

//  from card

  Widget _buildFormCard() {
    return Container(
      padding:
          const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color:
            _EditProfileTheme.surface,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              _EditProfileTheme.border,
        ),
      ),

      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          Text(
            'Informasi Profil',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 17,
              fontWeight:
                  FontWeight.w700,
              color:
                  _EditProfileTheme
                      .textPrimary,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Perbarui informasi pribadi Anda.',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 12.5,
              color:
                  _EditProfileTheme
                      .textSecondary,
            ),
          ),

          const SizedBox(height: 22),

          // Nama
          _buildFieldLabel(
            'Nama Lengkap',
          ),

          const SizedBox(height: 7),

          TextFormField(
            controller:
                nameController,

            enabled: !isLoading,

            textInputAction:
                TextInputAction.next,

            style:
                _inputTextStyle(),

            decoration:
                _inputDecoration(
              hintText:
                  'Nama lengkap Anda',
              prefixIcon:
                  Icons.person_outline,
            ),

            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Nama wajib diisi';
              }

              if (value.trim().length >
                  255) {
                return 'Nama maksimal 255 karakter';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // Email
          _buildFieldLabel(
            'Email',
          ),

          const SizedBox(height: 7),

          TextFormField(
            controller:
                emailController,

            enabled: !isLoading,

            keyboardType:
                TextInputType.emailAddress,

            textInputAction:
                TextInputAction.next,

            style:
                _inputTextStyle(),

            decoration:
                _inputDecoration(
              hintText:
                  'nama@email.com',
              prefixIcon:
                  Icons.email_outlined,
            ),

            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Email wajib diisi';
              }

              if (!value.contains('@')) {
                return 'Format email tidak valid';
              }

              if (value.trim().length >
                  255) {
                return 'Email maksimal 255 karakter';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // Nomor HP
          _buildFieldLabel(
            'Nomor HP',
          ),

          const SizedBox(height: 7),

          TextFormField(
            controller:
                phoneController,

            enabled: !isLoading,

            keyboardType:
                TextInputType.phone,

            textInputAction:
                TextInputAction.next,

            style:
                _inputTextStyle(),

            decoration:
                _inputDecoration(
              hintText:
                  '08xxxxxxxxxx',
              prefixIcon:
                  Icons.phone_outlined,
            ),

            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Nomor HP wajib diisi';
              }

              final numStr =
                  value.trim();

              if (numStr.length < 10) {
                return 'Nomor HP minimal 10 digit';
              }

              if (numStr.length > 15) {
                return 'Nomor HP maksimal 15 digit';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // Jenis Kelamin
          _buildFieldLabel(
            'Jenis Kelamin',
          ),

          const SizedBox(height: 7),

          DropdownButtonFormField<
              String>(
            initialValue: gender,

            style:
                _inputTextStyle(),

            icon: const Icon(
              Icons
                  .keyboard_arrow_down_rounded,
              color:
                  _EditProfileTheme
                      .textSecondary,
            ),

            decoration:
                _inputDecoration(
              hintText:
                  'Pilih jenis kelamin',
              prefixIcon:
                  Icons.wc_outlined,
            ),

            dropdownColor:
                _EditProfileTheme.surface,

            borderRadius:
                BorderRadius.circular(10),

            items: const [
              DropdownMenuItem(
                value: 'L',
                child:
                    Text('Laki-laki'),
              ),
              DropdownMenuItem(
                value: 'P',
                child:
                    Text('Perempuan'),
              ),
            ],

            onChanged: isLoading
                ? null
                : (value) {
                    setState(() {
                      gender = value;
                    });
                  },

            validator: (value) {
              if (value == null) {
                return 'Jenis kelamin wajib dipilih';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // Tempat Lahir
          _buildFieldLabel(
            'Tempat Lahir',
          ),

          const SizedBox(height: 7),

          TextFormField(
            controller:
                birthPlaceController,

            enabled: !isLoading,

            textInputAction:
                TextInputAction.next,

            style:
                _inputTextStyle(),

            decoration:
                _inputDecoration(
              hintText:
                  'Kota tempat Anda lahir',
              prefixIcon:
                  Icons.location_on_outlined,
            ),

            validator: (value) {
              if (value != null &&
                  value.trim().length >
                      100) {
                return 'Tempat lahir maksimal 100 karakter';
              }

              return null;
            },
          ),

          const SizedBox(height: 16),

          // Tanggal Lahir
          _buildFieldLabel(
            'Tanggal Lahir',
          ),

          const SizedBox(height: 7),

          TextFormField(
            controller:
                birthDateController,

            readOnly: true,

            enabled: !isLoading,

            onTap: isLoading
                ? null
                : selectBirthDate,

            style:
                _inputTextStyle(),

            decoration:
                _inputDecoration(
              hintText:
                  'Pilih tanggal lahir',
              prefixIcon:
                  Icons.calendar_today_outlined,
            ),

            validator: (value) {
              if (value == null ||
                  value.isEmpty) {
                return 'Tanggal lahir wajib dipilih';
              }

              return null;
            },
          ),
        ],
      ),
    );
  }

// save button

  Widget _buildSaveButton() {
    return SizedBox(
      height: 50,

      child: ElevatedButton(
        onPressed:
            isLoading ? null : saveProfile,

        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              _EditProfileTheme
                  .primary,

          disabledBackgroundColor:
              _EditProfileTheme
                  .primary
                  .withOpacity(0.5),

          foregroundColor:
              Colors.white,

          elevation: 0,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(10),
          ),
        ),

        child: isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.3,
                  valueColor:
                      AlwaysStoppedAnimation<
                          Color>(
                    Colors.white,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,

                children: [
                  Text(
                    'Simpan Perubahan',
                    style: GoogleFonts
                        .plusJakartaSans(
                      fontSize: 14,
                      fontWeight:
                          FontWeight.w700,
                      color:
                          Colors.white,
                    ),
                  ),

                  const SizedBox(
                    width: 7,
                  ),

                  const Icon(
                    Icons
                        .check_rounded,
                    size: 18,
                    color:
                        Colors.white,
                  ),
                ],
              ),
      ),
    );
  }

// label

  Widget _buildFieldLabel(
    String label,
  ) {
    return Text(
      label,
      style:
          GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight:
            FontWeight.w700,
        color:
            _EditProfileTheme
                .textPrimary,
      ),
    );
  }

  // input style

  TextStyle _inputTextStyle() {
    return GoogleFonts.plusJakartaSans(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color:
          _EditProfileTheme
              .textPrimary,
    );
  }

// input decoration
  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,

      hintStyle:
          GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        color:
            _EditProfileTheme
                .textMuted,
        fontWeight:
            FontWeight.w400,
      ),

      filled: true,

      fillColor:
          _EditProfileTheme
              .inputBackground,

      prefixIcon: Icon(
        prefixIcon,
        size: 20,
        color:
            _EditProfileTheme
                .textSecondary,
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color:
              _EditProfileTheme
                  .border,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color:
              _EditProfileTheme
                  .border,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color:
              _EditProfileTheme
                  .primary,
          width: 1.5,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color:
              _EditProfileTheme
                  .error,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(10),
        borderSide:
            const BorderSide(
          color:
              _EditProfileTheme
                  .error,
          width: 1.5,
        ),
      ),

      errorStyle:
          GoogleFonts.plusJakartaSans(
        fontSize: 11,
        color:
            _EditProfileTheme
                .error,
      ),
    );
  }
}