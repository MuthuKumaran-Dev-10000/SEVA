import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DivineTheme {
  // Theme Colors
  static const Color maroon = Color(0xFF5A0E1A);
  static const Color saffron = Color(0xFFFF9933);
  static const Color gold = Color(0xFFD4AF37);
  static const Color cream = Color(0xFFFDFBF7);
  static const Color creamDark = Color(0xFFF5EFEB);
  static const Color textDark = Color(0xFF2C3E50);
  static const Color textLight = Color(0xFF7F8C8D);

  // Soft glow representing the divine light (diya)
  static List<BoxShadow> get diyaGlow => [
        BoxShadow(
          color: saffron.withOpacity(0.25),
          blurRadius: 15,
          spreadRadius: 2,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get softShadow => [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ThemeData getter
  static ThemeData get themeData {
    return ThemeData(
      primaryColor: maroon,
      colorScheme: const ColorScheme.light(
        primary: maroon,
        secondary: saffron,
        surface: cream,
        error: Colors.redAccent,
      ),
      scaffoldBackgroundColor: cream,
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.cinzel(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: maroon,
        ),
        displayMedium: GoogleFonts.cinzel(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: maroon,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: maroon,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 16,
          color: textDark,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: textDark,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: maroon,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: maroon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: gold.withOpacity(0.5)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: creamDark, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: saffron, width: 2),
        ),
        labelStyle: const TextStyle(color: maroon),
      ),
    );
  }
}

// A custom clipper that makes a beautiful temple-inspired arch in the headers
class TempleArchClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height - 40);

    // Left arch curve
    var firstControlPoint = Offset(size.width * 0.25, size.height);
    var firstEndPoint = Offset(size.width * 0.5, size.height - 25);
    path.quadraticBezierTo(
      firstControlPoint.dx,
      firstControlPoint.dy,
      firstEndPoint.dx,
      firstEndPoint.dy,
    );

    // Right arch curve
    var secondControlPoint = Offset(size.width * 0.75, size.height);
    var secondEndPoint = Offset(size.width, size.height - 40);
    path.quadraticBezierTo(
      secondControlPoint.dx,
      secondControlPoint.dy,
      secondEndPoint.dx,
      secondEndPoint.dy,
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
