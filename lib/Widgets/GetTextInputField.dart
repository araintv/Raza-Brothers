import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

Widget GetTextInputField_Widget(BuildContext context, String title,
    TextInputType textType, TextEditingController controller) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(
        height: 5,
      ),
      Text(
        title,
        style: GoogleFonts.poppins(),
      ),
      const SizedBox(
        height: 10,
      ),
      TextField(
        controller: controller,
        decoration: InputDecoration(
          border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(10)),
              borderSide: BorderSide.none),
          filled: true,
          fillColor: Colors.grey[100],
          hoverColor: Colors.blueAccent,
        ),
        textAlign: TextAlign.left,
        keyboardType: textType,
        style: GoogleFonts.poppins(
            color: Colors.black, fontSize: 12.0, fontStyle: FontStyle.normal),
      ),
    ],
  );
}
