import 'package:material_ui/material_ui.dart';

import 'app/theme/app_theme.dart';
import 'features/home/presentation/pages/home_page.dart';

void main() {
  runApp(const GetKejaApp());
}

class GetKejaApp extends StatelessWidget {
  const GetKejaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GetKeja',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const HomePage(),
    );
  }
}
