//layout definitions; mainly colors and fonts

import 'package:flutter/material.dart';

final appTheme = ThemeData(
  primaryColor: Color(0xffcccccc),
  textTheme: TextTheme(
    displayLarge: TextStyle(
      fontFamily: 'Arial',
      fontWeight: FontWeight.w700,
      fontSize: 18,
      color: Colors.white,
    ),
  ),
);

Container myValueColumn(var _topText, _bottomText) {
  return Container(color: Color(0xff999999), child:Column(
      children:[
        Container(alignment: Alignment.center,padding: EdgeInsets.symmetric(vertical: 10),//color: Color(0xfff1f1f1),
            decoration: BoxDecoration(color: Color(0xfff1f1f1),border: Border.all(color: Color(0xff999999), width: 2), borderRadius: BorderRadius.vertical(top:  Radius.circular(10.0))),
            child: Text(_topText, style: myTextStyle(18))),
        Container(alignment: Alignment.center,padding: EdgeInsets.symmetric(vertical: 5),//color: Color(0xffffffff),
            decoration: BoxDecoration(color: Color(0xffffffff),border: Border.all(color: Color(0xff999999), width: 2), borderRadius: BorderRadius.vertical(bottom:  Radius.circular(10.0))),
            child: Text(_bottomText, style: myTextStyle(18))),
      ]));
}

var myElevatedButtonStyle = ElevatedButton.styleFrom(
  backgroundColor: const Color(0xff269CE9),
  foregroundColor: Colors.white,
  padding: const EdgeInsets.all(22),
  // shape: RoundedRectangleBorder(
  //   borderRadius: BorderRadius.all(Radius.circular(10)),
  // ),
);

TextStyle myTextStyle (double _size) {
  return TextStyle(fontFamily: "Arial", fontSize: _size,color: Colors.black,fontWeight: FontWeight.bold);
}
TextStyle myCommentStyle (double _size) {
  return TextStyle(fontFamily: "Arial", fontSize: _size,color: Colors.white,fontWeight: FontWeight.bold);
}
var myTextFormFieldDeco = InputDecoration(
    labelText: "String", fillColor: Colors.white, border: OutlineInputBorder(
    //borderRadius: BorderRadius.circular(10.0), borderSide: BorderSide()
    ));
