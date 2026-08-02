import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mobile_app/config/routes/app_routes.dart';
import 'package:mobile_app/core/theme/app_theme.dart';
import 'package:mobile_app/services/auth_service.dart';
import 'package:mobile_app/services/permission_service.dart';
import 'package:mobile_app/services/location_service.dart';
import 'package:mobile_app/services/device_service.dart';
import 'package:mobile_app/services/auto_upload_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>(create: (_) => AuthService()),
        Provider<PermissionService>(create: (_) => PermissionService()),
        Provider<LocationService>(create: (_) => LocationService()),
        Provider<DeviceService>(create: (_) => DeviceService()),
        Provider<AutoUploadService>(create: (_) => AutoUploadService()),
      ],
      child: MaterialApp(
        title: 'Video Platform',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generateRoute,
      ),
    );
  }
}
