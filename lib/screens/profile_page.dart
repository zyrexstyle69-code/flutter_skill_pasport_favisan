import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:flutter_appl_latihan/screens/edit_profile.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

abstract class _ProfileTheme {
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

  static const double cardRadius = 18;
  static const double actionRadius = 14;

  static const double mobileBreakpoint = 600;
  static const double tabletMaxWidth = 680;
  static const double desktopMaxWidth = 840;

  static double getMaxContentWidth(double screenWidth) {
    return double.infinity; // Diubah agar selalu full layar
  }

  static EdgeInsets getPagePadding(double screenWidth) {
    if (screenWidth >= 1024) {
      return const EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 24,
      );
    }

    if (screenWidth >= mobileBreakpoint) {
      return const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 20,
      );
    }

    return const EdgeInsets.symmetric(
      horizontal: 16,
      vertical: 16,
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
// api
  static const String baseUrl =
      'https://sijala.biz.id/api/v1';

  static const String profileEndpoint =
      '$baseUrl/profile';

  static const String imageEndpoint =
      'https://sijala.biz.id/api/image';

//  state
  Map<String, dynamic>? profile;

  Future<Uint8List?>? profileImageFuture;

  bool isLoading = true;
  bool hasError = false;

  String? errorMessage;

  @override
  void initState() {
    super.initState();
    getProfile();
  }

// profile
  Future<void> getProfile() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        hasError = false;
        errorMessage = null;
      });
    }

    try {
      final prefs = await SharedPreferences.getInstance();

      final token = prefs.getString('token');

      if (token == null || token.isEmpty) {
        throw Exception(
          'Token tidak ditemukan. Silakan login kembali.',
        );
      }

      final response = await http.get(
        Uri.parse(profileEndpoint),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 &&
          data['status'] == true) {
        final profileData =
            Map<String, dynamic>.from(data['data']);

        final photo =
            profileData['photo']?.toString();

        if (!mounted) return;

        setState(() {
          profile = profileData;

          if (photo != null && photo.isNotEmpty) {
            profileImageFuture =
                fetchProfileImage(photo);
          } else {
            profileImageFuture = null;
          }

          isLoading = false;
          hasError = false;
        });
      } else {
        throw Exception(
          data['message'] ??
              'Gagal mengambil data profile.',
        );
      }
    } catch (e) {
      if (!mounted) return;

      final message =
          e.toString().replaceAll('Exception: ', '');

      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = message;
      });

      _showModernSnackBar(
        message: message,
        isSuccess: false,
      );
    }
  }

  // profile

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

      if (response.statusCode == 200 &&
          response.bodyBytes.isNotEmpty) {
        return response.bodyBytes;
      }

      return null;
    } catch (e) {
      debugPrint('IMAGE ERROR: $e');
      return null;
    }
  }

  //...
  // LOGOUT
  //...

  Future<void> logout() async {
    final result = await _showLogoutDialog();

    if (result != true) return;

    try {
      final prefs =
          await SharedPreferences.getInstance();

      final token =
          prefs.getString('token');

      if (token == null || token.isEmpty) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        context.go(AppRoutes.login);
        return;
      }

      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 ||
          response.statusCode == 401) {
        await prefs.remove('token');
        await prefs.remove('user');

        if (!mounted) return;

        _showModernSnackBar(
          message: 'Logout berhasil.',
          isSuccess: true,
        );

        context.go(AppRoutes.login);
      } else {
        if (!mounted) return;

        _showModernSnackBar(
          message:
              'Logout gagal. Silakan coba lagi.',
          isSuccess: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      _showModernSnackBar(
        message:
            'Tidak dapat terhubung ke server.',
        isSuccess: false,
      );
    }
  }

