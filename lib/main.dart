import 'package:flutter/material.dart';
import 'package:raza_brothers/Screens/Options.dart';
import 'package:raza_brothers/Services/GsheetApi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Iniatlize the Google Sheet Here
  await UserSheetsApi.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Raza Brother',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const OptionsScreen(),
      // home: DuePaymentScreen(),
      // home: OptionsScreen(),
      // home: const HomePage(),
      // home: DailyCashBook(),
      // home: KhataScreen(),
    );
  }
}
