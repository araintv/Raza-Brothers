import 'package:flutter/material.dart';

Widget TextInputField_Widget(BuildContext context, String hintText,
    TextInputType textType, TextEditingController controller) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      hoverColor: Colors.blueAccent,
      hintText: hintText,
    ),
    textAlign: TextAlign.left,
    keyboardType: textType,
    style: const TextStyle(
        color: Colors.black, fontSize: 12.0, fontStyle: FontStyle.normal),
  );
}
