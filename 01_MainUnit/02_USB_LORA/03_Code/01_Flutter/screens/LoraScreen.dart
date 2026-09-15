import 'package:flutter/material.dart';
import 'package:loracmd/common/layout.dart';
import 'package:loracmd/models/LoraModel.dart';
import 'package:provider/provider.dart';
import 'dart:typed_data';

class LoraScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Text('Clamps Settings', style: myTextStyle(24)),
            Spacer(),
            //Image( image: AssetImage('assets/zoid.webp'),height: 48.0,)
          ]),
          backgroundColor: Color(0xff269CE9),
        ),
        body: LoraConnect()
        // CustomScrollView(
        //   slivers: [
        //     // _MyAppBar(),
        //     // SliverToBoxAdapter(child: SizedBox(height: 12)),
        //     // SliverList(
        //     //   delegate: SliverChildBuilderDelegate(
        //     //           (context, index) => _MyListItem(index)),
        //     // ),
        //   ],
        // ),
        );
  }
}

class LoraConnect extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var loraData = context.watch<LoraModel>();

    return Center(
        child: Column(children: [
      ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: Text("Save")),
      ElevatedButton(
          onPressed: () => {loraData.initialize()}, child: Text("Refresh")),
      Text(
          loraData.ports.length > 0
              ? "Available Serial Ports"
              : "No serial devices available",
          style: Theme.of(context).textTheme.titleLarge),
      ...loraData.ports,
      Text('Status: ${loraData.status}')
    ]));
  }
}

class LoraControl extends StatelessWidget {
  final TextEditingController _textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var loraData = context.watch<LoraModel>();
    return Center(
        child: Column(children: <Widget>[
      ListTile(
          title: TextField(
            controller: _textController,
            decoration: InputDecoration(
              border: OutlineInputBorder(),
              labelText: 'TEST COMMAND',
            ),
          ),
          trailing: ElevatedButton(
            child: Text("Send"),
            onPressed: loraData.port == null
                ? null
                : () async {
              if (loraData.port == null) {
                return;
              }
              String data = _textController.text + "\r\n";
              await loraData.port!.write(Uint8List.fromList(data.codeUnits));
              _textController.text = "";
            },
          ),
      ),
    ]));
  }
}
