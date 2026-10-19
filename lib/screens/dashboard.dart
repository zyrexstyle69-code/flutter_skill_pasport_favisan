
import 'package:flutter/material.dart';

import 'package:flutter_appl_latihan/screens/home_page.dart';
import 'package:flutter_appl_latihan/screens/profile_page.dart';
import 'package:flutter_appl_latihan/screens/survey_page.dart';

import 'package:google_fonts/google_fonts.dart';

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int _selectedIndex = 0;

  final pages = const [
    HomePage(),
    SurveyPage(),
    ProfilePage(),
  ];

  static const Color primaryColor = Color(0xFF7A1025);
  static const Color backgroundColor = Color(0xFFFCF8F9);
  static const Color textColor = Color(0xFF1E293B);
  static const Color mutedColor = Color(0xFF94A3B8);
  static const Color borderColor = Color(0xFFE2E8F0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,

      extendBody: true,

      body: pages[_selectedIndex],

      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 12,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 15,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                index: 0,
                activeIcon: Icons.home_rounded,
                inactiveIcon: Icons.home_outlined,
                label: 'Home',
              ),

              _buildNavItem(
                index: 1,
                activeIcon: Icons.assignment_rounded,
                inactiveIcon: Icons.assignment_outlined,
                label: 'Survey',
              ),

              _buildNavItem(
                index: 2,
                activeIcon: Icons.person_rounded,
                inactiveIcon: Icons.person_outline_rounded,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
  }) {
    final isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
      },

      borderRadius: BorderRadius.circular(14),

      splashColor: primaryColor.withOpacity(0.08),

      highlightColor: Colors.transparent,

      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,

        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 14 : 12,
          vertical: 9,
        ),

        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withOpacity(0.10)
              : Colors.transparent,

          borderRadius: BorderRadius.circular(14),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,

              color: isSelected
                  ? primaryColor
                  : mutedColor,

              size: 22,
            ),

            if (isSelected) ...[
              const SizedBox(width: 7),

              Text(
                label,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

