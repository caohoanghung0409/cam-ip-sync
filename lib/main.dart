import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NoiDayApp());
}

class Member {
  final String name;
  final String shortName;
  final Color themeColor;

  const Member({
    required this.name,
    required this.shortName,
    required this.themeColor,
  });
}

class DutyShift {
  final DateTime date;
  final String assignedPerson;
  final bool isHoliday;
  final String? holidayName;

  DutyShift({
    required this.date,
    required this.assignedPerson,
    this.isHoliday = false,
    this.holidayName,
  });
}

class NoiDayApp extends StatelessWidget {
  const NoiDayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NỔI DẬY',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00796B)),
        useMaterial3: true,
      ),
      home: const MainDutyScreen(),
    );
  }
}

class MainDutyScreen extends StatefulWidget {
  const MainDutyScreen({super.key});

  @override
  State<MainDutyScreen> createState() => _MainDutyScreenState();
}

class _MainDutyScreenState extends State<MainDutyScreen> {
  // Thứ tự xoay tua cố định: SÂM -> MINH -> TRINH -> HƯNG
  final List<Member> members = const [
    Member(name: "NGUYỄN THỊ SÂM", shortName: "SÂM", themeColor: Colors.deepOrange),
    Member(name: "NGUYỄN NGỌC HOÀNG MINH", shortName: "MINH", themeColor: Colors.blue),
    Member(name: "LÂM TỐ TRINH", shortName: "TRINH", themeColor: Colors.purple),
    Member(name: "CAO HOÀNG HƯNG", shortName: "HƯNG", themeColor: Colors.teal),
  ];

  // Mốc gốc chuẩn xác: Thứ 7 ngày 17/10/2026 là ca của SÂM (index 0)
  static final DateTime baseSaturday = DateTime(2026, 10, 17);

  DateTime _currentDate = DateTime.now();
  bool _isOnlineTime = false;
  bool _isLoadingTime = true;

  @override
  void initState() {
    super.initState();
    _fetchInternetTime();
  }

