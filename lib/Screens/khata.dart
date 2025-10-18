import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'package:quickalert/widgets/quickalert_dialog.dart';
import 'package:raza_brothers/Services/GsheetApi.dart';
import 'package:raza_brothers/Widgets/Button.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

class KhataScreen extends StatefulWidget {
  const KhataScreen({super.key});

  @override
  State<KhataScreen> createState() => _KhataScreenState();
}

class _KhataScreenState extends State<KhataScreen> {
  List<Map<String, String>> filteredData = [];
  List<String> accountNames = []; // List for autocomplete suggestions
  TextEditingController searchController = TextEditingController();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    fetchAccountNames(); // Load available names for autocomplete
  }

  // Fetch all available names from Jama and Naam columns for suggestions
  Future<void> fetchAccountNames() async {
    final data = await UserSheetsApi.fetchAllRows();
    Set<String> namesSet = {}; // Use Set to avoid duplicates

    for (var row in data.skip(1)) {
      if (row.length > 1) namesSet.add(row[1].trim()); // Jama
      if (row.length > 3) namesSet.add(row[3].trim()); // Naam
    }

    setState(() {
      accountNames = namesSet.where((name) => name.isNotEmpty).toList();
    });
  }

  Future<void> fetchData(String khataName) async {
    setState(() => isLoading = true);
    final data = await UserSheetsApi.fetchAllRows();

    List<Map<String, String>> mappedData = data.skip(1).map((row) {
      return {
        "Date": row.isNotEmpty ? row[0].replaceAll("'", "").trim() : "",
        "Jama": row.length > 1 ? row[1].trim() : "",
        "Type": row.length > 2 ? row[2].trim() : "",
        "Naam": row.length > 3 ? row[3].trim() : "",
        "Amount": row.length > 4 ? row[4].trim() : "",
        "Details": row.length > 5 ? row[5].trim() : "",
      };
    }).toList();

    setState(() {
      filteredData = mappedData
          .where((entry) =>
              entry["Naam"]?.toLowerCase() == khataName.toLowerCase() ||
              entry["Jama"]?.toLowerCase() == khataName.toLowerCase())
          .toList();

      // Sort the filtered data by Date in descending order
      filteredData.sort((a, b) {
        DateTime dateA = _parseDate(a["Date"] ?? "");
        DateTime dateB = _parseDate(b["Date"] ?? "");
        return dateB.compareTo(dateA); // Descending order
      });

      isLoading = false;
    });
  }

  // Helper function to parse the date
  DateTime _parseDate(String dateString) {
    try {
      return DateFormat("dd-MM-yyyy").parse(dateString);
    } catch (e) {
      return DateTime(2000, 1, 1); // Default fallback date
    }
  }

  String formatDate(String date) {
    if (date.isNotEmpty && date.contains("-")) {
      List<String> parts = date.split("-");
      if (parts.length >= 2) {
        return "${parts[0]}-${parts[1]}"; // Extracts only DD-MM
      }
    }
    return date; // Return original if format is incorrect
  }

  // ================= PDF / Print Helpers =================

  // ✅ Generate & Save PDF
  Future<void> _saveKhataAsPdf(String accountName) async {
    final pdf = pw.Document();

    // Prepare running balances and totals **based on filteredData**
    List<double> balances = [];
    double runningBalance = 0.0;
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    // We assume filteredData is in descending order (latest first), but
    // for running balance we want to process oldest first to compute progressive balance
    final List<Map<String, String>> oldestFirst =
        filteredData.reversed.toList();

    for (var entry in oldestFirst) {
      double amount = double.tryParse(entry["Amount"] ?? "0") ?? 0.0;
      bool isDebit = entry["Naam"]?.toLowerCase() == accountName.toLowerCase();
      bool isCredit = entry["Jama"]?.toLowerCase() == accountName.toLowerCase();

      if (isDebit) {
        runningBalance -= amount;
        totalDebit += amount;
      } else if (isCredit) {
        runningBalance += amount;
        totalCredit += amount;
      }

      balances.add(runningBalance);
    }

    // Convert balances back to same order as filteredData (descending)
    final List<double> balancesForPdf = balances.reversed.toList();

    // Build table rows in the same order as filteredData
    final tableRows = List.generate(filteredData.length, (index) {
      final entry = filteredData[index];
      double amount = double.tryParse(entry["Amount"] ?? "0") ?? 0.0;
      bool isDebit = entry["Naam"]?.toLowerCase() == accountName.toLowerCase();
      bool isCredit = entry["Jama"]?.toLowerCase() == accountName.toLowerCase();

      return [
        entry["Date"] ?? "---",
        entry["Details"] ?? "---",
        isDebit ? amount.toStringAsFixed(0) : "---",
        isCredit ? amount.toStringAsFixed(0) : "---",
        balancesForPdf[index].toStringAsFixed(0),
      ];
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              "Khata Account: $accountName",
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
              "Generated on: ${DateFormat('dd-MM-yyyy HH:mm').format(DateTime.now())}"),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ["Date", "Details", "Debit", "Credit", "Balance"],
            data: tableRows,
            border: pw.TableBorder.all(),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            cellStyle: const pw.TextStyle(fontSize: 10),
            cellAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("Total Debit: Rs. ${totalDebit.toStringAsFixed(0)}"),
              pw.Text("Total Credit: Rs. ${totalCredit.toStringAsFixed(0)}"),
              pw.Text(
                  "Closing Balance: Rs. ${runningBalance.toStringAsFixed(0)}"),
            ])
          ]),
        ],
      ),
    );

    // Save to visible folder on Android or application folder otherwise
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory("/storage/emulated/0/Download");
      if (!await dir.exists()) {
        dir = await getApplicationDocumentsDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final safeName = accountName.isEmpty
        ? "khata"
        : accountName.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    final file = File(
        "${dir.path}/khata_${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());

    // Open the saved file
    await OpenFilex.open(file.path);
  }

  // ✅ Print PDF directly
  Future<void> _printKhata(String accountName) async {
    final pdf = pw.Document();

    // Compute balances and totals same as save method
    List<double> balances = [];
    double runningBalance = 0.0;
    double totalDebit = 0.0;
    double totalCredit = 0.0;

    final List<Map<String, String>> oldestFirst =
        filteredData.reversed.toList();

    for (var entry in oldestFirst) {
      double amount = double.tryParse(entry["Amount"] ?? "0") ?? 0.0;
      bool isDebit = entry["Naam"]?.toLowerCase() == accountName.toLowerCase();
      bool isCredit = entry["Jama"]?.toLowerCase() == accountName.toLowerCase();

      if (isDebit) {
        runningBalance -= amount;
        totalDebit += amount;
      } else if (isCredit) {
        runningBalance += amount;
        totalCredit += amount;
      }
      balances.add(runningBalance);
    }

    final List<double> balancesForPdf = balances.reversed.toList();

    final tableRows = List.generate(filteredData.length, (index) {
      final entry = filteredData[index];
      double amount = double.tryParse(entry["Amount"] ?? "0") ?? 0.0;
      bool isDebit = entry["Naam"]?.toLowerCase() == accountName.toLowerCase();
      bool isCredit = entry["Jama"]?.toLowerCase() == accountName.toLowerCase();

      return [
        entry["Date"] ?? "---",
        entry["Details"] ?? "---",
        isDebit ? amount.toStringAsFixed(0) : "---",
        isCredit ? amount.toStringAsFixed(0) : "---",
        balancesForPdf[index].toStringAsFixed(0),
      ];
    });

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          pw.Center(
            child: pw.Text(
              "Khata Account: $accountName",
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Table.fromTextArray(
            headers: ["Date", "Details", "Debit", "Credit", "Balance"],
            data: tableRows,
            border: pw.TableBorder.all(),
            cellStyle: const pw.TextStyle(fontSize: 10),
            headerStyle:
                pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            cellAlignment: pw.Alignment.center,
            columnWidths: {
              0: const pw.FlexColumnWidth(1),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(1),
              3: const pw.FlexColumnWidth(1),
              4: const pw.FlexColumnWidth(1),
            },
          ),
          pw.SizedBox(height: 12),
          pw.Divider(),
          pw.SizedBox(height: 6),
          pw.Row(mainAxisAlignment: pw.MainAxisAlignment.end, children: [
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text("Total Debit: Rs. ${totalDebit.toStringAsFixed(0)}"),
              pw.Text("Total Credit: Rs. ${totalCredit.toStringAsFixed(0)}"),
              pw.Text(
                  "Closing Balance: Rs. ${runningBalance.toStringAsFixed(0)}"),
            ])
          ]),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  // ======================================================

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double screenHeight = MediaQuery.of(context).size.height;

    // Precompute running balances in correct order (oldest first)
    double runningBalance = 0.0;
    List<double> runningBalances = [];

    for (int i = filteredData.length - 1; i >= 0; i--) {
      final entry = filteredData[i];
      double amount = double.tryParse(entry["Amount"] ?? "0") ?? 0.0;

      bool isDebit =
          entry["Naam"]?.toLowerCase() == searchController.text.toLowerCase();
      bool isCredit =
          entry["Jama"]?.toLowerCase() == searchController.text.toLowerCase();

      if (isDebit) {
        runningBalance -= amount;
      } else if (isCredit) {
        runningBalance += amount;
      }

      runningBalances.insert(
          0, runningBalance); // Insert at index 0 to maintain order
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        title:
            const Text("Khata Accounts", style: TextStyle(color: Colors.black)),
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          const Text(
            'Download Khata : ',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () {
              if (filteredData.isNotEmpty) {
                final acct = searchController.text.trim();
                _saveKhataAsPdf(acct.isEmpty ? "Account" : acct);
              }
            },
          ),
          const SizedBox(
            width: 50,
          ),
          const Text(
            'Print Khata : ',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              if (filteredData.isNotEmpty) {
                final acct = searchController.text.trim();
                _printKhata(acct.isEmpty ? "Account" : acct);
              }
            },
          ),
          const SizedBox(
            width: 20,
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    width: screenWidth * 0.75,
                    height: screenHeight * 0.070,
                    child: Autocomplete<String>(
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        if (textEditingValue.text.isEmpty)
                          return const Iterable<String>.empty();
                        return accountNames.where((name) => name
                            .toLowerCase()
                            .contains(textEditingValue.text.toLowerCase()));
                      },
                      onSelected: (String selected) {
                        searchController.text = selected;
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onEditingComplete) {
                        searchController = controller;
                        return TextField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          decoration: InputDecoration(
                            hintText: "Search Khata",
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: screenWidth * 0.30,
                  height: screenHeight * 0.070,
                  child:
                      Button_Widget(context, 'Search', Colors.black, () async {
                    if (searchController.text.isNotEmpty) {
                      fetchData(searchController.text.trim());
                    } else {
                      QuickAlert.show(
                        context: context,
                        type: QuickAlertType.error,
                        title: 'No Text Found',
                        text: 'Kindly Write a Khata Name',
                      );
                    }
                  }),
                ),
              ],
            ),
          ),
          isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredData.isNotEmpty
                  ? Expanded(
                      child: Column(
                        children: [
                          // 🔹 Header Row
                          const Padding(
                            padding: EdgeInsets.symmetric(
                                vertical: 8, horizontal: 10),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Center(
                                    child: Text(
                                      "Date",
                                      style: TextStyle(
                                          fontSize: 25, color: Colors.black),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Details",
                                      style: TextStyle(
                                          fontSize: 25, color: Colors.black),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Debit",
                                      style: TextStyle(
                                          fontSize: 25, color: Colors.green),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Credit",
                                      style: TextStyle(
                                          fontSize: 25, color: Colors.red),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  flex: 2,
                                  child: Center(
                                    child: Text(
                                      "Balance",
                                      style: TextStyle(
                                          fontSize: 25, color: Colors.blue),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Divider(thickness: 2),

                          // 🔹 The Scrollable List
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final entry = filteredData[index];
                                double amount =
                                    double.tryParse(entry["Amount"] ?? "0") ??
                                        0.0;
                                bool isDebit = entry["Naam"]?.toLowerCase() ==
                                    searchController.text.toLowerCase();
                                bool isCredit = entry["Jama"]?.toLowerCase() ==
                                    searchController.text.toLowerCase();

                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 8, horizontal: 10),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: Text(
                                                formatDate(
                                                    entry["Date"] ?? "---"),
                                                style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.020),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              '${entry["Details"] ?? "---"} - ${searchController.text == entry["Naam"] ? entry["Jama"] : searchController.text == "${entry["Jama"]}" ? entry["Naam"] : ""}',
                                              maxLines: 3,
                                              style: TextStyle(
                                                  fontSize:
                                                      screenWidth * 0.010),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                isCredit
                                                    ? amount.toStringAsFixed(0)
                                                    : "---",
                                                style: TextStyle(
                                                    fontSize: isCredit
                                                        ? screenWidth * 0.025
                                                        : screenWidth * 0.015,
                                                    color: Colors.green),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                isDebit
                                                    ? amount.toStringAsFixed(0)
                                                    : "---",
                                                style: TextStyle(
                                                    fontSize: isDebit
                                                        ? screenWidth * 0.025
                                                        : screenWidth * 0.015,
                                                    color: Colors.red),
                                              ),
                                            ),
                                          ),
                                          Expanded(
                                            flex: 2,
                                            child: Center(
                                              child: Text(
                                                runningBalances[index] >= 0
                                                    ? "${runningBalances[index].toStringAsFixed(0).replaceAll('+', '')} DR"
                                                    : "${runningBalances[index].toStringAsFixed(0).replaceAll('-', '')} CR",
                                                style: TextStyle(
                                                    fontSize:
                                                        screenWidth * 0.025,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.blue),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Divider(),
                                  ],
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    )
                  : const Center(
                      child: Text("No matching records found",
                          style: TextStyle(fontSize: 18, color: Colors.red)),
                    ),
        ],
      ),
    );
  }
}
