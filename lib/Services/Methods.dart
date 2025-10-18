import 'package:flutter/material.dart';
import 'package:raza_brothers/Services/GsheetApi.dart';

class Methods {
  // Main Screen pr show hona wala Card Logo
  showSlogan(BuildContext context) {
    double width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: SizedBox(
        height: 300,
        width: width / 2.5, //desktop 2.5 - mobile 1
        child: Card(
          semanticContainer: true,
          clipBehavior: Clip.antiAliasWithSaveLayer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.0),
          ),
          elevation: 10,
          margin: const EdgeInsets.all(10),
          child: Image.asset(
            'assets/logo.jpg',
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  } //End Here

  // Navigate Method
  void navigateTo(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => screen),
    );
  } // End Here

  // Bank Names Where Accounts are Registered
  Map<String, double> getInitialAccountBalances() {
    return {
      "Ali Raza Allied": 0.0,
      "Raza Brothers Allied": 0.0,
      "Ghulam Asghar Allied": 0.0,
      "Ali Raza EasyPaisa": 0.0,
      "Ali Raza JazzCash": 0.0,
      "Dukan Cash": 0.0
    };
  }

// Start Checking Account Balances
  Future<Map<String, double>> fetchBalances(Set<String> accountKeys) async {
    final data = await UserSheetsApi.fetchAllRows();
    Map<String, double> newBalances =
        Map.fromIterable(accountKeys, value: (_) => 0.0);

    for (var row in data.skip(1)) {
      if (row.length < 5) continue;

      final amount = double.tryParse(row[4].trim()) ?? 0.0;
      final jama = row[1].trim();
      final naam = row[3].trim();

      if (accountKeys.contains(jama)) {
        newBalances[jama] = newBalances[jama]! + amount;
      }
      if (accountKeys.contains(naam)) {
        newBalances[naam] = newBalances[naam]! - amount;
      }
    }

    return newBalances;
  } // End Here
}
