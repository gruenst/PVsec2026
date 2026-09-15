//import 'dart:js';
import 'dart:typed_data';
import 'dart:async';
import 'dart:io';
import 'package:usb_serial/usb_serial.dart';
import 'package:usb_serial/transaction.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:loracmd/models/MeasureModel.dart';

class LoraModel extends ChangeNotifier {
  UsbPort? _port;
  String _status = "Idle";
  List<Widget> _ports = [];
  StreamSubscription<String>? _subscription;
  Transaction<String>? _transaction;
  UsbDevice? _device;
  String _receivedText = "";
  String _commentText = " ";
  var _commentIcon = Icons.workspaces_outlined;
  int _clampNumber = 5;
  bool _disableSave = false, _disableMeasure = false, _disableClamps = false;
  MeasureModel _model = MeasureModel();
  StreamSubscription<UsbEvent>? _usbEventSubscription;

  String get status => _status;
  List<Widget> get ports => _ports.toList();
  UsbPort? get port => _port;
  String get receivedText => _receivedText;
  String get commentText => this._commentText;
  IconData get commentIcon => this._commentIcon;
  bool get disableSave => this._disableSave;
  bool get disableMeasure => this._disableMeasure;
  bool get disableClamps => this._disableClamps;

  // Initialize USB monitoring here instead of initState
  void initialize() {
    _usbEventSubscription = UsbSerial.usbEventStream!.listen((UsbEvent event) {
      _getPorts();
    });

    _getPorts();
  }

  void setMeasureModel(MeasureModel model) {
    _model = model;
    notifyListeners();
  }

  void sendMeasure() async {
    if (_port == null) {
      changeCommentIcon(Icons.flash_on);
      changeCommentText("<no device connected>");
      disableButton("all");
      notifyListeners();
      return;
    }
    // Removed null check for _model since it's now non-nullable

    String command = "MEASURE_" + _clampNumber.toString() + ";" + _model.stringID().text;
    String data = command + "\r\n";
    _disableMeasure = true;
    changeCommentText("measurement started... (" + _clampNumber.toString() + " clamps)");
    notifyListeners();
    await _port!.write(Uint8List.fromList(data.codeUnits));
  }

  void sendClampsOnly() async {
    if (_port == null) {
      changeCommentIcon(Icons.flash_on);
      changeCommentText("<no device connected>");
      disableButton("all");
      notifyListeners();
      return;
    }
    // Removed null check for _model since it's now non-nullable

    String command = "CLAMPS_" + _clampNumber.toString() + ";" + _model.stringID().text;
    String data = command + "\r\n";
    _disableClamps = true;
    changeCommentText("clamp test... (" + _clampNumber.toString() + " clamps)");
    notifyListeners();
    await _port!.write(Uint8List.fromList(data.codeUnits));
  }

  Future<void> saveDataToFile() async {
    // Removed null check for _model since it's now non-nullable

    // append current measurement to buffer
    _model.addToDataBuffer();
    
    var dataLines = _model.dataBuffer;
    if (dataLines.isEmpty) {
      changeCommentText("no data to save");
      notifyListeners();
      return;
    }

    try {
      Directory dir = await getApplicationDocumentsDirectory();
      String filePath = "${dir.path}/measurement_data.txt";
      File file = File(filePath);
      await file.writeAsString("${dataLines.join('\n')}\n", mode: FileMode.append);
      _model.clearDataBuffer();
      changeCommentText("data saved to $filePath");
      changeCommentIcon(Icons.check_circle);
    } catch (e) {
      changeCommentText("save failed: $e");
      changeCommentIcon(Icons.error);
    } finally {
      _disableSave = false;
      notifyListeners();
    }
  }

