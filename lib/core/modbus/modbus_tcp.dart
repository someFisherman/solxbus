import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

class ModbusException implements Exception {
  final String message;
  ModbusException(this.message);
  @override
  String toString() => message;
}

class ModbusTcpClient {
  final String host;
  final int port;
  final int unitId;
  final Duration timeout;
  final bool keepAlive;

  Socket? _socket;
  int _txId = 1;

  ModbusTcpClient({
    required this.host,
    required this.port,
    required this.unitId,
    this.timeout = const Duration(seconds: 3),
    this.keepAlive = true,
  });

  Future<void> connect() async {
    if (_socket != null && keepAlive) return;
    _socket = await Socket.connect(host, port, timeout: timeout);
    _socket!.setOption(SocketOption.tcpNoDelay, true);
  }

  Future<void> close() async {
    final s = _socket;
    _socket = null;
    if (s != null) await s.close();
  }

  int _nextTx() {
    _txId = (_txId + 1) & 0xFFFF;
    if (_txId == 0) _txId = 1;
    return _txId;
  }

  void _ensureFcOk(int requestFc, int respFc) {
    if (respFc == (requestFc | 0x80)) {
      throw ModbusException("Modbus exception (FC $requestFc)");
    }
    if (respFc != requestFc) {
      throw ModbusException("Unexpected function code: $respFc (req $requestFc)");
    }
  }

  Future<Uint8List> _sendPdu(Uint8List pdu) async {
    await connect();
    final s = _socket!;
    final tx = _nextTx();

    final mbap = ByteData(7);
    mbap.setUint16(0, tx);
    mbap.setUint16(2, 0);
    mbap.setUint16(4, pdu.length + 1);
    mbap.setUint8(6, unitId);

    s.add(mbap.buffer.asUint8List());
    s.add(pdu);
    await s.flush();

    final hdr = await _readExactly(7);
    if (hdr.length != 7) throw ModbusException("Short MBAP header");

    final bd = ByteData.sublistView(hdr);
    final proto = bd.getUint16(2);
    final len = bd.getUint16(4);
    if (proto != 0) throw ModbusException("Unexpected protocol $proto");

    final remain = len - 1;
    final resp = await _readExactly(remain);
    return resp;
  }

  Future<Uint8List> _readExactly(int n) async {
    final s = _socket!;
    final completer = Completer<Uint8List>();
    final buf = BytesBuilder();

    late StreamSubscription sub;
    Timer? t;

    void doneError(Object e) {
      t?.cancel();
      sub.cancel();
      if (!completer.isCompleted) completer.completeError(e);
    }

    sub = s.listen((chunk) {
      buf.add(chunk);
      if (buf.length >= n) {
        t?.cancel();
        sub.cancel();
        final all = buf.takeBytes();
        completer.complete(Uint8List.sublistView(all, 0, n));
      }
    }, onError: doneError, onDone: () => doneError(ModbusException("Socket closed")));

    t = Timer(timeout, () => doneError(ModbusException("Timeout reading $n bytes")));
    return completer.future;
  }

  List<int> _decodeBits(Uint8List bytes, int count) {
    final out = <int>[];
    for (var i = 0; i < count; i++) {
      final byteIndex = i ~/ 8;
      final bitIndex = i % 8;
      final val = (bytes[byteIndex] >> bitIndex) & 1;
      out.add(val);
    }
    return out;
  }

  Uint8List _packCoils(List<int> bools01) {
    final out = BytesBuilder();
    for (var i = 0; i < bools01.length; i += 8) {
      var b = 0;
      for (var bit = 0; bit < 8; bit++) {
        final idx = i + bit;
        if (idx < bools01.length && bools01[idx] != 0) b |= (1 << bit);
      }
      out.add([b]);
    }
    return out.takeBytes();
  }

