import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:raza_brothers/Components/snackBar.dart';
import 'package:raza_brothers/Services/GsheetApi.dart';
import 'package:raza_brothers/Widgets/DuePaymentWidget.dart';
import 'package:share_plus/share_plus.dart';

class DuePaymentScreen extends StatefulWidget {
  const DuePaymentScreen({super.key});

  @override
  State<DuePaymentScreen> createState() => _DuePaymentScreenState();
}

class _DuePaymentScreenState extends State<DuePaymentScreen> {
  List<Map<String, String>> allData = [];
  List<Map<String, String>> filteredData = [];
  Map<String, List<String>> groupedData = {}; // Grouped Dues
  bool isLoading = true;
  Set<String> selectedAccounts = {};
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    fetchDuePayments();
    searchController.addListener(_filterData);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterData);
    searchController.dispose();
    super.dispose();
  }

  Future<void> fetchDuePayments() async {
    setState(() => isLoading = true);
    final data = await UserSheetsApi.fetchAllRows();

    Map<String, List<Map<String, dynamic>>> accountDetails = {};

    // Date format definition for parsing
    DateFormat dateFormat = DateFormat("dd-MM-yyyy");
    for (var row in data.skip(1)) {
      String date = row.isNotEmpty ? row[0].trim() : "Unknown Date";
      String? jamaName = row.length > 1 ? row[1].trim() : null;
      String? naamName = row.length > 3 ? row[3].trim() : null;
      double amount =
          row.length > 4 ? (double.tryParse(row[4].trim()) ?? 0.0) : 0.0;

      if (naamName != null && naamName.isNotEmpty) {
        accountDetails.putIfAbsent(naamName, () => []);
        accountDetails[naamName]!
            .add({"type": "due", "date": date, "amount": amount});
      }
      if (jamaName != null && jamaName.isNotEmpty) {
        accountDetails.putIfAbsent(jamaName, () => []);
        accountDetails[jamaName]!
            .add({"type": "paid", "date": date, "amount": amount});
      }
    }

    Map<String, List<Map<String, dynamic>>> partialsMap = {};

    accountDetails.forEach((account, transactions) {
      double totalDue = 0.0;

      List<Map<String, dynamic>> dues = [];
      List<Map<String, dynamic>> payments = [];

      for (var txn in transactions) {
        if (txn["type"] == "due") {
          dues.add(txn);
          totalDue += txn["amount"];
        } else if (txn["type"] == "paid") {
          payments.add(txn);
        }
      }

      // Apply payments to dues from earliest first
      dues.sort((a, b) {
        String dateA = a["date"];
        String dateB = b["date"];

        if (dateA.isEmpty || dateB.isEmpty)
          return 0; // Handle empty dates gracefully

        try {
          DateTime parsedDateA = dateFormat.parse(dateA);
          DateTime parsedDateB = dateFormat.parse(dateB);
          return parsedDateA.compareTo(
              parsedDateB); // Compare by full date (day, month, year)
        } catch (e) {
          return 0; // Return 0 if there is an error parsing the date (it won't affect sorting)
        }
      });

      payments.sort((a, b) {
        String dateA = a["date"];
        String dateB = b["date"];

        if (dateA.isEmpty || dateB.isEmpty)
          return 0; // Handle empty dates gracefully

        try {
          DateTime parsedDateA = dateFormat.parse(dateA);
          DateTime parsedDateB = dateFormat.parse(dateB);
          return parsedDateA.compareTo(
              parsedDateB); // Compare by full date (day, month, year)
        } catch (e) {
          return 0; // Return 0 if there is an error parsing the date (it won't affect sorting)
        }
      });

      for (var payment in payments) {
        double paymentAmount = payment["amount"];
        for (var due in dues) {
          if (paymentAmount <= 0) break;
          if (due["amount"] <= 0) continue;

          if (paymentAmount >= due["amount"]) {
            paymentAmount -= due["amount"];
            due["amount"] = 0.0;
          } else {
            due["amount"] -= paymentAmount;
            paymentAmount = 0.0;
          }
        }
      }

      // Get unpaid dues and apply the reverse partial logic
      List<Map<String, dynamic>> unpaidDues =
          dues.where((d) => d["amount"] > 0).toList();

      unpaidDues.sort((a, b) {
        String dateA = a["date"];
        String dateB = b["date"];

        if (dateA.isEmpty || dateB.isEmpty)
          return 0; // Handle empty dates gracefully

        try {
          DateTime parsedDateA = dateFormat.parse(dateA);
          DateTime parsedDateB = dateFormat.parse(dateB);
          return parsedDateB
              .compareTo(parsedDateA); // Sort from newest to oldest
        } catch (e) {
          return 0; // Return 0 if there is an error parsing the date (it won't affect sorting)
        }
      });

      double remaining = unpaidDues.fold(0.0, (sum, d) => sum + d["amount"]);
      double totalToCover = remaining;

      List<Map<String, dynamic>> partials = [];

      for (var due in unpaidDues) {
        if (totalToCover <= 0) break;

        double dueAmount = due["amount"];
        if (totalToCover >= dueAmount) {
          partials.add({"date": due["date"], "amount": dueAmount});
          totalToCover -= dueAmount;
        } else {
          partials.add({"date": due["date"], "amount": totalToCover});
          totalToCover = 0;
        }
      }

      // Reverse to show oldest partial first
      partials = partials.reversed.toList();

      if (remaining >= 1000) {
        partialsMap[account] = partials;
      }
    });

    // Prepare display data
    Map<String, List<String>> groupedData = {};
    List<Map<String, String>> allData = [];

    for (var entry in partialsMap.entries) {
      String accountName = entry.key;
      List<String> dueEntries = entry.value
          .map((due) => "${due["date"]} - ${due["amount"].toStringAsFixed(0)}")
          .toList();

      groupedData[accountName] = dueEntries;

      for (var due in entry.value) {
        allData.add({
          "Name": accountName,
          "Date": due["date"].toString(),
          "Due Amount": (due["amount"] as num).toStringAsFixed(0),
        });
      }
    }

    setState(() {
      this.allData = allData;
      this.groupedData = groupedData;
      isLoading = false;
    });
  }

  void _filterData() {
    String query = searchController.text.toLowerCase();
    setState(() {
      groupedData = {};

      for (var entry in allData) {
        String name = entry["Name"]!;
        double dueAmount = double.tryParse(entry["Due Amount"]!) ?? 0.0;

        if (dueAmount >= 1000 && name.toLowerCase().contains(query)) {
          groupedData.putIfAbsent(name, () => []);
          groupedData[name]!.add("${entry["Date"]} - ${entry["Due Amount"]}");
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (selectedAccounts.isNotEmpty) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SelectedAccountsScreen(
                  selectedAccounts: allData
                      .where(
                          (entry) => selectedAccounts.contains(entry["Name"]))
                      .toList(),
                ),
              ),
            );
          } else {
            CustomSnackBar(
                context, const Text("Please Select at Least One Account"));
          }
        },
        child: const Icon(Icons.check),
      ),
      appBar: AppBar(title: const Text("Due Payments")),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: "Search Account",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: DueGrid(
                    groupedData: groupedData,
                    selectedAccounts: selectedAccounts,
                    onAccountToggle: (name, isSelected) {
                      setState(() {
                        if (isSelected) {
                          selectedAccounts.add(name);
                        } else {
                          selectedAccounts.remove(name);
                        }
                      });
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

class SelectedAccountsScreen extends StatelessWidget {
  final List<Map<String, String>> selectedAccounts;

  SelectedAccountsScreen({required this.selectedAccounts});

  Future<void> generateAndSharePDF() async {
    final pdf = pw.Document();

    // Group accounts by name
    Map<String, List<Map<String, String>>> groupedSelectedAccounts = {};
    for (var account in selectedAccounts) {
      String name = account["Name"] ?? "---";
      groupedSelectedAccounts.putIfAbsent(name, () => []);
      groupedSelectedAccounts[name]!.add(account);
    }

    // Calculate grand total
    double grandTotalDue = selectedAccounts.fold(0.0, (sum, account) {
      double amount = double.tryParse(account["Due Amount"] ?? "0") ?? 0.0;
      return sum + amount;
    });

    // Multi-page PDF generation
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) {
          return [
            pw.Text(DateFormat('dd-MM-yyyy').format(DateTime.now()),
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 10),

            // Generate account dues list
            ...groupedSelectedAccounts.keys.map((accountName) {
              List<Map<String, String>> dues =
                  groupedSelectedAccounts[accountName]!;

              double totalDueAmount = dues.fold(0.0, (sum, entry) {
                double amount =
                    double.tryParse(entry["Due Amount"] ?? "0") ?? 0.0;
                return sum + amount;
              });

              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(accountName,
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 5),
                  pw.Table(
                    border: pw.TableBorder.all(),
                    columnWidths: {
                      0: const pw.FixedColumnWidth(15),
                      1: const pw.FixedColumnWidth(85),
                    },
                    children: [
                      pw.TableRow(
                        decoration:
                            const pw.BoxDecoration(color: PdfColors.grey300),
                        children: [
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Date",
                                style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                          pw.Padding(
                            padding: const pw.EdgeInsets.all(5),
                            child: pw.Text("Due Amount",
                                style: pw.TextStyle(
                                    fontSize: 14,
                                    fontWeight: pw.FontWeight.bold)),
                          ),
                        ],
                      ),
                      ...dues.map(
                        (due) => pw.TableRow(
                          children: [
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(
                                  (due["Date"] ?? "--").replaceAll("'", ""),
                                  style: const pw.TextStyle(fontSize: 12)),
                            ),
                            pw.Padding(
                              padding: const pw.EdgeInsets.all(5),
                              child: pw.Text(due["Due Amount"] ?? "0",
                                  style: const pw.TextStyle(fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text("Total Due: ${totalDueAmount.toStringAsFixed(0)}",
                      style: pw.TextStyle(
                          fontSize: 16, fontWeight: pw.FontWeight.bold)),
                  pw.Divider(),
                  pw.SizedBox(height: 10),
                ],
              );
            }).toList(),

            pw.Text("Grand Total Due: ${grandTotalDue.toStringAsFixed(0)}",
                style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.green)),
          ];
        },
      ),
    );

    // Save PDF file
    final output = await getTemporaryDirectory();
    final file = File(
        "${output.path}/${DateTime.now().day}-${DateTime.now().month}-${DateTime.now().year}.pdf");
    await file.writeAsBytes(await pdf.save());

    // Share PDF
    Share.shareXFiles([XFile(file.path)],
        text: "Here is the Selected Accounts Report.");
  }

  @override
  Widget build(BuildContext context) {
    // Group the selected accounts by name
    Map<String, List<Map<String, String>>> groupedSelectedAccounts = {};

    for (var account in selectedAccounts) {
      String name = account["Name"] ?? "---";
      groupedSelectedAccounts.putIfAbsent(name, () => []);
      groupedSelectedAccounts[name]!.add(account);
    }

    // Calculate grand total
    double grandTotalDue = selectedAccounts.fold(0.0, (sum, account) {
      double amount = double.tryParse(account["Due Amount"] ?? "0") ?? 0.0;
      return sum + amount;
    });

    double width = MediaQuery.of(context).size.width;

    int crossAxisCount;
    if (width < 600) {
      crossAxisCount = 1; // Mobile
    } else if (width < 1024) {
      crossAxisCount = 2; // Tablet
    } else {
      crossAxisCount = 3; // Laptop/Desktop
    }

    return Scaffold(
        backgroundColor: Colors.white,
        floatingActionButton: FloatingActionButton(
          onPressed: generateAndSharePDF,
          child: const Icon(Icons.picture_as_pdf_rounded),
        ),
        appBar: AppBar(
            title: Text(
          "Grand Total Due: ${grandTotalDue.toStringAsFixed(0)}",
          style: const TextStyle(fontSize: 18),
        )),
        body: MasonryGridView.count(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          padding: const EdgeInsets.all(10),
          itemCount: groupedSelectedAccounts.keys.length,
          itemBuilder: (context, index) {
            String accountName = groupedSelectedAccounts.keys.elementAt(index);
            List<Map<String, String>> dues =
                groupedSelectedAccounts[accountName]!;

            double totalDueAmount = dues.fold(0.0, (sum, entry) {
              double amount =
                  double.tryParse(entry["Due Amount"] ?? "0") ?? 0.0;
              return sum + amount;
            });

            return Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: Colors.black.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      accountName,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    ...dues.map((due) => Padding(
                          padding: const EdgeInsets.only(left: 10, top: 5),
                          child: Text(
                            "${due["Date"]?.replaceAll("'", "") ?? ''} - ${due["Due Amount"]}",
                            style: const TextStyle(
                                fontSize: 16, color: Colors.red),
                          ),
                        )),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.only(left: 10, top: 5),
                      child: Text(
                        "Total Due: ${totalDueAmount.toStringAsFixed(0)}",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ));
  }
}
