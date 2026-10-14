import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: CameraSyncScreen(),
  ));
}

class CameraSyncScreen extends StatefulWidget {
  const CameraSyncScreen({super.key});

  @override
  State<CameraSyncScreen> createState() => _CameraSyncScreenState();
}

class _CameraSyncScreenState extends State<CameraSyncScreen> {
  final _domainController = TextEditingController(text: "mycam.ddns.net");
  final _nvrIpController = TextEditingController(text: "192.168.1.100");
  final _portController = TextEditingController(text: "80");
  final _userController = TextEditingController(text: "admin");
  final _pwdController = TextEditingController(text: "Password123@");
  final _channelController = TextEditingController(text: "1");

  String _deviceType = "hikvision";
  String _statusLog = "Sẵn sàng hoạt động";
  bool _isLoading = false;

  Future<String?> _resolveHost(String host) async {
    try {
      final results = await InternetAddress.lookup(host);
      if (results.isNotEmpty) {
        return results.first.address;
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  Future<void> _handleSync() async {
    setState(() {
      _isLoading = true;
      _statusLog = "Đang phân giải DNS tên miền...";
    });

    final domain = _domainController.text.trim();
    final nvrIp = _nvrIpController.text.trim();
    final port = _portController.text.trim();
    final user = _userController.text.trim();
    final pwd = _pwdController.text.trim();
    final channel = int.tryParse(_channelController.text.trim()) ?? 1;

    final resolvedIp = await _resolveHost(domain);
    if (resolvedIp == null) {
      setState(() {
        _isLoading = false;
        _statusLog = "❌ Lỗi: Không thể phân giải DNS từ '$domain'. Vui lòng kiểm tra lại tên miền.";
      });
      return;
    }

    setState(() {
      _statusLog = "Đã tìm thấy IP: $resolvedIp\nĐang gửi lệnh tới thiết bị...";
    });

    try {
      if (_deviceType == "dahua") {
        final idx = channel - 1;
        final uri = Uri.parse("http://$nvrIp:$port/cgi-bin/configManager.cgi?action=setConfig&RemoteDevice[$idx].Address=$resolvedIp");
        final authHeader = 'Basic ${base64Encode(utf8.encode('$user:$pwd'))}';
        
        final res = await http.get(uri, headers: {
          'Authorization': authHeader,
        }).timeout(const Duration(seconds: 7));

        if (res.statusCode == 200 && res.body.contains("OK")) {
          _statusLog = " Thành công!\n- Kênh: $channel\n- Thiết bị: Dahua\n- IP mới: $resolvedIp";
        } else {
          _statusLog = "❌ Lỗi Dahua (HTTP ${res.statusCode}):\n${res.body}";
        }
      } else {
        final uri = Uri.parse("http://$nvrIp:$port/ISAPI/ContentMgmt/InputProxy/channels/$channel");
        final authHeader = 'Basic ${base64Encode(utf8.encode('$user:$pwd'))}';
        final xmlBody = '''
        <InputProxyChannel xmlns="http://www.hikvision.com/ver20/XMLSchema" version="2.0">
          <id>$channel</id>
          <sourceInputPortDescriptor>
            <ipAddress>$resolvedIp</ipAddress>
          </sourceInputPortDescriptor>
        </InputProxyChannel>
        ''';

        final res = await http.put(
          uri,
          headers: {
            'Authorization': authHeader,
            'Content-Type': 'application/xml',
          },
          body: xmlBody,
        ).timeout(const Duration(seconds: 7));

        if (res.statusCode == 200 || res.statusCode == 204) {
          _statusLog = " Thành công!\n- Kênh: $channel\n- Thiết bị: Hikvision\n- IP mới: $resolvedIp";
        } else {
          _statusLog = "❌ Lỗi Hikvision (HTTP ${res.statusCode}):\n${res.body}";
        }
      }
    } catch (e) {
      _statusLog = "❌ Lỗi kết nối thiết bị: $e";
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Camera IP Sync Tool"),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _domainController,
              decoration: const InputDecoration(labelText: "Tên miền DDNS camera nguồn", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nvrIpController,
                    decoration: const InputDecoration(labelText: "IP NVR / Đầu ghi đích", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _portController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Port", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _userController,
                    decoration: const InputDecoration(labelText: "Username", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _pwdController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _channelController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: "Kênh (Channel)", border: OutlineInputBorder()),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _deviceType,
                    decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Loại thiết bị"),
                    items: const [
                      DropdownMenuItem(value: "hikvision", child: Text("Hikvision")),
                      DropdownMenuItem(value: "dahua", child: Text("Dahua")),
                    ],
                    onChanged: (val) => setState(() => _deviceType = val!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSync,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueGrey,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text("Phân giải DNS & Cập nhật IP", style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black26),
              ),
              child: Text(
                _statusLog,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
