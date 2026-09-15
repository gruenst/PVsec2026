import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:loracmd/common/layout.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:loracmd/models/MeasureModel.dart';
import 'package:provider/provider.dart';
import 'package:animations/animations.dart';
import 'package:loracmd/models/LoraModel.dart';


class MeasureScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Row(children: [
            Text('Measurement App', style: myTextStyle(24)),
            Spacer(),
            //Image(image: AssetImage('assets/zoid.webp'), height: 48.0,),
            IconButton(
              icon: Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settings'),
            ),
          ]),
          backgroundColor: Color(0xff269CE9),
        ),
        body: SingleChildScrollView(child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FirstLine(),
            SecondLine(),
            ThirdLine(),
            FourthLine(),
            FifthLine(),
            CommentLine(),
            SixthLine(),
          ],
          ),
        )
        );
  }
}


class FirstLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = context.watch<MeasureModel>();
    return Container(
         color: Color(0xff999999),
       child: Row(
       children:
      List.generate(
          model.clampNumber,(i) => Expanded(child: Container(padding: EdgeInsets.all(15),
          decoration: BoxDecoration(color: model.powerColors[i], border: Border.all(color: Color(0xff999999), width: 2),borderRadius: BorderRadius.all(Radius.circular(15))),
          child: Text(model.powerValues[i].toStringAsFixed(1), textAlign: TextAlign.center, style: TextStyle(fontSize: 18.0,color: Colors.white)))),
          growable: true)
      ));
  }
}


class SecondLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = context.watch<MeasureModel>();
    var clock = context.watch<MeasureClock>();
    return Table(
        columnWidths: const <int, TableColumnWidth>{ 0: FixedColumnWidth(60),  2: FixedColumnWidth(60), 3: IntrinsicColumnWidth()},children: [
      TableRow(decoration: const BoxDecoration(color: Color(0xff999999)), children:[
        ElevatedButton(style: myElevatedButtonStyle,
            child: Text("-", style: TextStyle(fontSize: 20.0,color: Colors.white)),
            onPressed: () { String _string = model.stringID().text; int i = int.tryParse(model.stringID().text.substring(model.stringID().text.length-2)) ?? 0;
            if (i>1) {i--; model.stringID().text =_string.substring(0,_string.length-2) + i.toString().padLeft(2,'0');}
            }),
        TextFormField(autofocus: true, controller: model.stringID(), decoration: myTextFormFieldDeco,
            keyboardType: TextInputType.name, style:  myCommentStyle(18)),
        ElevatedButton(style: myElevatedButtonStyle,
            child: Text("+", style: TextStyle(fontSize: 20.0,color: Colors.white)),
            onPressed: () { String _string = model.stringID().text; int i = int.tryParse(model.stringID().text.substring(model.stringID().text.length-2)) ?? 99;
            if (i<99) {i++; model.stringID().text =_string.substring(0,_string.length-2) + i.toString().padLeft(2,'0');}
            }),
        Container(  padding: EdgeInsets.all(8),
            child: Text(clock.dateTime,style: myCommentStyle(16))
        ),
      ])]);
  }
}


class ThirdLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = context.watch<MeasureModel>();
    return Slidable(
      startActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.15, children: [SlidableAction(onPressed: (_) => model.lessClamps(), backgroundColor: Color(0xff269CE9), foregroundColor: Colors.white, icon: Icons.exposure_minus_1, label: 'less')]),
      endActionPane: ActionPane(motion: const DrawerMotion(), extentRatio: 0.15, children: [SlidableAction(onPressed: (_) => model.moreClamps(), backgroundColor: Color(0xff269CE9), foregroundColor: Colors.white, icon: Icons.exposure_plus_1, label: 'more')]),
      child: Row(children: List.generate(model.clampNumber, (i) => Expanded(child: myValueColumn("I ${i + 1}", "${model.currents[i].toStringAsFixed(1)}")))),
    );
  }
}

class FourthLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = context.watch<MeasureModel>();
    return Table(
        border: TableBorder.all(color: Color(0xff999999),width: 4),
      children: [
      TableRow(decoration: const BoxDecoration(color: Color(0xff999999)), children:[
        myValueColumn("Irr 1", "${model.irradiance[0].toStringAsFixed(0)}"),
        myValueColumn("Irr 2", "${model.irradiance[1].toStringAsFixed(0)}"),
        myValueColumn("Tm 1", "${model.temperature[0].toStringAsFixed(1)}"),
        myValueColumn("Tm 2", "${model.temperature[1].toStringAsFixed(1)}"),
        myValueColumn("Volt", "${model.voltage.toStringAsFixed(0)}"),
      ])]);
  }
}