// log out

  Future<bool?> _showLogoutDialog() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _ProfileTheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          contentPadding:
              const EdgeInsets.fromLTRB(
            24,
            24,
            24,
            20,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: _ProfileTheme.errorBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: _ProfileTheme.error,
                  size: 27,
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'Keluar Akun',
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color:
                      _ProfileTheme.textPrimary,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Apakah Anda yakin ingin keluar dari akun?',
                textAlign: TextAlign.center,
                style:
                    GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color:
                      _ProfileTheme.textSecondary,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 22),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.pop(
                        context,
                        false,
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        foregroundColor:
                            _ProfileTheme
                                .textSecondary,
                        side: const BorderSide(
                          color:
                              _ProfileTheme.border,
                        ),
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 12,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                      ),
                      child: Text(
                        'Batal',
                        style:
                            GoogleFonts
                                .plusJakartaSans(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),

                  Expanded(
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(
                        context,
                        true,
                      ),
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor:
                            _ProfileTheme.error,
                        foregroundColor:
                            Colors.white,
                        elevation: 0,
                        padding:
                            const EdgeInsets
                                .symmetric(
                          vertical: 12,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            10,
                          ),
                        ),
                      ),
                      child: Text(
                        'Keluar',
                        style:
                            GoogleFonts
                                .plusJakartaSans(
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w700,
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
// refresh
  Future<void> handleRefresh() async {
    await getProfile();
  }

 

  void _showModernSnackBar({
    required String message,
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess
            ? _ProfileTheme.success
            : _ProfileTheme.error,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        content: Row(
          children: [
            Icon(
              isSuccess
                  ? Icons.check_circle_rounded
                  : Icons.error_outline_rounded,
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
    final screenWidth =
        MediaQuery.sizeOf(context).width;

    final isWide =
        screenWidth >=
            _ProfileTheme.mobileBreakpoint;

    final maxWidth =
        _ProfileTheme.getMaxContentWidth(
      screenWidth,
    );

    final pagePadding =
        _ProfileTheme.getPagePadding(
      screenWidth,
    );

    return Scaffold(
      backgroundColor:
          _ProfileTheme.background,

      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: RefreshIndicator(
                color: _ProfileTheme.primary,
                backgroundColor:
                    _ProfileTheme.surface,
                onRefresh: handleRefresh,

                child: SingleChildScrollView(
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: pagePadding,

                  // PERUBAHAN 1: Center & ConstrainedBox dihapus agar full layar
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,

                    children: [
                      if (isLoading)
                        _buildLoadingState()
                      else if (hasError ||
                          profile == null)
                        _buildErrorState()
                      else ...[
                        _buildProfileCard(
                          isWide: isWide,
                        ),

                        const SizedBox(
                          height: 80,
                        ),

                        _buildActionSection(
                          isWide: isWide,
                        ),

                        const SizedBox(
                          height: 100,
                        ),
                      ],
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
        horizontal: 20,
        vertical: 16,
      ),

      decoration: const BoxDecoration(
        color: _ProfileTheme.surface,

        border: Border(
          bottom: BorderSide(
            color: _ProfileTheme.border,
            width: 1,
          ),
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _ProfileTheme.primaryLight,
              borderRadius:
                  BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.person_outline_rounded,
              color: _ProfileTheme.primary,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Text(
            'Profil Pengguna',
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color:
                  _ProfileTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // profile card

  Widget _buildProfileCard({
    required bool isWide,
  }) {
    final name =
        profile!['name']?.toString() ?? '-';

    final username =
        profile!['username']?.toString() ?? '-';

    final email =
        profile!['email']?.toString() ?? '-';

    final phone =
        profile!['phone']?.toString() ?? '-';

    String genderDisplay = '-';

    if (profile!['gender'] != null) {
      final gender =
          profile!['gender']
              .toString()
              .toLowerCase();

      if (gender.startsWith('l')) {
        genderDisplay = 'Laki-laki';
      } else if (gender.startsWith('p')) {
        genderDisplay = 'Perempuan';
      } else {
        genderDisplay =
            profile!['gender'].toString();
      }
    }

    final birthPlace =
        profile!['birth_place']?.toString() ??
            '-';

    final birthDate =
        profile!['birth_date']?.toString() ??
            '-';

    final photo =
        profile!['photo']?.toString();

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        color: _ProfileTheme.surface,
        borderRadius:
            BorderRadius.circular(
          _ProfileTheme.cardRadius,
        ),
        border: Border.all(
          color: _ProfileTheme.border,
        ),
      ),

      child: Column(
        children: [
          _buildAvatar(photo),

          const SizedBox(height: 14),

          Text(
            name.isNotEmpty ? name : '-',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 21,
              fontWeight: FontWeight.w700,
              color:
                  _ProfileTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            username.isNotEmpty
                ? '@$username'
                : '@-',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color:
                  _ProfileTheme.textSecondary,
            ),
          ),

          const SizedBox(height: 22),

          Container(
            width: double.infinity,
            height: 1,
            color: _ProfileTheme.border,
          ),

          const SizedBox(height: 18),

          if (isWide)
            _buildWideInfoGrid(
              username: username,
              email: email,
              phone: phone,
              gender: genderDisplay,
              birthPlace: birthPlace,
              birthDate: birthDate,
            )
          else
            _buildMobileInfoList(
              username: username,
              email: email,
              phone: phone,
              gender: genderDisplay,
              birthPlace: birthPlace,
              birthDate: birthDate,
            ),
        ],
      ),
    );
  }

//  info

  Widget _buildWideInfoGrid({
    required String username,
    required String email,
    required String phone,
    required String gender,
    required String birthPlace,
    required String birthDate,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                icon:
                    Icons.person_outline_rounded,
                label: 'Username',
                value: username,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildInfoItem(
                icon:
                    Icons.email_outlined,
                label: 'Email',
                value: email,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                icon:
                    Icons.phone_outlined,
                label: 'Nomor HP',
                value: phone,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildInfoItem(
                icon:
                    Icons.wc_outlined,
                label: 'Jenis Kelamin',
                value: gender,
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildInfoItem(
                icon:
                    Icons.location_on_outlined,
                label: 'Tempat Lahir',
                value: birthPlace,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _buildInfoItem(
                icon:
                    Icons.calendar_today_outlined,
                label: 'Tanggal Lahir',
                value: birthDate,
              ),
            ),
          ],
        ),
      ],
    );
  }

//  info mobile 

  Widget _buildMobileInfoList({
    required String username,
    required String email,
    required String phone,
    required String gender,
    required String birthPlace,
    required String birthDate,
  }) {
    return Column(
      children: [
        _buildInfoItem(
          icon: Icons.person_outline_rounded,
          label: 'Username',
          value: username,
        ),

        const SizedBox(height: 10),

        _buildInfoItem(
          icon: Icons.email_outlined,
          label: 'Email',
          value: email,
        ),

        const SizedBox(height: 10),

        _buildInfoItem(
          icon: Icons.phone_outlined,
          label: 'Nomor HP',
          value: phone,
        ),

        const SizedBox(height: 10),

        _buildInfoItem(
          icon: Icons.wc_outlined,
          label: 'Jenis Kelamin',
          value: gender,
        ),

        const SizedBox(height: 10),

        _buildInfoItem(
          icon: Icons.location_on_outlined,
          label: 'Tempat Lahir',
          value: birthPlace,
        ),

        const SizedBox(height: 10),

        _buildInfoItem(
          icon:
              Icons.calendar_today_outlined,
          label: 'Tanggal Lahir',
          value: birthDate,
        ),
      ],
    );
  }

  // item

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 12,
      ),

      decoration: BoxDecoration(
        color: _ProfileTheme.background,
        borderRadius:
            BorderRadius.circular(12),
        border: Border.all(
          color: _ProfileTheme.border,
        ),
      ),

      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,

            decoration: BoxDecoration(
              color:
                  _ProfileTheme.primaryLight,
              borderRadius:
                  BorderRadius.circular(10),
            ),

            child: Icon(
              icon,
              size: 18,
              color: _ProfileTheme.primary,
            ),
          ),

          const SizedBox(width: 11),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color:
                        _ProfileTheme.textMuted,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value.isNotEmpty
                      ? value
                      : '-',
                  softWrap: true,
                  style:
                      GoogleFonts.plusJakartaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color:
                        _ProfileTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
// section

  
  Widget _buildActionSection({
    required bool isWide,
  }) {
    final editButton =
        _buildEditProfileAction();

    final logoutButton =
        _buildLogoutAction();

    return Row(
      children: [
        Expanded(
          child: editButton,
        ),

        const SizedBox(width: 12),

        Expanded(
          child: logoutButton,
        ),
      ],
    );
  }

  // edit profile

  Widget _buildEditProfileAction() {
    return _buildActionCard(
      icon: Icons.edit_outlined,
      title: 'Edit Profil',
      subtitle: 'Perbarui data diri Anda',
      iconColor: _ProfileTheme.primary,
      iconBgColor: _ProfileTheme.primaryLight,
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                EditProfilePage(
              profile: profile,
            ),
          ),
        );

        if (result == true) {
          getProfile();
        }
      },
    );
  }

  // logout acton
  Widget _buildLogoutAction() {
    return _buildActionCard(
      icon: Icons.logout_rounded,
      title: 'Keluar Akun',
      subtitle: 'Logout dari sesi aplikasi',
      iconColor: _ProfileTheme.error,
      iconBgColor: _ProfileTheme.errorBg,
      isDestructive: true,
      onTap: logout,
    );
  }

  // aksi cardnya

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
    required Color iconBgColor,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _ProfileTheme.surface,
        borderRadius:
            BorderRadius.circular(
          _ProfileTheme.actionRadius,
        ),
        border: Border.all(
          color: _ProfileTheme.border,
        ),
      ),

      child: Material(
        color: Colors.transparent,

        child: InkWell(
          borderRadius:
              BorderRadius.circular(
            _ProfileTheme.actionRadius,
          ),
          onTap: onTap,

          child: Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 14,
            ),

            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,

                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius:
                        BorderRadius.circular(11),
                  ),

                  child: Icon(
                    icon,
                    size: 21,
                    color: iconColor,
                  ),
                ),

                const SizedBox(width: 13),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style:
                            GoogleFonts
                                .plusJakartaSans(
                          fontSize: 14,
                          fontWeight:
                              FontWeight.w700,
                          color: isDestructive
                              ? _ProfileTheme.error
                              : _ProfileTheme
                                  .textPrimary,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        subtitle,
                        style:
                            GoogleFonts
                                .plusJakartaSans(
                          fontSize: 11.5,
                          color: _ProfileTheme
                              .textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),

                Icon(
                  Icons
                      .arrow_forward_ios_rounded,
                  size: 13,
                  color:
                      _ProfileTheme.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // avatar

  Widget _buildAvatar(String? photo) {
    return Container(
      width: 96,
      height: 96,

      padding: const EdgeInsets.all(3),

      decoration: const BoxDecoration(
        color: _ProfileTheme.primary,
        shape: BoxShape.circle,
      ),

      child: ClipOval(
        child: photo != null &&
                photo.isNotEmpty
            ? FutureBuilder<Uint8List?>(
                future: profileImageFuture,

                builder:
                    (context, snapshot) {
                  if (snapshot
                          .connectionState ==
                      ConnectionState.waiting) {
                    return Container(
                      color: _ProfileTheme
                          .primaryLight,

                      child: const Center(
                        child:
                            SizedBox(
                          width: 22,
                          height: 22,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2.2,
                            valueColor:
                                AlwaysStoppedAnimation<
                                    Color>(
                              _ProfileTheme
                                  .primary,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  if (snapshot.hasData &&
                      snapshot.data != null) {
                    return Image.memory(
                      snapshot.data!,
                      width: 90,
                      height: 90,
                      fit: BoxFit.cover,
                    );
                  }

                  return Container(
                    color: _ProfileTheme
                        .primaryLight,
                    child: const Icon(
                      Icons.person_rounded,
                      size: 46,
                      color:
                          _ProfileTheme.primary,
                    ),
                  );
                },
              )
            : Container(
                color:
                    _ProfileTheme.primaryLight,
                child: const Icon(
                  Icons.person_rounded,
                  size: 46,
                  color: _ProfileTheme.primary,
                ),
              ),
      ),
    );
  }

 
  Widget _buildLoadingState() {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 80,
      ),

      child: Center(
        child: Column(
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child:
                  CircularProgressIndicator(
                strokeWidth: 2.5,
                color: _ProfileTheme.primary,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Memuat data profil...',
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color:
                    _ProfileTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  

  Widget _buildErrorState() {
    return Container(
      padding: const EdgeInsets.all(24),

      decoration: BoxDecoration(
        color: _ProfileTheme.surface,
        borderRadius:
            BorderRadius.circular(
          _ProfileTheme.cardRadius,
        ),
        border: Border.all(
          color: _ProfileTheme.border,
        ),
      ),

      child: Column(
        children: [
          Container(
            width: 58,
            height: 58,

            decoration: const BoxDecoration(
              color: _ProfileTheme.errorBg,
              shape: BoxShape.circle,
            ),

            child: const Icon(
              Icons.error_outline_rounded,
              size: 28,
              color: _ProfileTheme.error,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            errorMessage ??
                'Gagal memuat profil.',
            textAlign: TextAlign.center,
            style:
                GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color:
                  _ProfileTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 16),

          ElevatedButton.icon(
            onPressed: getProfile,

            style:
                ElevatedButton.styleFrom(
              backgroundColor:
                  _ProfileTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,

              padding:
                  const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 11,
              ),

              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(10),
              ),
            ),

            icon: const Icon(
              Icons.refresh_rounded,
              size: 18,
            ),

            label: Text(
              'Coba Lagi',
              style:
                  GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}