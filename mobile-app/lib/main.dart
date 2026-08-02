import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'services/auth_service.dart';
import 'services/permission_service.dart';
import 'services/location_service.dart';
import 'services/device_service.dart';
import 'services/auto_upload_service.dart';

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
        ChangeNotifierProvider(create: (_) => AuthService()),
        Provider(create: (_) => PermissionService()),
        Provider(create: (_) => LocationService()),
        Provider(create: (_) => DeviceService()),
        Provider(create: (_) => AutoUploadService()),
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