  Future<List<num>> read({
    required int fc,
    required int address,
    required int count,
    bool signed = false,
    double factor = 1.0,
  }) async {
    if (![1, 2, 3, 4].contains(fc)) {
      throw ArgumentError("read supports FC 1/2/3/4");
    }

    final pdu = ByteData(5);
    pdu.setUint8(0, fc);
    pdu.setUint16(1, address);
    pdu.setUint16(3, count);

    final resp = await _sendPdu(pdu.buffer.asUint8List());
    _ensureFcOk(fc, resp[0]);

    final byteCount = resp[1];
    final payload = resp.sublist(2, 2 + byteCount);

    if (fc == 1 || fc == 2) {
      final bits = _decodeBits(payload, count);
      return bits.map((e) => e).toList();
    } else {
      final regs = <num>[];
      final bd = ByteData.sublistView(payload);
      for (var i = 0; i < byteCount; i += 2) {
        var r = bd.getUint16(i);
        if (signed && r >= 0x8000) r = r - 0x10000;
        regs.add(r * factor);
      }
      return regs;
    }
  }

  Future<void> writeSingle({
    required int fc,
    required int address,
    required int valueRaw,
  }) async {
    if (fc == 5) {
      final raw = valueRaw != 0 ? 0xFF00 : 0x0000;
      final pdu = ByteData(5);
      pdu.setUint8(0, 5);
      pdu.setUint16(1, address);
      pdu.setUint16(3, raw);
      final resp = await _sendPdu(pdu.buffer.asUint8List());
      _ensureFcOk(5, resp[0]);
      return;
    }
    if (fc == 6) {
      final pdu = ByteData(5);
      pdu.setUint8(0, 6);
      pdu.setUint16(1, address);
      pdu.setUint16(3, valueRaw & 0xFFFF);
      final resp = await _sendPdu(pdu.buffer.asUint8List());
      _ensureFcOk(6, resp[0]);
      return;
    }
    throw ArgumentError("writeSingle supports FC5/FC6");
  }

  Future<void> writeMultiple({
    required int fc,
    required int address,
    required List<int> valuesRaw,
  }) async {
    if (fc == 15) {
      final payload = _packCoils(valuesRaw);
      final hdr = ByteData(6);
      hdr.setUint8(0, 15);
      hdr.setUint16(1, address);
      hdr.setUint16(3, valuesRaw.length);
      hdr.setUint8(5, payload.length);

      final pdu = BytesBuilder();
      pdu.add(hdr.buffer.asUint8List());
      pdu.add(payload);

      final resp = await _sendPdu(pdu.takeBytes());
      _ensureFcOk(15, resp[0]);
      return;
    }

    if (fc == 16) {
      final payload = BytesBuilder();
      for (final v in valuesRaw) {
        final b = ByteData(2)..setUint16(0, v & 0xFFFF);
        payload.add(b.buffer.asUint8List());
      }
      final pl = payload.takeBytes();

      final hdr = ByteData(6);
      hdr.setUint8(0, 16);
      hdr.setUint16(1, address);
      hdr.setUint16(3, valuesRaw.length);
      hdr.setUint8(5, pl.length);

      final pdu = BytesBuilder();
      pdu.add(hdr.buffer.asUint8List());
      pdu.add(pl);

      final resp = await _sendPdu(pdu.takeBytes());
      _ensureFcOk(16, resp[0]);
      return;
    }

    throw ArgumentError("writeMultiple supports FC15/FC16");
  }

  Future<List<int>> readWrite23({
    required int readAddress,
    required int readCount,
    required int writeAddress,
    required List<int> writeValuesRaw,
  }) async {
    final payload = BytesBuilder();
    for (final v in writeValuesRaw) {
      final b = ByteData(2)..setUint16(0, v & 0xFFFF);
      payload.add(b.buffer.asUint8List());
    }
    final pl = payload.takeBytes();

    final hdr = ByteData(10);
    hdr.setUint8(0, 23);
    hdr.setUint16(1, readAddress);
    hdr.setUint16(3, readCount);
    hdr.setUint16(5, writeAddress);
    hdr.setUint16(7, writeValuesRaw.length);
    hdr.setUint8(9, pl.length);

    final pdu = BytesBuilder();
    pdu.add(hdr.buffer.asUint8List());
    pdu.add(pl);

    final resp = await _sendPdu(pdu.takeBytes());
    _ensureFcOk(23, resp[0]);

    final byteCount = resp[1];
    final data = resp.sublist(2, 2 + byteCount);
    final bd = ByteData.sublistView(data);

    final out = <int>[];
    for (var i = 0; i < byteCount; i += 2) {
      out.add(bd.getUint16(i));
    }
    return out;
  }
}
