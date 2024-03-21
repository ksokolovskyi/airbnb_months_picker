import 'package:airbnb_months_picker/months_picker.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: _MonthsPicker(),
              ),
            ),
            Positioned(
              right: 15,
              bottom: -35,
              child: FlutterLogo(
                size: 130,
                style: FlutterLogoStyle.horizontal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthsPicker extends StatefulWidget {
  const _MonthsPicker();

  @override
  State<_MonthsPicker> createState() => __MonthsPickerState();
}

class __MonthsPickerState extends State<_MonthsPicker> {
  int _value = 1;

  @override
  Widget build(BuildContext context) {
    return MonthsPicker(
      value: _value,
      label: _value == 1 ? 'month' : 'months',
      onChanged: (value) {
        setState(() {
          _value = value;
        });
      },
    );
  }
}
