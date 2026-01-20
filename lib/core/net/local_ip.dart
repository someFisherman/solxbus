import 'dart:io';

/// Returns the best local private IPv4 address of the device.
/// - Prefer Wi-Fi interfaces (iOS: en0, Android: wlan0)
/// - Ignore VPN/tunnel interfaces (utun/tun/ppp)
/// - Prefer 192.168.* over 10.* over 172.16–31.*
Future<String?> getLocalIPv4() async {
  final ifaces = await NetworkInterface.list(
    includeLoopback: false,
    type: InternetAddressType.IPv4,
  );

  // Remove typical VPN/tunnel interfaces first
  final filtered = ifaces.where((i) {
    final n = i.name.toLowerCase();
    if (n.startsWith('utun')) return false; // iOS VPN
    if (n.contains('tun')) return false;    // tun0, etc.
    if (n.contains('ppp')) return false;    // ppp0, etc.
    return true;
  }).toList();

  // Prefer Wi-Fi-like interface names first
  final ordered = <NetworkInterface>[
    ...filtered.where((i) => i.name.toLowerCase() == 'en0'),   // iOS Wi-Fi
    ...filtered.where((i) => i.name.toLowerCase() == 'wlan0'), // Android Wi-Fi
    ...filtered,
  ];

  final candidates = <String>[];

  for (final iface in ordered) {
    for (final addr in iface.addresses) {
      final ip = addr.address;
      if (!addr.isLoopback && _isPrivateIPv4(ip)) {
        candidates.add(ip);
      }
    }
  }

  if (candidates.isEmpty) return null;

  // Prefer 192.168.* then 10.* then 172.16-31.*
  candidates.sort((a, b) => _rankIp(a).compareTo(_rankIp(b)));
  return candidates.first;
}

/// Converts an IPv4 address into a /24 CIDR network
/// Example: 192.168.0.23 → 192.168.0.0/24
String cidrFromIp(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return '192.168.0.0/24';
  return '${parts[0]}.${parts[1]}.${parts[2]}.0/24';
}

/// Ranking to prefer typical home LAN ranges first.
int _rankIp(String ip) {
  if (ip.startsWith('192.168.')) return 0;
  if (ip.startsWith('10.')) return 1;
  if (ip.startsWith('172.')) return 2;
  return 9;
}

/// Checks if IPv4 is in private ranges (RFC1918)
bool _isPrivateIPv4(String ip) {
  final parts = ip.split('.');
  if (parts.length != 4) return false;

  final p0 = int.tryParse(parts[0]);
  final p1 = int.tryParse(parts[1]);
  if (p0 == null || p1 == null) return false;

  // 10.0.0.0/8
  if (p0 == 10) return true;

  // 172.16.0.0 – 172.31.255.255
  if (p0 == 172 && p1 >= 16 && p1 <= 31) return true;

  // 192.168.0.0/16
  if (p0 == 192 && p1 == 168) return true;

  return false;
}
