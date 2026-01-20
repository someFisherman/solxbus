import 'package:flutter/foundation.dart';

class AppState extends ChangeNotifier {
  // TCP connection
  String host = "192.168.1.1";
  int port = 502;
  int unitId = 1;
  double timeoutSec = 3.0;

  // RTU placeholders
  String rtuPort = "";
  int rtuBaud = 9600;
  String rtuParity = "N";
  int rtuStopBits = 1;

  // Logs
  final List<String> manualLog = [];
  final List<String> scanLog = [];
  final List<String> autoLog = [];

  void setHost(String v) { host = v; notifyListeners(); }
  void setPort(int v) { port = v; notifyListeners(); }
  void setUnit(int v) { unitId = v; notifyListeners(); }
  void setTimeout(double v) { timeoutSec = v; notifyListeners(); }

  void addManualLog(String s) { manualLog.add(s); notifyListeners(); }
  void clearManualLog() { manualLog.clear(); notifyListeners(); }

  void addScanLog(String s) { scanLog.add(s); notifyListeners(); }
  void clearScanLog() { scanLog.clear(); notifyListeners(); }

  void addAutoLog(String s) { autoLog.add(s); notifyListeners(); }
  void clearAutoLog() { autoLog.clear(); notifyListeners(); }
}
