import 'dart:collection';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class MeasureModel extends ChangeNotifier {
  double _tk = -0.25;
  double _pnom = 75;
  int _modNum = 10;
  double _voltage = 0.0;
  List<double> _currents = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<double> _irradiance = [1000, 900];
  List<double> _temperature = [25.0, 24.0];
  List<Color> _powerColors = [Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc), Color(0xffcccccc)];
  List<double> _powerValues = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
  List<Color> _clampColors = [Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa), Color(0xfffafafa)];
  TextEditingController _stringID = TextEditingController();

  final List<Clamp> _clamps = [Clamp("clamp_1"), Clamp("clamp_2"), Clamp("clamp_3"), Clamp("clamp_4"), Clamp("clamp_5")];

  // buffer for accumulating measurements before save
  List<String> _dataBuffer = [];

  UnmodifiableListView<Clamp> get clamps => UnmodifiableListView(_clamps);
  List<double> get currents => _currents;
  List<double> get irradiance => _irradiance;
  List<double> get temperature => _temperature;
  int get clampNumber => _clamps.length;
  double get voltage => this._voltage;
  double get tk => this._tk;
  double get pnom => this._pnom;
  int get modNum => this._modNum;
  UnmodifiableListView<Color> get powerColors => UnmodifiableListView(_powerColors);
  UnmodifiableListView<double> get powerValues => UnmodifiableListView(_powerValues);
  UnmodifiableListView<Color> get clampColors => UnmodifiableListView(_clampColors);
  TextEditingController stringID() => this._stringID;
  List<String> get dataBuffer => _dataBuffer;

  void add(Clamp clamp) {
    _clamps.add(clamp);
    notifyListeners();
  }

  void moreClamps() {
    if(_clamps.length <= 9)
      _clamps.add(Clamp("clamp_${_clamps.length+1}"));
    notifyListeners();
  }

  void lessClamps() {
    if(_clamps.length > 0)
      _clamps.removeLast();
    notifyListeners();
  }

  void changePnom(double value) {
    _pnom = value;
  }
  void changeTk(double value) {
    _tk = value;
  }
  void changeModNum(int value) {
    _modNum = value;
  }
  void update(){
    notifyListeners();
  }
  void changePowerValue(int index, double value) {
    _powerValues[index] = value;
  }
  void clearAll() {
    _temperature[0]=0;_temperature[1]=0;_irradiance[0]=0;_irradiance[1]=0;_voltage=0;
    for (int i=0; i<10; i++) {_currents[i]=0; _powerValues[i]=0; _powerColors[i] = Color(0xffcccccc);}
  }

  void addToDataBuffer() {
    var dt = DateTime.now();
    var timestamp = '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year.toString().substring(2)} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    var _string = _stringID.text;
    
    // format: timestamp;string_id;pnom;modNum;vk;tmod1;tmod2;irr1;irr2;voltage;c1;c2;c3...c10
    var line = "$timestamp;$_string;$_pnom;$_modNum;$tk;${_temperature[0].toStringAsFixed(1)};${_temperature[1].toStringAsFixed(1)};${_irradiance[0].toStringAsFixed(0)};${_irradiance[1].toStringAsFixed(0)};${_voltage.toStringAsFixed(0)};";
    for (int i = 0; i < 10; i++) {
      line += "${_currents[i].toStringAsFixed(3)}";
      if (i < 9) line += ";";
    }
    _dataBuffer.add(line);
  }

  void clearDataBuffer() {
    _dataBuffer.clear();
    notifyListeners();
  }

  void evaluateMeasurement() {
    // sensor fallbacks (fixes the buggy lines from index.html)
    var irr = _irradiance[0];
    if ((irr < 650) || (irr.isNaN)) { irr = _irradiance[1]; }
    var tmod = _temperature[0];
    if ((tmod == 0) || (tmod.isNaN)) { tmod = _temperature[1]; }

    // clamp plausibility check
    var results = [];
    for (int i = 0; i < 10; i++) {
      results.add(_currents[i]);
    }
    var resultAvg = 0.0, j = 0;
    for (int i = 0; i < results.length; i++) {
      if (results[i] > 0) {
        resultAvg += results[i];
        j++;
      }
    }
    if (j > 0) { resultAvg /= j; }
    for (int i = 0; i < results.length; i++) {
      if ((results[i] > 0) && (results[i] > 0.9 * resultAvg) && (results[i] < 1.1 * resultAvg)) {
        _clampColors[i] = Color(0xfffafafa);
      } else {
        _clampColors[i] = Colors.yellow;
      }
    }

    // normalized power calculation per clamp
    for (int i = 0; i < 10; i++) {
      double result;
      if (irr > 0) {
        result = _currents[i] * _voltage / irr * 1000.0 * (1 - (tmod - 25.0) * _tk / 100.0) / (_pnom * _modNum) * 100.0;
      } else {
        result = 0;
      }
      _powerValues[i] = result;
      if (result < 70) { _powerColors[i] = Color(0xffef4655); }
      else if (result < 80) { _powerColors[i] = Color(0xfff7aa38); }
      else if (result < 90) { _powerColors[i] = Color(0xfffffa50); }
      else if (result < 110) { _powerColors[i] = Color(0xff5ee432); }
      else { _powerColors[i] = Color(0xffBE80FF); }
    }

    notifyListeners();
  }

  void setValues(String _id, double value) {
    switch (_id.substring(0,_id.length-3)) {    //cut off end number    clamp_1  => clamp
      case "clamp": int? _num = int.tryParse(_id[_id.length-1]); if ((_num==0)||(_num == null)) _num=10; _currents[_num-1] = value;  break;
      case "irr": int? _num = int.tryParse(_id[_id.length-1]); if (_num == null) _num=1; _irradiance[_num-1] = value;  break;
      case "temp": int? _num = int.tryParse(_id[_id.length-1]); if (_num == null) _num=1; _temperature[_num-1] = value;  break;
      case "volt": _voltage = value;  break;
    }
  }
}

class Clamp {
  Clamp(String name) { _name = name;}
  String _name = "";
  String get name => _name;
}

class MeasureClock extends ChangeNotifier {
  String _dateTime = DateFormat('dd.MM.yy\nHH:mm:ss').format(DateTime.now());
  String get dateTime => _dateTime;
  MeasureClock() {
    Timer.periodic(Duration(seconds: 1), (Timer t) {
      _dateTime = DateFormat('dd.MM.yy\nHH:mm:ss').format(DateTime.now());
      notifyListeners();
    });
  }
}
