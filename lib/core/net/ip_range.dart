import 'dart:math';

List<String> expandCidr(String cidr) {
  final parts = cidr.split("/");
  if (parts.length != 2) throw FormatException("CIDR muss wie 192.168.1.0/24 sein.");

  final baseIp = parts[0].trim();
  final prefix = int.parse(parts[1].trim());
  if (prefix < 0 || prefix > 32) throw FormatException("CIDR Prefix muss 0..32 sein.");

  final base = ipToInt(baseIp);
  final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  final network = base & mask;
  final broadcast = network | (~mask & 0xFFFFFFFF);

  if (prefix >= 31) {
    final start = network;
    final end = broadcast;
    return [for (int i = start; i <= end; i++) intToIp(i)];
  }

  final start = network + 1;
  final end = broadcast - 1;

  final size = end - start + 1;
  if (size > 4096) {
    throw FormatException("CIDR Range zu groß ($size IPs). Bitte kleiner wählen (z.B. /24 oder /26).");
  }

  return [for (int i = start; i <= end; i++) intToIp(i)];
}

List<String> expandStartEnd(String startIp, String endIp) {
  final start = ipToInt(startIp.trim());
  final end = ipToInt(endIp.trim());
  final a = min(start, end);
  final b = max(start, end);

  final size = b - a + 1;
  if (size > 4096) {
    throw FormatException("Range zu groß ($size IPs). Bitte kleiner wählen.");
  }

  return [for (int i = a; i <= b; i++) intToIp(i)];
}

int ipToInt(String ip) {
  final parts = ip.split(".");
  if (parts.length != 4) throw FormatException("Ungültige IP: $ip");
  final nums = parts.map((p) => int.parse(p)).toList();
  for (final n in nums) {
    if (n < 0 || n > 255) throw FormatException("Ungültige IP: $ip");
  }
  return (nums[0] << 24) | (nums[1] << 16) | (nums[2] << 8) | nums[3];
}

String intToIp(int v) {
  final a = (v >> 24) & 0xFF;
  final b = (v >> 16) & 0xFF;
  final c = (v >> 8) & 0xFF;
  final d = v & 0xFF;
  return "$a.$b.$c.$d";
}