  Future<bool> _connectTo(device) async {
    if (_subscription != null) {
      _subscription!.cancel();
      _subscription = null;
    }

    if (_transaction != null) {
      _transaction!.dispose();
      _transaction = null;
    }

    if (_port != null) {
      _port!.close();
      _port = null;
    }

    if (device == null) {
      _device = null;
      _status = "Disconnected";
      changeCommentIcon(Icons.flash_on);
      changeCommentText("<no device connected>");
      disableButton("all");
      notifyListeners();
      return true;
    }

    _port = await device.create();
    if (await (_port!.open()) != true) {
      _status = "Failed to open port";
      notifyListeners();
      return false;
    }
    _device = device;

    await _port!.setDTR(true);
    await _port!.setRTS(true);
    await _port!.setPortParameters(115200, UsbPort.DATABITS_8, UsbPort.STOPBITS_1, UsbPort.PARITY_NONE);

    _transaction = Transaction.stringTerminated(_port!.inputStream as Stream<Uint8List>, Uint8List.fromList([13, 10]));

    _subscription = _transaction!.stream.listen((String line) {
      if (line.startsWith("result;")) {
        line = line.substring(line.indexOf(';')+1);  //strip "result;" from message
        _receivedText = line;
        // Removed null check for _model since it's now non-nullable
        {
          var _satellites = ["clamp_1", "clamp_2", "clamp_3", "clamp_4", "clamp_5","clamp_6", "clamp_7", "clamp_8", "clamp_9", "clamp_0", "irr_1", "volt_1","irr_2", "tmod_1", "tmod_2"];
          var _strSplit = line.split(';');
          for (int i = 0; i < _satellites.length; i++) {
            int idx = _strSplit.indexOf(_satellites[i]);
            if (idx >= 0 && idx + 1 < _strSplit.length) {
              double? value = double.tryParse(_strSplit[idx + 1]);
              if ((value == null) || (value == 0)) {
                _model.setValues(_satellites[i], 0);
              }
              else {
                _model.setValues(_satellites[i], value);
              }
            }
          }
          // CRITICAL: Call evaluateMeasurement after setting values (replicates ws.onmessage calc)
          _model.evaluateMeasurement();
          changeCommentText("data received");
          changeCommentIcon(Icons.arrow_forward_sharp);
          enableButton("all");
        }
      }
      else if (line.startsWith("SAVED")) {
        changeCommentText("data saved!");
        enableButton("all");
      }
      else if (line.startsWith("DATA")) {
        _receivedText = line.substring(4);
        changeCommentText("data loaded");
      }
      notifyListeners();
    });

    _status = "Connected";
    changeCommentIcon(Icons.arrow_forward_sharp);
    changeCommentText("connected");
    enableButton("all");
    notifyListeners();
    return true;
  }

  void _getPorts() async {
    _ports = [];
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (!devices.contains(_device)) {
      _connectTo(null);
    }
    print(devices);

    devices.forEach((device) {
      _ports.add(ListTile(
          leading: Icon(Icons.usb),
          title: Text(device.productName!, overflow: TextOverflow.ellipsis),
          subtitle: Text(device.manufacturerName!, overflow: TextOverflow.ellipsis),
          trailing: ElevatedButton(
            child: Text(_device == device ? "Disconnect" : "Connect"),
            onPressed: () {
              _connectTo(_device == device ? null : device).then((res) {
                _getPorts();
              });
            },
          )));
    });

      print(_ports);
    notifyListeners();
  }

  @override
  void dispose() {
    // Clean up USB event subscription
    _usbEventSubscription?.cancel();
    // Clean up transaction
    _transaction?.dispose();
    // Clean up subscription
    _subscription?.cancel();
    // Disconnect port
    _connectTo(null);
    // Dispose ChangeNotifier
    super.dispose();
  }

  void changeCommentIcon(IconData newIcon) {
    _commentIcon = newIcon;
  }
  void changeCommentText(String newText) {
    _commentText = newText;
  }
  void update(){
    notifyListeners();
  }
  void disableButton (String _id) {
    switch (_id) {
      case "save": _disableSave = true;break;
      case "measure": _disableMeasure = true;break;
      case "clamps": _disableClamps = true;break;
      case "all": _disableSave = true;_disableMeasure=true;_disableClamps=true;break;
    }
  }
  void enableButton (String _id) {
    switch (_id) {
      case "save": _disableSave = false;break;
      case "measure": _disableMeasure = false;break;
      case "clamps": _disableClamps = false;break;
      case "all": _disableSave = false;_disableMeasure=false;_disableClamps=false;break;
    }
  }
}
