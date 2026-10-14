import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: HikConnectCloneApp(),
  ));
}

class CameraDevice {
  String name;
  String hostOrDomain; // IP hoặc tên miền DDNS
  int port;
  String username;
  String password;
  String brand; // 'HIKVISION', 'DAHUA', 'IMOU'
  bool isAutoResolve; // Thiết bị cần tự động phân giải DNS ra IP

  CameraDevice({
    required this.name,
    required this.hostOrDomain,
    this.port = 554,
    required this.username,
    required this.password,
    required this.brand,
    this.isAutoResolve = false,
  });
}

class HikConnectCloneApp extends StatefulWidget {
  const HikConnectCloneApp({super.key});

  @override
  State<HikConnectCloneApp> createState() => _HikConnectCloneAppState();
}

class _HikConnectCloneAppState extends State<HikConnectCloneApp> {
  int _currentIndex = 0;

  // Danh sách camera đã nạp
  final List<CameraDevice> _devices = [
    CameraDevice(
      name: "Camera Cổng (Auto DNS)",
      hostOrDomain: "a.ddns.net",
      port: 554,
      username: "admin",
      password: "Password123",
      brand: "HIKVISION",
      isAutoResolve: true, // Thiết bị đầu tiên cần phân giải IP
    ),
  ];

  late final Player _player;
  late final VideoController _videoController;
  String _activeIpDisplay = "Chưa kết nối";
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  // Hàm tự phân giải tên miền ra IP và tạo link RTSP
  Future<void> _playCamera(CameraDevice cam) async {
    setState(() {
      _isConnecting = true;
      _activeIpDisplay = "Đang kiểm tra kết nối & DNS...";
    });

    String targetIp = cam.hostOrDomain;

    // Nếu thiết bị được đánh dấu tự phân giải tên miền
    if (cam.isAutoResolve) {
      try {
        final lookup = await InternetAddress.lookup(cam.hostOrDomain);
        if (lookup.isNotEmpty) {
          targetIp = lookup.first.address;
        }
      } catch (e) {
        setState(() {
          _isConnecting = false;
          _activeIpDisplay = "Lỗi phân giải tên miền ${cam.hostOrDomain}";
        });
        return;
      }
    }

    // Tạo URL RTSP theo từng hãng
    String rtspUrl = "";
    if (cam.brand == "HIKVISION") {
      rtspUrl = "rtsp://${cam.username}:${cam.password}@$targetIp:${cam.port}/Streaming/Channels/101";
    } else {
      // DAHUA & IMOU dùng chung chuẩn luồng Dahua
      rtspUrl = "rtsp://${cam.username}:${cam.password}@$targetIp:${cam.port}/cam/realmonitor?channel=1&subtype=0";
    }

    setState(() {
      _activeIpDisplay = "Đang xem: $targetIp (Port: ${cam.port})";
      _isConnecting = false;
    });

    await _player.open(Media(rtspUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFD32F2F), // Màu đỏ thương hiệu Hik-Connect
        elevation: 0,
        title: Text(
          _currentIndex == 0 ? "Hik-Connect (Live View)" : "Quản lý thiết bị",
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.white),
            onPressed: () => _showAddDeviceDialog(),
          ),
        ],
      ),
      body: _currentIndex == 0 ? _buildLiveViewTab() : _buildDeviceListTab(),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFFD32F2F),
        unselectedItemColor: Colors.grey,
        onTap: (idx) => setState(() => _currentIndex = idx),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.videocam), label: "Xem trực tiếp"),
          BottomNavigationBarItem(icon: Icon(Icons.devices_other), label: "Thiết bị"),
        ],
      ),
    );
  }

  // Tab 1: Màn hình Live View giống Hik-Connect
  Widget _buildLiveViewTab() {
    return Column(
      children: [
        // Khung hiển thị Video
        AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Video(controller: _videoController),
                if (_isConnecting)
                  const CircularProgressIndicator(color: Colors.red),
              ],
            ),
          ),
        ),
        // Thanh thông tin trạng thái IP
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: Colors.white,
          child: Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: Colors.blueGrey),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activeIpDisplay,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Danh sách nhanh các camera để chọn xem
        Expanded(
          child: ListView.builder(
            itemCount: _devices.length,
            itemBuilder: (context, idx) {
              final cam = _devices[idx];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: cam.isAutoResolve ? Colors.red : Colors.blueGrey,
                  ),
                  title: Text(cam.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text("${cam.brand} - ${cam.hostOrDomain}"),
                  trailing: const Icon(Icons.play_circle_fill, color: Color(0xFFD32F2F), size: 32),
                  onTap: () => _playCamera(cam),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Tab 2: Danh sách quản lý thiết bị
  Widget _buildDeviceListTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _devices.length,
      itemBuilder: (context, idx) {
        final cam = _devices[idx];
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(cam.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(cam.brand, style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text("Địa chỉ: ${cam.hostOrDomain}:${cam.port}"),
                Text("Cơ chế: ${cam.isAutoResolve ? 'Tự phân giải tên miền -> IP' : 'IP tĩnh'}"),
              ],
            ),
          ),
        );
      },
    );
  }

  // Dialog thêm thiết bị
  void _showAddDeviceDialog() {
    final nameCtrl = TextEditingController();
    final hostCtrl = TextEditingController();
    final userCtrl = TextEditingController(text: "admin");
    final pwdCtrl = TextEditingController();
    String selectedBrand = "HIKVISION";
    bool autoDns = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text("Thêm thiết bị mới"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: "Tên camera")),
                TextField(controller: hostCtrl, decoration: const InputDecoration(labelText: "IP hoặc Domain DDNS")),
                TextField(controller: userCtrl, decoration: const InputDecoration(labelText: "Username")),
                TextField(controller: pwdCtrl, obscureText: true, decoration: const InputDecoration(labelText: "Password")),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedBrand,
                  items: const [
                    DropdownMenuItem(value: "HIKVISION", child: Text("Hikvision")),
                    DropdownMenuItem(value: "DAHUA", child: Text("Dahua")),
                    DropdownMenuItem(value: "IMOU", child: Text("Imou")),
                  ],
                  onChanged: (val) => setDialogState(() => selectedBrand = val!),
                  decoration: const InputDecoration(labelText: "Hãng sản xuất"),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text("Tự động phân giải DNS ra IP", style: TextStyle(fontSize: 13)),
                  value: autoDns,
                  onChanged: (val) => setDialogState(() => autoDns = val ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD32F2F)),
              onPressed: () {
                setState(() {
                  _devices.add(CameraDevice(
                    name: nameCtrl.text.isEmpty ? "Camera ${_devices.length + 1}" : nameCtrl.text,
                    hostOrDomain: hostCtrl.text.trim(),
                    username: userCtrl.text.trim(),
                    password: pwdCtrl.text.trim(),
                    brand: selectedBrand,
                    isAutoResolve: autoDns,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text("Lưu", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
