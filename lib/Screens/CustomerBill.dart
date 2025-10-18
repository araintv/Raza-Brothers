import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:raza_brothers/Components/snackBar.dart';
import 'package:raza_brothers/Services/GsheetApi.dart';
import 'package:raza_brothers/Widgets/Button.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // add this package

class CustomerBill extends StatefulWidget {
  const CustomerBill({super.key});

  @override
  State<CustomerBill> createState() => _CustomerBillState();
}

class _CustomerBillState extends State<CustomerBill> {
  DateTime selectedDate = DateTime.now();
  final TextEditingController billNoController = TextEditingController();
  final TextEditingController customerNameController = TextEditingController();
  final TextEditingController productNameController = TextEditingController();
  final TextEditingController quantityController = TextEditingController();
  final TextEditingController valueController = TextEditingController();
  final TextEditingController priceController = TextEditingController();
  final TextEditingController widthController = TextEditingController();
  final TextEditingController lengthController = TextEditingController();
  final TextEditingController transporterNameController =
      TextEditingController();
  final TextEditingController transportController = TextEditingController();
  final TextEditingController discountController = TextEditingController();
  final TextEditingController cashPaidController = TextEditingController();

  List<Map<String, dynamic>> billItems = [];
  List<String> productSuggestions = [];
  final List<String> unitOptions = ["Quantity", "Litre", "KG", "Foot", "Tile"];

  bool isLoading = false;
  String? selectedTileType, selectedUnit;
  int? editIndex;

  void _addOrUpdateItem() {
    if (customerNameController.text.isEmpty ||
        productNameController.text.isEmpty ||
        priceController.text.isEmpty ||
        selectedUnit == null) {
      CustomSnackBar(context, const Text("Please fill all fields"));
      return;
    }

    int quantity = int.tryParse(quantityController.text) ?? 1;
    double value = double.tryParse(valueController.text) ?? 0.0;
    double price = double.tryParse(priceController.text) ?? 0.0;

    double width = 0.0;
    double length = 0.0;
    double areaInFoot = 0.0;
    double areaInMeter = 0.0;
    String productDisplayName = productNameController.text;

    // ✅ Handle Tile case
    if (selectedUnit == "Tile") {
      width = double.tryParse(widthController.text) ?? 0.0;
      length = double.tryParse(lengthController.text) ?? 0.0;

      if (width > 0 && length > 0) {
        areaInFoot = width * length; // total area in sq. foot
        areaInMeter = areaInFoot / 10.76; // convert to sq. meter

        if (selectedTileType == "Meter") {
          value = areaInMeter;
        } else {
          value = areaInFoot;
        }

        // ✅ Format display name for Tile
        productDisplayName =
            "${productNameController.text}\nTotal : Meter ${areaInMeter.toStringAsFixed(2)}, Foot ${areaInFoot.toStringAsFixed(0)})";
      } else {
        CustomSnackBar(context, const Text("Enter Width & Length for Tile"));

        return;
      }
    }

    double total = quantity * value * price;

    final newItem = {
      "billNo": billNoController.text,
      "date": DateFormat("dd-MM-yyyy").format(selectedDate),
      "customerName": customerNameController.text,
      "productName": productDisplayName, // ✅ formatted name
      "quantity": quantity,
      "unit": selectedUnit,
      "tileType": selectedTileType ?? "",
      "width": widthController.text,
      "length": lengthController.text,
      "value": value, // ✅ keep double
      "price": price, // ✅ keep double
      "total": total, // ✅ keep double
    };

    setState(() {
      if (editIndex != null) {
        billItems[editIndex!] = newItem;
        editIndex = null;
      } else {
        billItems.add(newItem);
      }

      // Clear product-related fields only
      productNameController.clear();
      quantityController.clear();
      valueController.clear();
      priceController.clear();
      widthController.clear();
      lengthController.clear();
      selectedTileType = null;
    });
  }

