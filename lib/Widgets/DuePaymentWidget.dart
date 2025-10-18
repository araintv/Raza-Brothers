import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

class DueGrid extends StatelessWidget {
  final Map<String, List<String>> groupedData;
  final Set<String> selectedAccounts;
  final Function(String, bool) onAccountToggle;

  const DueGrid({
    Key? key,
    required this.groupedData,
    required this.selectedAccounts,
    required this.onAccountToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Screen width
    final width = MediaQuery.of(context).size.width;

    // Breakpoints: phone < 600, tablet < 1024, desktop ≥ 1024
    int crossAxisCount;
    if (width < 600) {
      crossAxisCount = 1;
    } else if (width < 1024) {
      crossAxisCount = 2;
    } else {
      crossAxisCount = 3;
    }

    return MasonryGridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: groupedData.keys.length,
      itemBuilder: (context, index) {
        final accountName = groupedData.keys.elementAt(index);
        final dues = groupedData[accountName]!;

        final totalDue = dues.fold<double>(
          0.0,
          (sum, due) {
            final parts = due.split(" - ");
            return sum +
                (parts.length > 1 ? double.tryParse(parts[1]) ?? 0.0 : 0.0);
          },
        );

        return Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: Colors.black.withOpacity(0.2), width: 1),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row with name + checkbox
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        accountName,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Checkbox(
                      value: selectedAccounts.contains(accountName),
                      onChanged: (val) =>
                          onAccountToggle(accountName, val ?? false),
                    ),
                  ],
                ),

                // List of dues (variable length)
                ...dues.map((due) => Padding(
                      padding: const EdgeInsets.only(left: 6, top: 2),
                      child: Text(
                        due.replaceAll("'", ""),
                        style: const TextStyle(fontSize: 14, color: Colors.red),
                      ),
                    )),

                const Divider(),

                // Total due
                Text(
                  "Total Due: ${totalDue.toStringAsFixed(0)}",
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