class FifthLine extends StatelessWidget {
  @override
  Widget build (BuildContext context)  {
    var model = context.watch<MeasureModel>();
    return Table(
        border: TableBorder.all(color: Color(0xff999999),width: 4),
      children: [
      TableRow(decoration: const BoxDecoration(color: Color(0xff999999)), children:[
        OpenContainer<Widget>(
          openBuilder: (context, closeContainer) {
            return InkWell( onTap: closeContainer, child: Container(child:  PnomChangeScreen()   ));},
          tappable: true, transitionDuration: Duration(seconds: 1),
          transitionType: ContainerTransitionType.fadeThrough,
          closedBuilder: (context, openContainer) {return myValueColumn("Pnom [W]", "${model.pnom.toStringAsFixed(1)}");},
        ),
        OpenContainer<Widget>(
          openBuilder: (context, closeContainer) {
            return InkWell( onTap: closeContainer, child: Container(child:  ModuleChangeScreen()   ));},
          tappable: true, transitionDuration: Duration(seconds: 1),
          transitionType: ContainerTransitionType.fadeThrough,
          closedBuilder: (context, openContainer) {return myValueColumn("modules/str", "${model.modNum.toStringAsFixed(0)}");},
        ),
        OpenContainer<Widget>(
          openBuilder: (context, closeContainer) {
            return InkWell( onTap: closeContainer, child: Container(child: TkChangeScreen()  ));},
          tappable: true, transitionDuration: Duration(seconds: 1),
          transitionType: ContainerTransitionType.fadeThrough,
          closedBuilder: (context, openContainer) {return myValueColumn("Tk [%/K]", "${model.tk.toStringAsFixed(2)}");},
        )
      ])]);
  }
}


class PnomChangeScreen extends StatelessWidget {
  double sliderValue = 75;
  @override
  Widget build (BuildContext context)  {
    var model = context.watch<MeasureModel>();
    sliderValue = model.pnom;
    return
     Column(mainAxisAlignment: MainAxisAlignment.center, children:[
       myValueColumn("Pnom [W]", "${model.pnom.toStringAsFixed(1)}"),
       Slider(value: sliderValue, min: 50, max: 500, divisions: 180, label: model.pnom.toStringAsFixed(1),
          onChanged: (double value) { sliderValue = value;model.changePnom(value);model.update();})
     ]);
  }
}

class ModuleChangeScreen extends StatelessWidget {
  double sliderValue = 10;
  @override
  Widget build (BuildContext context)  {
    var model = context.watch<MeasureModel>();
    sliderValue = model.modNum.toDouble();
    return
      Column(mainAxisAlignment: MainAxisAlignment.center, children:[
        myValueColumn("modules/str", "${model.modNum.toStringAsFixed(0)}"),
        Slider(value: sliderValue, min: 1, max: 50, divisions: 49, label: model.modNum.toStringAsFixed(0),
            onChanged: (double value) { sliderValue = value;model.changeModNum(value.toInt());model.update();})
      ]);
  }
}

class TkChangeScreen extends StatelessWidget {
  double sliderValue = -0.25;
  @override
  Widget build (BuildContext context)  {
    var model = context.watch<MeasureModel>();
    sliderValue = model.tk;
    return
      Column(mainAxisAlignment: MainAxisAlignment.center, children:[
        myValueColumn("Tk [%/K]", "${model.tk.toStringAsFixed(2)}"),
        Slider(value: sliderValue, min: -0.5, max: 0, divisions: 50, label: model.tk.toStringAsFixed(2),
            onChanged: (double value) { sliderValue = value;model.changeTk(value);model.update();})
      ]);
  }
}


class SixthLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = context.watch<MeasureModel>();
    var usb = context.watch<LoraModel>();
    return Table(
        columnWidths: const <int, TableColumnWidth>{ 0: FlexColumnWidth(),  1: FlexColumnWidth(), 2: FlexColumnWidth()},children: [
      TableRow(decoration: const BoxDecoration(color: Color(0xff999999)), children:[
        ElevatedButton(style: myElevatedButtonStyle,
            child: Text("MEAS", style: TextStyle(fontSize: 20.0,color: Colors.white)),
            onPressed: (usb.disableMeasure)  ? null: () { usb.changeCommentIcon(Icons.hourglass_bottom);
                            usb.disableButton("all");
                            usb.changeCommentText("measurement started...  (${model.clampNumber.toString()} clamps)");
                            usb.sendMeasure();
                            usb.update();
                            model.clearAll(); model.update(); }
            ),
        ElevatedButton(style: myElevatedButtonStyle,
            child: Text("clamps", style: TextStyle(fontSize: 20.0,color: Colors.white)),
            onPressed: (usb.disableClamps) ? null: () { usb.changeCommentIcon(Icons.hourglass_bottom);
            usb.disableButton("all");
            usb.changeCommentText("clamp test...  (${model.clampNumber.toString()} clamps)");
            usb.sendClampsOnly();
            usb.update(); }
            ),
        ElevatedButton(style: myElevatedButtonStyle,
            child: Text("SAVE", style: TextStyle(fontSize: 20.0,color: Colors.white)),
            onPressed: (usb.disableSave) ? null: () {
              usb.saveDataToFile();
              usb.update();
            }
           )
  ])]);
  }
}

class CommentLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var model = context.watch<MeasureModel>();
    var usb = context.watch<LoraModel>();
    return Container(color: Colors.black, padding: EdgeInsets.all(10), child: Row(mainAxisAlignment: MainAxisAlignment.start, children: [
      Icon(usb.commentIcon, color: Colors.white),
      Text(usb.commentText, style: myCommentStyle(16)),
    ]
    ));
  }
}
