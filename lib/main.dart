import 'package:flutter/material.dart';

import 'pages/receipt_home_page.dart';

void main() => runApp(const ReceiptScannerApp());

class ReceiptScannerApp extends StatelessWidget {
  const ReceiptScannerApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Receipt Scanner',
    themeMode: ThemeMode.system,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.teal,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    ),
    home: const ReceiptHomePage(),
  );
}