  Future<void> _uploadBill() async {
    setState(() {
      isLoading = true;
    });

    if (billItems.isEmpty) {
      CustomSnackBar(context, const Text("No items to upload"));

      setState(() => isLoading = false);
      return;
    }

    final String billNo = billNoController.text.trim().isEmpty
        ? "N/A"
        : billNoController.text.trim();

    final double productsTotal = billItems.fold(
      0.0,
      (sum, item) => sum + (item['total'] ?? 0.0),
    );

    final double totalBill = grandTotal;

    final double cashPaid =
        double.tryParse(cashPaidController.text.trim()) ?? 0.0;

    final double remaining = totalBill - cashPaid;

    final details = billItems.map((item) {
      final qtyPart =
          (item['quantity'] != 1) ? "Qty: ${item['quantity']}, " : "";
      return "${item['productName']} "
          "($qtyPart${item['unit']}: ${formatNumber(item['value'])} "
          "× Rate: ${formatNumber(item['price'])} "
          "= Rs.${formatNumber(item['total'])})";
    }).join(" | ");

    final extraDetails = [
      if (transporterNameController.text.isNotEmpty)
        "Transporter Name: ${transporterNameController.text}",
      if (transportController.text.isNotEmpty &&
          double.tryParse(transportController.text) != null &&
          double.parse(transportController.text) > 0)
        "Transport Charges: Rs.${formatNumber(double.parse(transportController.text))}",
      if (discountController.text.isNotEmpty &&
          double.tryParse(discountController.text) != null &&
          double.parse(discountController.text) > 0)
        "Discount: Rs.${formatNumber(double.parse(discountController.text))}",
      "Products Total (without charges): Rs.${formatNumber(productsTotal)}",
    ].join(" | ");

    final fullDetails =
        extraDetails.isNotEmpty ? "$details $extraDetails" : details;

    try {
      // ✅ Always insert at least one row for cash received
      // ✅ Only insert cash row if > 0
      if (cashPaid > 0) {
        final rowCash = [
          DateFormat("dd-MM-yyyy").format(selectedDate), // Date
          "Stock Khata", // Jama
          "Customer Bill", // Type
          "Dukan Cash", // Naam (shop got this money)
          formatNumber(cashPaid), // Amount actually received
          "$fullDetails Cash Paid: Rs.${formatNumber(cashPaid)}", // Details
        ];
        await UserSheetsApi.insertRow(rowCash);
      }

      // ✅ If remaining > 0, also insert second row
      if (remaining > 0) {
        final rowRemaining = [
          DateFormat("dd-MM-yyyy").format(selectedDate), // Date
          "Stock Khata", // Jama
          "Customer Bill", // Type
          customerNameController.text, // Naam (customer still owes this much)
          formatNumber(remaining), // Remaining balance
          "Remaining balance from bill No \"$billNo\" of Rs.${formatNumber(totalBill)} -- $fullDetails", // Details
        ];
        await UserSheetsApi.insertRow(rowRemaining);
      }

      // ✅ NEW: Insert extra rows for items with price = 0
      for (var item in billItems) {
        final double price = item['price'] ?? 0.0;
        if (price == 0) {
          final rowFreeItem = [
            DateFormat("dd-MM-yyyy").format(selectedDate), // Date
            "Stock Khata", // Jama
            "Customer Bill", // Type
            customerNameController.text, // Naam (customer gets this free item)
            formatNumber(item['value']), // Store value or qty as amount
            "Free Item: ${item['productName']} "
                "(${item['unit']} ${formatNumber(item['value'])}) "
                "-- Bill No \"$billNo\"", // Details
          ];
          await UserSheetsApi.insertRow(rowFreeItem);
        }
      }

      CustomSnackBar(context, const Text("Bill uploaded successfully!"));

      final copiedItems = List<Map<String, dynamic>>.from(billItems);

      _showReceiptDialog(
        billNo: billNo,
        customerName: customerNameController.text,
        transporterName: transporterNameController.text,
        items: copiedItems,
        transport: transportCharges,
        discount: discountAmount,
        cashPaid: cashPaid,
        grandTotal: totalBill,
      );

      setState(() {
        billItems.clear();
        transportController.clear();
        transporterNameController.clear();
        discountController.clear();
        cashPaidController.clear();
      });

      setState(() {
        transportController.clear();
        transporterNameController.clear();
        discountController.clear();
        cashPaidController.clear();
      });
    } catch (e) {
      CustomSnackBar(context, Text("Upload failed: $e"));
    }

    setState(() {
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Customer Bill"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    "Date: ${DateFormat("dd-MM-yyyy").format(selectedDate)}",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                Button_Widget(context, 'Pick a Date', Colors.black, _pickDate),
              ],
            ),

            const SizedBox(height: 20),

            /// Row with Qty, Product, Unit, Value, Price
            Row(
              children: [
                /// Bill No
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: billNoController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Bill No.",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                /// Customer Name
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: customerNameController,
                    decoration: const InputDecoration(
                      labelText: "Customer Name",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 6),

                /// Product Name Autocomplete
                Expanded(
                  flex: 2,
                  child: Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return productSuggestions.where(
                        (option) => option.toLowerCase().contains(
                              textEditingValue.text.toLowerCase(),
                            ),
                      );
                    },
                    onSelected: (String selection) {
                      productNameController.text = selection;
                    },
                    fieldViewBuilder: (context, textEditingController,
                        focusNode, onEditingComplete) {
                      textEditingController.text = productNameController.text;
                      textEditingController.addListener(() {
                        productNameController.text = textEditingController.text;
                      });
                      return TextField(
                        controller: textEditingController,
                        focusNode: focusNode,
                        onEditingComplete: onEditingComplete,
                        decoration: const InputDecoration(
                          labelText: "Product Name",
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 6),

                /// Unit Dropdown
                SizedBox(
                  width: 120,
                  child: DropdownButtonFormField<String>(
                    value: selectedUnit,
                    hint: const Text("Unit"),
                    decoration:
                        const InputDecoration(border: OutlineInputBorder()),
                    items: unitOptions.map((String unit) {
                      return DropdownMenuItem<String>(
                        value: unit,
                        child: Text(unit),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedUnit = value;
                        selectedTileType = null;
                        if (selectedUnit == "Quantity" ||
                            selectedUnit == "KG" ||
                            selectedUnit == "Litre") {
                          quantityController.text = "1";
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 6),

                // ✅ If unit = Tile → show Tile fields
                if (selectedUnit == "Tile") ...[
                  /// Tile Type Dropdown
                  SizedBox(
                    width: 100,
                    child: DropdownButtonFormField<String>(
                      value: selectedTileType,
                      hint: const Text("Tile Type"),
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                      items: ["Inches", "Meter"].map((t) {
                        return DropdownMenuItem<String>(
                          value: t,
                          child: Text(t),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() {
                          selectedTileType = val;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 6),

                  /// Width
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: widthController,
                      keyboardType: TextInputType.number,
                      // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Width",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  /// Length
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: lengthController,
                      keyboardType: TextInputType.number,
                      // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Length",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // ✅ Qty field (only when NOT Quantity/KG/Litre)
                if (selectedUnit != "Quantity" &&
                    selectedUnit != "KG" &&
                    selectedUnit != "Litre") ...[
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: quantityController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: "Qty",
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // ✅ Value field (only if not Tile)
                if (selectedUnit != "Tile") ...[
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: valueController,
                      keyboardType: TextInputType.number,
                      // inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: selectedUnit ?? "Rate",
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                /// Price
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: priceController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: "Price",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                /// Add / Update Button
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: Button_Widget(
                      context,
                      editIndex == null ? "Add Item" : "Update Item",
                      Colors.black,
                      _addOrUpdateItem,
                    ),
                  ),
                ),
              ],
            ),

            const Divider(),

            /// Bill List
            Expanded(
              child: ListView.builder(
                itemCount: billItems.length,
                itemBuilder: (context, index) {
                  final item = billItems[index];
                  return Card(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(10), // if you need this
                      side: const BorderSide(
                        color: Colors.black,
                        width: 0.5,
                      ),
                    ),
                    child: ListTile(
                      title: Text(
                        "Product Name : ${item['productName']}",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        "${(item['quantity'] != 1) ? "Qty: ${item['quantity']} | " : ""}"
                        "${item['unit']} ${formatNumber(item['value'])} "
                        "${item['unit'] == 'Tile' ? "( ${item['tileType']} ${item['width']} x ${item['length']} ) " : ""}"
                        "× Rate: ${formatNumber(item['price'])} = Rs.${formatNumber(item['total'])}",
                      ),
                      trailing: Wrap(
                        spacing: 6,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: () => _editItem(index),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteItem(index),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),

            /// Grand Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Row(
                  children: [
                    const Text(
                      "Transporter : ",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: 120,
                      height: 40,
                      child: TextField(
                        controller: transporterNameController,
                        decoration: const InputDecoration(
                          hintText: "Name",
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: TextField(
                        controller: transportController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly, // ✅ Only digits allowed
                        ],
                        onChanged: (_) => setState(() {}), // ✅ update live
                        decoration: const InputDecoration(
                          hintText: "Charges",
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Row(
                      children: [
                        const Text(
                          "Discount : ",
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(
                          width: 70,
                          height: 40,
                          child: TextField(
                            controller: discountController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter
                                  .digitsOnly, // ✅ Only digits allowed
                            ],
                            onChanged: (_) => setState(() {}),
                            decoration: const InputDecoration(
                              hintText: "0",
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      "Cash Received : ",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(
                      width: 100,
                      height: 40,
                      child: TextField(
                        controller: cashPaidController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter
                              .digitsOnly, // ✅ Only digits allowed
                        ],
                        decoration: const InputDecoration(
                          hintText: "0",
                          border: OutlineInputBorder(),
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  "Total: Rs. ${grandTotal.toStringAsFixed(2)}",
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.bold),
                ),
                SizedBox(
                  height: 45,
                  width: 200,
                  child: isLoading
                      ? const Center(
                          child: CircularProgressIndicator(color: Colors.blue),
                        )
                      : Button_Widget(
                          context, 'Upload Bill', Colors.blue, _uploadBill),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    fetchProductSuggestions();
  }

  @override
  void dispose() {
    billNoController.dispose();
    customerNameController.dispose();
    productNameController.dispose();
    quantityController.dispose();
    valueController.dispose();
    priceController.dispose();
    transportController.dispose();
    transporterNameController.dispose();
    discountController.dispose();
    cashPaidController.dispose();
    super.dispose();
  }

  Future<void> fetchProductSuggestions() async {
    try {
      final rows = await UserSheetsApi.fetchAllRowsFromSheet("Stock");

      if (rows.isEmpty) {
        CustomSnackBar(context, const Text("⚠️ No rows found in Stock sheet"));
        return;
      }

      setState(() {
        // Skip header row, take only non-empty product names
        productSuggestions = rows
            .skip(1) // ✅ skip header row
            .map((row) => row.isNotEmpty ? row[0].toString().trim() : "")
            .where((item) => item.isNotEmpty)
            .toSet() // ✅ remove duplicates
            .toList();
      });

      CustomSnackBar(
          context,
          const Text(
            "✅ Loaded All Products",
            maxLines: 1,
          ));
    } catch (e) {
      CustomSnackBar(context, Text("❌ Error fetching product suggestions: $e"));
    }
  }

  void _deleteItem(int index) {
    setState(() {
      billItems.removeAt(index);
    });
  }

  void _editItem(int index) {
    final item = billItems[index];
    setState(() {
      customerNameController.text = item["customerName"];
      productNameController.text = item["productName"];
      quantityController.text = item["quantity"].toString();
      valueController.text = item["value"].toString();
      priceController.text = item["price"].toString();
      selectedUnit = item["unit"];
      editIndex = index;
    });
  }

  double get transportCharges =>
      double.tryParse(transportController.text) ?? 0.0;

  double get discountAmount => double.tryParse(discountController.text) ?? 0.0;

  double get grandTotal {
    double itemsTotal =
        billItems.fold(0, (sum, item) => sum + (item["total"] as double));
    return itemsTotal + transportCharges - discountAmount;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != selectedDate) {
      setState(() => selectedDate = picked);
    }
  }

  String formatNumber(num value) {
    if (value == value.toInt()) {
      return value.toInt().toString(); // show 10 instead of 10.0
    } else {
      return value.toString(); // keep decimals like 10.5
    }
  }

  void _showReceiptDialog({
    required String billNo,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required String transporterName,
    required double transport,
    required double discount,
    required double cashPaid,
    required double grandTotal,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          title: const Text(
            "Bill Receipt",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bill No: $billNo"),
                  Text("Customer: $customerName"),
                  if (transporterName.isNotEmpty)
                    Text("Transporter: $transporterName"),
                  const Divider(),

                  // Products List
                  ...items.map((item) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${item['productName']} (${item['unit']} ${formatNumber(item['value'])})",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          "${(item['quantity'] != 1) ? "Qty: ${item['quantity']} × " : ""}"
                          "Rate: ${formatNumber(item['price'])} = Rs.${formatNumber(item['total'])}",
                        ),
                        const SizedBox(height: 6),
                      ],
                    );
                  }),

                  const Divider(),
                  if (transport > 0)
                    Text("Transport Charges: Rs.${formatNumber(transport)}"),
                  if (discount > 0)
                    Text("Discount: Rs.${formatNumber(discount)}"),
                  if (cashPaid > 0)
                    Text("Cash Paid: Rs.${formatNumber(cashPaid)}"),

                  const Divider(),
                  Text(
                    "Grand Total: Rs.${grandTotal.toStringAsFixed(2)}",
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            // ✅ PDF Download Button
            TextButton.icon(
              icon: const Icon(Icons.download),
              label: const Text("Download PDF"),
              onPressed: () async {
                await _generatePdfAndSave(
                  billNo: billNo,
                  customerName: customerName,
                  transporterName: transporterName,
                  items: items,
                  transport: transport,
                  discount: discount,
                  cashPaid: cashPaid,
                  grandTotal: grandTotal,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("PDF saved successfully!")),
                );
              },
            ),

            // ✅ Print Button
            TextButton.icon(
              icon: const Icon(Icons.print),
              label: const Text("Print"),
              onPressed: () async {
                await _printBill(
                  billNo: billNo,
                  customerName: customerName,
                  transporterName: transporterName,
                  items: items,
                  transport: transport,
                  discount: discount,
                  cashPaid: cashPaid,
                  grandTotal: grandTotal,
                );
              },
            ),

            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Close"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generatePdfAndSave({
    required String billNo,
    required String customerName,
    required String transporterName,
    required List<Map<String, dynamic>> items,
    required double transport,
    required double discount,
    required double cashPaid,
    required double grandTotal,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Bill Receipt",
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Bill No: $billNo"),
              pw.Text("Customer: $customerName"),
              if (transporterName.isNotEmpty)
                pw.Text("Transporter: $transporterName"),
              pw.Divider(),

              // Products
              ...items.map((item) => pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        "${item['productName']} (${item['unit']} ${formatNumber(item['value'])})",
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                      ),
                      pw.Text(
                        "${(item['quantity'] != 1) ? "Qty: ${item['quantity']} × " : ""}Rate: ${formatNumber(item['price'])} = Rs.${formatNumber(item['total'])}",
                      ),
                      pw.SizedBox(height: 6),
                    ],
                  )),

              pw.Divider(),
              if (transport > 0)
                pw.Text("Transport Charges: Rs.${formatNumber(transport)}"),
              if (discount > 0)
                pw.Text("Discount: Rs.${formatNumber(discount)}"),
              if (cashPaid > 0)
                pw.Text("Cash Paid: Rs.${formatNumber(cashPaid)}"),
              pw.Divider(),
              pw.Text("Grand Total: Rs.${grandTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(
                      fontSize: 16, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    // 📂 Save into Downloads folder (Android)
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory("/storage/emulated/0/Download");
    } else {
      dir = await getApplicationDocumentsDirectory();
    }

    final file = File("${dir.path}/bill_$billNo.pdf");
    await file.writeAsBytes(await pdf.save());

    // ✅ Optionally open the PDF after saving
    await OpenFilex.open(file.path);
  }

  Future<void> _printBill({
    required String billNo,
    required String customerName,
    required String transporterName,
    required List<Map<String, dynamic>> items,
    required double transport,
    required double discount,
    required double cashPaid,
    required double grandTotal,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Bill Receipt",
                  style: pw.TextStyle(
                      fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.Text("Bill No: $billNo"),
              pw.Text("Customer: $customerName"),
              if (transporterName.isNotEmpty)
                pw.Text("Transporter: $transporterName"),
              pw.Divider(),
              ...items.map((item) => pw.Text(
                    "${item['productName']} | ${item['unit']} ${formatNumber(item['value'])} | Rate: ${formatNumber(item['price'])} | Total: Rs.${formatNumber(item['total'])}",
                    style: const pw.TextStyle(fontSize: 12),
                  )),
              pw.Divider(),
              if (transport > 0)
                pw.Text("Transport: Rs.${formatNumber(transport)}"),
              if (discount > 0)
                pw.Text("Discount: Rs.${formatNumber(discount)}"),
              if (cashPaid > 0)
                pw.Text("Cash Paid: Rs.${formatNumber(cashPaid)}"),
              pw.Divider(),
              pw.Text("Grand Total: Rs.${grandTotal.toStringAsFixed(2)}",
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save());
  }
}
