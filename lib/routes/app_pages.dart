import 'package:flutter_appl_latihan/models/survey.dart';
import 'package:flutter_appl_latihan/routes/app_routes.dart';
import 'package:flutter_appl_latihan/screens/dashboard.dart';
import 'package:flutter_appl_latihan/screens/edit_profile.dart';
import 'package:flutter_appl_latihan/screens/login_page.dart';
import 'package:flutter_appl_latihan/screens/register_page.dart';
import 'package:flutter_appl_latihan/screens/splash_screen.dart';
import 'package:flutter_appl_latihan/screens/survey_detail_page.dart';
import 'package:flutter_appl_latihan/screens/survey_form_page.dart';
import 'package:go_router/go_router.dart';

class AppPages {
  static final router = GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => SplashScreen(),
      ),
      GoRoute(path: AppRoutes.login, builder: (context, state) => LoginPage()),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => RegisterPage(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, state) => Dashboard(),
      ),
      GoRoute(
        path: AppRoutes.editProfile,
        builder: (context, state) =>
            EditProfilePage(profile: state.extra as Map<String, dynamic>?),
      ),
      GoRoute(
        path: AppRoutes.addSurvey,
        builder: (context, state) => SurveyFormPage(
          survey: state.extra is Survey ? state.extra as Survey : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.editSurvey,
        builder: (context, state) => SurveyFormPage(
          survey: state.extra is Survey ? state.extra as Survey : null,
        ),
      ),
      GoRoute(
        path: AppRoutes.surveyDetail,
        builder: (context, state) {
          int parsedId = 0;
          final extra = state.extra;

          if (extra is int) {
            parsedId = extra;
          } else if (extra is String) {
            parsedId = int.tryParse(extra) ?? 0;
          } else if (extra is Map) {
            parsedId = int.tryParse(extra['id']?.toString() ?? '') ?? 0;
          } else if (state.uri.queryParameters['id'] != null) {
            parsedId = int.tryParse(state.uri.queryParameters['id']!) ?? 0;
          } else if (state.pathParameters['id'] != null) {
            parsedId = int.tryParse(state.pathParameters['id']!) ?? 0;
          }

          return SurveyDetailPage(surveyId: parsedId);
        },
      ),
    ],
  );
}
