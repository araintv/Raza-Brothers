import 'package:flutter/material.dart';

class AccountBalanceGrid extends StatelessWidget {
  final Map<String, double> accountBalances;
  final VoidCallback onRefresh;

  const AccountBalanceGrid({
    super.key,
    required this.accountBalances,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 20,
      color: Colors.blue[50],
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: accountBalances.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: MediaQuery.of(context).size.width < 600 ? 2 : 6,
            childAspectRatio: 2, //Desktop 2.9 - mobile 2
            crossAxisSpacing: 0.1, //Desktop 1 - mobile 0.1
            mainAxisSpacing: 0.1, //Desktop 1 - mobile 0.1
          ),
          itemBuilder: (context, index) {
            String account = accountBalances.keys.elementAt(index);
            double balance = accountBalances[account] ?? 0.0;

            return InkWell(
              onTap: onRefresh,
              child: Card(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            account,
                            style: const TextStyle(
                              fontSize: 25,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "${balance >= 0 ? "+" : ""}${balance.toStringAsFixed(0)}",
                            style: TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              color: balance >= 0 ? Colors.green : Colors.red,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
