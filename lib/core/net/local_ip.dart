import 'dart:io';

/// Returns the first private IPv4 address of the device (e.g. 192.168.0.23)
Future<String?> getLocalIPv4() async {
  for (final iface in await NetworkInterface.list()) {
    for (final addr in iface.addresses) {
      if (addr.type == InternetAddressType.IPv4 &&
          !addr.isLoopback &&
          _isPrivateIPv4(addr.address)) {
        return addr.address;
      }
    }
  }
  return null;
}

/// Converts an IPv4 address into a /24 CIDR network
/// Example: 192.168.0.23 → 192.168.0.0/24
String cidrFromIp(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return '192.168.0.0/24';
  return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
}

/// Checks if IPv4 is in private ranges
bool _isPrivateIPv4(String ip) {
  final p = ip.split('.').map(int.parse).toList();

  // 10.0.0.0/8
  if (p[0] == 10) return true;

  // 172.16.0.0 – 172.31.255.255
  if (p[0] == 172 && p[1] >= 16 && p[1] <= 31) return true;

  // 192.168.0.0/16
  if (p[0] == 192 && p[1] == 168) return true;

  return false;
}
