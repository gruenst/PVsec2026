import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:loracmd/common/layout.dart';
import 'package:loracmd/models/MeasureModel.dart';
import 'package:loracmd/screens/MeasureScreen.dart';
import 'package:loracmd/models/LoraModel.dart';
import 'package:loracmd/screens/LoraScreen.dart';

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (context) => MeasureModel(),
          ),
          ChangeNotifierProvider(
              create: (context) => LoraModel(),
          ),
          ChangeNotifierProvider(
              create: (context) => MeasureClock()),
          // ChangeNotifierProxyProvider
        ],
        child: MaterialApp(
          title: 'Provider Demo',
          theme: appTheme,
          initialRoute: '/',
          routes: {
            '/': (context) => MeasureScreen(),
            '/settings': (context) => LoraScreen(),
          },
        ));

  }
}




