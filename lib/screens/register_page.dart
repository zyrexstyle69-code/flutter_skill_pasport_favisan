import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

class _RegisterTheme {
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
}

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  // controller
  final _formKey = GlobalKey<FormState>();
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();

  // state
  String? gender;
  bool isLoading = false;

  // register
  Future<void> register() async {
    if (!_formKey.currentState!.validate()) return;

    if (gender == null) {
      _showSnackBar(
        message: 'Silakan pilih jenis kelamin.',
        isSuccess: false,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('https://sijala.biz.id/api/v1/register'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'name': nameController.text.trim(),
          'gender': gender,
          'email': emailController.text.trim(),
          'phone': phoneController.text.trim(),
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (data['status'] == true) {
          if (!mounted) return;

          _showSnackBar(
            message: data['message'] ?? 'Registrasi berhasil. Silakan login.',
            isSuccess: true,
          );

          Navigator.pop(context);
        } else {
          throw Exception(data['message'] ?? 'Registrasi gagal.');
        }
      } else {
        final message = data['message'] ?? 'Registrasi gagal.';
        throw Exception(message);
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar(
        message: e.toString().replaceFirst('Exception: ', ''),
        isSuccess: false,
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  // snackbar
  void _showSnackBar({
    required String message,
    required bool isSuccess,
  }) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isSuccess ? _RegisterTheme.success : _RegisterTheme.error,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        content: Row(
          children: [
            Icon(
              isSuccess ? Icons.check_circle_outline : Icons.error_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // dispose
  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  // build
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _RegisterTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(),
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 20,
                  ),
                    child: _buildRegisterCard(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // top bar
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: _RegisterTheme.textPrimary,
            ),
          ),
          const SizedBox(width: 2),
          Text(
            'Daftar Akun',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _RegisterTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // card
  Widget _buildRegisterCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _RegisterTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _RegisterTheme.border),
      ),
      
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // icon header
            Container(
            ),
            const SizedBox(height: 18),
            Text(
              'Buat Akun',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _RegisterTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Lengkapi data untuk membuat akun baru.',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                color: _RegisterTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 25),

            // nama
            _buildNameField(),
            const SizedBox(height: 16),

            // gender
            _buildGenderField(),
            const SizedBox(height: 16),

            // email
            _buildEmailField(),
            const SizedBox(height: 16),

            // phone
            _buildPhoneField(),
            const SizedBox(height: 24),

            // button
            _buildSubmitButton(),
          ],
        ),
      ),
    );
  }

  // name
  Widget _buildNameField() {
    return _buildTextField(
      label: 'Nama Lengkap',
      hint: 'Masukkan nama lengkap',
      icon: Icons.person_outline,
      controller: nameController,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nama wajib diisi';
        }
        return null;
      },
    );
  }

  // gender
  Widget _buildGenderField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Jenis Kelamin',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _RegisterTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        DropdownButtonFormField<String>(
          initialValue: gender,
          onChanged: isLoading
              ? null
              : (value) {
                  setState(() => gender = value);
                },
          items: const [
            DropdownMenuItem(value: 'L', child: Text('Laki-laki')),
            DropdownMenuItem(value: 'P', child: Text('Perempuan')),
          ],
          decoration: InputDecoration(
            hintText: 'Pilih jenis kelamin',
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _RegisterTheme.textMuted,
            ),
            prefixIcon: const Icon(
              Icons.wc_outlined,
              color: _RegisterTheme.primary,
              size: 20,
            ),
            filled: true,
            fillColor: _RegisterTheme.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _RegisterTheme.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterTheme.error),
            ),
          ),
          validator: (value) {
            if (value == null) return 'Jenis kelamin wajib dipilih';
            return null;
          },
        ),
      ],
    );
  }

  // email
  Widget _buildEmailField() {
    return _buildTextField(
      label: 'Email',
      hint: 'nama@email.com',
      icon: Icons.email_outlined,
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.next,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Email wajib diisi';
        }
        if (!value.contains('@')) return 'Format email tidak valid';
        return null;
      },
    );
  }

  // phone
  Widget _buildPhoneField() {
    return _buildTextField(
      label: 'Nomor WhatsApp',
      hint: '08xxxxxxxxxx',
      icon: Icons.phone_outlined,
      controller: phoneController,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      onFieldSubmitted: (_) {
        if (!isLoading) register();
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Nomor WhatsApp wajib diisi';
        }
        return null;
      },
    );
  }

  // text field
  Widget _buildTextField({
    required String label,
    required String hint,
    required IconData icon,
    required TextEditingController controller,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
    void Function(String)? onFieldSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: _RegisterTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          enabled: !isLoading,
          onFieldSubmitted: onFieldSubmitted,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: _RegisterTheme.textPrimary,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: _RegisterTheme.textMuted,
            ),
            prefixIcon: Icon(
              icon,
              color: _RegisterTheme.primary,
              size: 20,
            ),
            filled: true,
            fillColor: _RegisterTheme.inputBackground,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterTheme.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _RegisterTheme.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _RegisterTheme.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: _RegisterTheme.error,
                width: 1.5,
              ),
            ),
            errorStyle: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              color: _RegisterTheme.error,
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  // button
  Widget _buildSubmitButton() {
    return SizedBox(
      height: 50,
      child: ElevatedButton(
        onPressed: isLoading ? null : register,
        style: ElevatedButton.styleFrom(
          backgroundColor: _RegisterTheme.primary,
          disabledBackgroundColor: _RegisterTheme.primary.withOpacity(0.5),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Daftar Sekarang',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 7),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
      ),
    );
  }
}