  // Lấy giờ thực từ Internet (GMT+7)
  Future<void> _fetchInternetTime() async {
    try {
      final res = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Ho_Chi_Minh'))
          .timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final internetDateStr = data['datetime'];
        final parsedDate = DateTime.parse(internetDateStr);

        if (mounted) {
          setState(() {
            _currentDate = parsedDate;
            _isOnlineTime = true;
            _isLoadingTime = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentDate = DateTime.now();
        _isOnlineTime = false;
        _isLoadingTime = false;
      });
    }
  }

  // Nhận diện ngày lễ cố định rơi vào Thứ 7
  static String? checkHoliday(DateTime date) {
    if (date.month == 1 && date.day == 1) return "Tết Dương Lịch";
    if (date.month == 4 && date.day == 30) return "Giải Phóng Miền Nam";
    if (date.month == 5 && date.day == 1) return "Quốc Tế Lao Động";
    if (date.month == 9 && (date.day >= 1 && date.day <= 3)) return "Quốc Khánh 2/9";
    return null;
  }

  // Tính ca trực của tuần hiện tại theo giờ thực
  DutyShift _calculateThisWeekDuty(DateTime now) {
    DateTime today = DateTime(now.year, now.month, now.day);
    int daysUntilSaturday = 6 - today.weekday;
    DateTime thisSaturday = today.add(Duration(days: daysUntilSaturday));

    int diffDays = thisSaturday.difference(baseSaturday).inDays;
    int diffWeeks = (diffDays / 7).round();
    int personIndex = (diffWeeks % members.length + members.length) % members.length;

    String person = members[personIndex].name;
    String? holiday = checkHoliday(thisSaturday);

    return DutyShift(
      date: thisSaturday,
      assignedPerson: person,
      isHoliday: holiday != null,
      holidayName: holiday,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentDuty = _calculateThisWeekDuty(_currentDate);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF00796B),
        leading: const Padding(
          padding: EdgeInsets.all(10.0),
          child: CircleAvatar(
            backgroundColor: Colors.white24,
            child: Icon(Icons.flash_on, color: Colors.amber, size: 20),
          ),
        ),
        title: const Text(
          "NỔI DẬY - LỊCH TRỰC",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 18, letterSpacing: 0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Làm mới giờ mạng",
            icon: _isLoadingTime
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              setState(() => _isLoadingTime = true);
              _fetchInternetTime();
            },
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner hiển thị ca trực tuần này
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            _isOnlineTime ? Icons.wifi : Icons.signal_wifi_off,
                            color: _isOnlineTime ? Colors.lightGreenAccent : Colors.white60,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isOnlineTime ? "GIỜ INTERNET (VIỆT NAM)" : "GIỜ HỆ THỐNG ĐIỆN THOẠI",
                            style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: currentDuty.isHoliday ? Colors.redAccent : Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${currentDuty.date.day.toString().padLeft(2, '0')}/${currentDuty.date.month.toString().padLeft(2, '0')}/${currentDuty.date.year}",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: currentDuty.isHoliday ? Colors.white : Colors.black87,
                          ),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currentDuty.isHoliday ? "${currentDuty.assignedPerson} (MIỄN TRỰC)" : currentDuty.assignedPerson,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    currentDuty.isHoliday
                        ? "Trùng dịp lễ: ${currentDuty.holidayName} (Được nghỉ)"
                        : "Đến lượt cày cuốc, chuẩn bị tinh thần!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Danh sách thành viên
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "THỨ TỰ XOAY TUA CA TRỰC",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: members.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final m = members[idx];
                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => YearRangeMemberDetailScreen(
                                  member: m,
                                  members: members,
                                  initialYear: _currentDate.year >= 2026 && _currentDate.year <= 2050
                                      ? _currentDate.year
                                      : 2026,
                                ),
                              ),
                            );
                          },
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: m.themeColor.withOpacity(0.15),
                                  foregroundColor: m.themeColor,
                                  radius: 20,
                                  child: Text("${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                      const Text(
                                        "Tra cứu lịch trực xuyên suốt đến năm 2050",
                                        style: TextStyle(fontSize: 12, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// Màn hình chi tiết hỗ trợ chọn bất kỳ năm nào từ 2026 đến 2050
class YearRangeMemberDetailScreen extends StatefulWidget {
  final Member member;
  final List<Member> members;
  final int initialYear;

  const YearRangeMemberDetailScreen({
    super.key,
    required this.member,
    required this.members,
    required this.initialYear,
  });

  @override
  State<YearRangeMemberDetailScreen> createState() => _YearRangeMemberDetailScreenState();
}

class _YearRangeMemberDetailScreenState extends State<YearRangeMemberDetailScreen> {
  late int _selectedYear;
  // Danh sách năm từ 2026 đến 2050 (25 năm)
  final List<int> _years = List.generate(25, (index) => 2026 + index);

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
  }

  // Thuật toán tính nhanh toàn bộ các thứ 7 của một năm cụ thể cho thành viên
  List<DutyShift> _getShiftsForYear(int year) {
    List<DutyShift> shifts = [];
    DateTime date = DateTime(year, 1, 1);

    // Tìm thứ Bảy đầu tiên của năm đó
    int daysUntilFirstSat = (6 - date.weekday + 7) % 7;
    DateTime saturday = date.add(Duration(days: daysUntilFirstSat));

    while (saturday.year == year) {
      int diffDays = saturday.difference(_MainDutyScreenState.baseSaturday).inDays;
      int diffWeeks = (diffDays / 7).round();
      int personIndex = (diffWeeks % widget.members.length + widget.members.length) % widget.members.length;

      String assignedName = widget.members[personIndex].name;
      if (assignedName == widget.member.name) {
        String? holiday = _MainDutyScreenState.checkHoliday(saturday);
        shifts.add(DutyShift(
          date: saturday,
          assignedPerson: assignedName,
          isHoliday: holiday != null,
          holidayName: holiday,
        ));
      }

      saturday = saturday.add(const Duration(days: 7));
    }
    return shifts;
  }

  @override
  Widget build(BuildContext context) {
    final memberShiftsInYear = _getShiftsForYear(_selectedYear);
    final actualCount = memberShiftsInYear.where((s) => !s.isHoliday).length;
    final holidayCount = memberShiftsInYear.where((s) => s.isHoliday).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(widget.member.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00796B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Hộp chọn năm Dropdown thông minh (Từ 2026 đến 2050)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.teal.shade300, width: 1.5),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.08), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.calendar_month, color: Color(0xFF00796B)),
                      SizedBox(width: 8),
                      Text("Chọn năm xem lịch:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    ],
                  ),
                  DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedYear,
                      icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00796B), size: 30),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00796B)),
                      items: _years.map((int year) {
                        return DropdownMenuItem<int>(
                          value: year,
                          child: Text("NĂM $year"),
                        );
                      }).toList(),
                      onChanged: (int? newYear) {
                        if (newYear != null) {
                          setState(() => _selectedYear = newYear);
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Thống kê tổng số ca trong năm đó
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                children: [
                  Text("Tổng kết năm $_selectedYear", style: const TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBox("Ca thực tế", "$actualCount ca", Colors.teal),
                      Container(height: 28, width: 1, color: Colors.grey.shade300),
                      _buildStatBox("Miễn trực (Lễ)", "$holidayCount ca", Colors.deepOrange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Danh sách các ca trực của năm được chọn
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "CÁC THỨ BẢY TRỰC NĂM $_selectedYear (${memberShiftsInYear.length} LƯỢT)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 10),

            if (memberShiftsInYear.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20.0),
                child: Text("Không có ca trực nào trong năm này.", style: TextStyle(color: Colors.grey)),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: memberShiftsInYear.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final shift = memberShiftsInYear[idx];
                  final dateStr = "${shift.date.day.toString().padLeft(2, '0')}/${shift.date.month.toString().padLeft(2, '0')}/${shift.date.year}";

                  if (shift.isHoliday) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.beach_access, color: Colors.red, size: 18),
                              const SizedBox(width: 10),
                              Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                            ],
                          ),
                          Text(
                            "MIỄN TRỰC (${shift.holidayName})",
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.event_available, color: Colors.teal, size: 18),
                            const SizedBox(width: 10),
                            Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.teal.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            "ĐẾN LƯỢT TRỰC",
                            style: TextStyle(color: Colors.teal, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        )
                      ],
                    ),
                  );
                },
              ),

            const SizedBox(height: 25),
            ElevatedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back),
              label: const Text("QUAY LẠI", style: TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00796B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatBox(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}
