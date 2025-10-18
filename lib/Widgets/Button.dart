import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget Button_Widget(
    BuildContext context, String btnTitle, Color color, Function onClick) {
  return ElevatedButton(
    onPressed: () {
      onClick();
    },
    style: ElevatedButton.styleFrom(
      backgroundColor: color,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    child: Text(
      btnTitle,
      textAlign: TextAlign.center,
      style: GoogleFonts.poppins(color: Colors.white),
    ),
  );
}
