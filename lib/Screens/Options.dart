import 'package:flutter/material.dart';
import 'package:raza_brothers/Screens/CustomerBill.dart';
import 'package:raza_brothers/Screens/DuePayment.dart';
import 'package:raza_brothers/Screens/GeneraLedger.dart';
import 'package:raza_brothers/Screens/TodayCB.dart';
import 'package:raza_brothers/Screens/khata.dart';
import 'package:raza_brothers/Services/Methods.dart';
import 'package:raza_brothers/Widgets/BankBalanceWidget.dart';
import 'package:raza_brothers/Widgets/Button.dart';

class OptionsScreen extends StatefulWidget {
  const OptionsScreen({super.key});

  @override
  State<OptionsScreen> createState() => _OptionsScreenState();
}

class _OptionsScreenState extends State<OptionsScreen> {
  Map<String, double> accountBalances = Methods().getInitialAccountBalances();

  @override
  void initState() {
    super.initState();
    fetchBalances();
  }

  Future<void> fetchBalances() async {
    final accountKeys = accountBalances.keys.toSet();
    final newBalances = await Methods().fetchBalances(accountKeys);

    setState(() {
      accountBalances = newBalances;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(
                height: 20,
              ),
              AccountBalanceGrid(
                accountBalances: accountBalances,
                onRefresh: () {
                  setState(() {
                    fetchBalances();
                  });
                },
              ),
              const SizedBox(
                height: 30,
              ),
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                Methods().showSlogan(context),
                const SizedBox(width: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            optionButton(context, 'Today Cash Book', () {
                              Methods().navigateTo(context, const Todaycb());
                            }),
                            const SizedBox(width: 10),
                            optionButton(context, 'General Ledger', () {
                              Methods()
                                  .navigateTo(context, const DailyCashBook());
                            }),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            optionButton(context, 'Khata \'Accounts\'', () {
                              Methods()
                                  .navigateTo(context, const KhataScreen());
                            }),
                            const SizedBox(width: 10),
                            optionButton(context, 'Due Payment', () {
                              Methods().navigateTo(
                                  context, const DuePaymentScreen());
                            }),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            optionButton(context, 'Customer Bill', () {
                              Methods()
                                  .navigateTo(context, const CustomerBill());
                            }),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  optionButton(BuildContext context, String title, Function onClick) {
    double width = MediaQuery.of(context).size.width;
    return Column(
      children: [
        SizedBox(
            height: 70,
            width: width / 4, //desktop 5 - mobile 2.2
            child: Button_Widget(context, title, Colors.black, onClick)),
        const SizedBox(height: 10),
      ],
    );
  }
}
