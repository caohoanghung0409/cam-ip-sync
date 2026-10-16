import 'dart:convert';
import 'dart:math';
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
  final bool isSwapped;
  final String? originalPerson;

  DutyShift({
    required this.date,
    required this.assignedPerson,
    this.isHoliday = false,
    this.holidayName,
    this.isSwapped = false,
    this.originalPerson,
  });
}

// ================= THUẬT TOÁN ÂM LỊCH VIỆT NAM (CHUẨN DART) =================
class LunarDate {
  final int day;
  final int month;
  final int year;

  LunarDate(this.day, this.month, this.year);

  static int _jdFromDate(int dd, int mm, int yy) {
    int a = ((14 - mm) / 12).floor();
    int y = yy + 4800 - a;
    int m = mm + 12 * a - 3;
    int jd = dd + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - (y / 100).floor() + (y / 400).floor() - 32045;
    if (jd < 2299161) {
      jd = dd + ((153 * m + 2) / 5).floor() + 365 * y + (y / 4).floor() - 32083;
    }
    return jd;
  }

  static double _newMoon(int k) {
    double t = k / 1236.85;
    double t2 = t * t;
    double t3 = t2 * t;
    double dr = pi / 180.0;
    double jde = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jde += 0.00033 * sin((166.56 + 132.87 * t - 0.009173 * t2) * dr);
    double m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    double mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    double f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    double c1 = (0.1734 - 0.000393 * t) * sin(m * dr) + 0.0021 * sin(2 * m * dr);
    c1 -= 0.4068 * sin(mpr * dr) + 0.0161 * sin(2 * mpr * dr);
    c1 -= 0.0004 * sin(3 * mpr * dr);
    c1 += 0.0104 * sin(2 * f * dr) - 0.0051 * sin((m + mpr) * dr);
    c1 -= 0.0074 * sin((m - mpr) * dr) + 0.0004 * sin((2 * f + m) * dr);
    c1 -= 0.0004 * sin((2 * f - m) * dr) - 0.0006 * sin((2 * f + mpr) * dr);
    c1 += 0.0010 * sin((2 * f - mpr) * dr) + 0.0005 * sin((2 * mpr + m) * dr);
    return jde + c1;
  }

  static double _sunLongitude(double jdn) {
    double t = (jdn - 2451545.0) / 36525.0;
    double dr = pi / 180.0;
    double l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t * t;
    double m = 357.52910 + 35999.05030 * t - 0.0001559 * t * t - 0.00000048 * t * t * t;
    double c = (1.914600 - 0.004817 * t - 0.000014 * t * t) * sin(m * dr) +
        (0.019993 - 0.000101 * t) * sin(2 * m * dr) +
        0.000290 * sin(3 * m * dr);
    double theta = l0 + c;
    theta = theta - 360.0 * (theta / 360.0).floor();
    return theta * dr;
  }

  static int _getSunLongitude(int dayNumber, double timeZone) {
    return (_sunLongitude(dayNumber - 0.5 - timeZone / 24.0) / (pi / 6.0)).floor();
  }

  static int _getLunarMonth11(int yy, double timeZone) {
    double off = _jdFromDate(31, 12, yy) - 2415021.076998695;
    int k = (off / 29.53058868).floor();
    double nm = _newMoon(k);
    int sunLong = _getSunLongitude((nm + 0.5 + timeZone / 24.0).floor(), timeZone);
    if (sunLong >= 9) {
      nm = _newMoon(k - 1);
    }
    return (nm + 0.5 + timeZone / 24.0).floor();
  }

  static LunarDate fromSolar(int dd, int mm, int yy, [double timeZone = 7.0]) {
    int dayNumber = _jdFromDate(dd, mm, yy);
    int k = ((dayNumber - 2415021.076998695) / 29.53058868).floor();
    int lastNm = (_newMoon(k) + 0.5 + timeZone / 24.0).floor();
    if (lastNm > dayNumber) {
      lastNm = (_newMoon(k - 1) + 0.5 + timeZone / 24.0).floor();
    }
    int a11 = _getLunarMonth11(yy, timeZone);
    int b11 = a11;
    int lunarYear = yy;
    if (dayNumber < a11) {
      a11 = _getLunarMonth11(yy - 1, timeZone);
      lunarYear = yy - 1;
    } else {
      b11 = _getLunarMonth11(yy + 1, timeZone);
      if (dayNumber >= b11) {
        lunarYear = yy + 1;
        a11 = b11;
      }
    }
    int lunarDay = dayNumber - lastNm + 1;
    int diff = ((lastNm - a11) / 29).round();
    int lunarMonth = diff + 11;
    if (lunarMonth > 12) {
      lunarMonth -= 12;
    }
    return LunarDate(lunarDay, lunarMonth, lunarYear);
  }
}

// ================= GIAO DIỆN CHÍNH =================
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
  static final List<Member> baseMembers = const [
    Member(name: "NGUYỄN THỊ SÂM", shortName: "SÂM", themeColor: Colors.deepOrange),
    Member(name: "NGUYỄN NGỌC HOÀNG MINH", shortName: "MINH", themeColor: Colors.blue),
    Member(name: "LÂM TỐ TRINH", shortName: "TRINH", themeColor: Colors.purple),
    Member(name: "CAO HOÀNG HƯNG", shortName: "HƯNG", themeColor: Colors.teal),
  ];

  static final DateTime baseSaturday = DateTime(2026, 10, 17);
  static const String sheetId = "12LwsnfhdvnT9WqZAiXy6lrA0GrEFpdA1IUXp5YfHf0c";
  static const String scriptApiUrl =
      "https://script.google.com/macros/s/AKfycbwC4lFvh_9Wd_P5KA5yih3-4uqqB3Wm9Yeila5GSuImfryloKEO4FYfQsICVx937vTM/exec";

  static Map<String, String> customHolidays = {};
  static Map<String, Map<String, String>> swapShifts = {};

  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;

  static final Map<String, String> holidaysMap = {
    "1-1": "Tết Dương Lịch",
    "30-4": "Giải Phóng Miền Nam",
    "1-5": "Quốc Tế Lao Động",
    "1-9": "Nghỉ Lễ Quốc Khánh",
    "2-9": "Quốc Khánh 2/9",
    "3-9": "Nghỉ Lễ Quốc Khánh",
    "24-11": "Ngày Lễ 24/11",
  };

  @override
  void initState() {
    super.initState();
    _initData();
  }

  Future<void> _initData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchInternetTime(),
      _fetchGoogleSheetHolidays(),
      _fetchSwappedShifts(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchGoogleSheetHolidays() async {
    final String url = "https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv";
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final lines = const LineSplitter().convert(res.body);
        Map<String, String> parsed = {};
        for (int i = 1; i < lines.length; i++) {
          final row = lines[i].replaceAll('"', '').split(',');
          if (row.isNotEmpty && row[0].trim().isNotEmpty) {
            String rawDate = row[0].trim();
            String reason = row.length > 1 && row[1].trim().isNotEmpty ? row[1].trim() : "Nghỉ công ty";
            String formattedDate = _normalizeDate(rawDate);
            if (formattedDate.isNotEmpty) {
              parsed[formattedDate] = reason;
            }
          }
        }
        customHolidays = parsed;
      }
    } catch (_) {}
  }

  Future<void> _fetchSwappedShifts() async {
    try {
      final res = await http.get(Uri.parse(scriptApiUrl)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded["status"] == "success" && decoded["data"] != null) {
          Map<String, Map<String, String>> parsedSwap = {};
          for (var item in decoded["data"]) {
            String d1 = _normalizeDate(item["ngay1"]?.toString() ?? "");
            String d2 = _normalizeDate(item["ngay2"]?.toString() ?? "");
            String p1 = item["nguoi1"]?.toString() ?? "";
            String p2 = item["nguoi2"]?.toString() ?? "";

            if (d1.isNotEmpty && p2.isNotEmpty) {
              parsedSwap[d1] = {"nguoiGoc": p1, "nguoiDoi": p2};
            }
            if (d2.isNotEmpty && p1.isNotEmpty) {
              parsedSwap[d2] = {"nguoiGoc": p2, "nguoiDoi": p1};
            }
          }
          swapShifts = parsedSwap;
        }
      }
    } catch (_) {}
  }

  static String _normalizeDate(String input) {
    try {
      if (input.contains('/')) {
        final parts = input.split('/');
        if (parts.length == 3) {
          String d = parts[0].trim().padLeft(2, '0');
          String m = parts[1].trim().padLeft(2, '0');
          String y = parts[2].trim();
          return "$y-$m-$d";
        }
      } else if (input.contains('-')) {
        final parts = input.split('-');
        if (parts.length == 3) {
          String y = parts[0].trim();
          String m = parts[1].trim().padLeft(2, '0');
          String d = parts[2].trim().padLeft(2, '0');
          return "$y-$m-$d";
        }
      }
    } catch (_) {}
    return "";
  }

  Future<void> _fetchInternetTime() async {
    try {
      final res = await http.get(Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Ho_Chi_Minh')).timeout(const Duration(seconds: 2));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        _currentDate = DateTime.parse(data['datetime']);
      }
    } catch (_) {
      _currentDate = DateTime.now();
    }
  }

  static String? checkHoliday(DateTime date) {
    String dateKey = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
    if (customHolidays.containsKey(dateKey)) {
      return customHolidays[dateKey];
    }
    String key = "${date.day}-${date.month}";
    if (holidaysMap.containsKey(key)) {
      return holidaysMap[key];
    }
    LunarDate lunar = LunarDate.fromSolar(date.day, date.month, date.year);
    if (lunar.month == 12 && (lunar.day == 29 || lunar.day == 30)) {
      return "Nghỉ Tết Nguyên Đán";
    }
    if (lunar.month == 1 && (lunar.day >= 1 && lunar.day <= 5)) {
      return "Tết Nguyên Đán (Mùng ${lunar.day})";
    }
    if (lunar.month == 3 && lunar.day == 10) {
      return "Giỗ Tổ Hùng Vương (10/3 ÂL)";
    }
    return null;
  }

  DateTime _getThisSaturday(DateTime now) {
    DateTime today = DateTime(now.year, now.month, now.day);
    int daysUntilSaturday = 6 - today.weekday;
    return today.add(Duration(days: daysUntilSaturday));
  }

  int _calculateCurrentWeekDiff(DateTime now) {
    DateTime thisSaturday = _getThisSaturday(now);
    int diffDays = thisSaturday.difference(baseSaturday).inDays;
    return (diffDays / 7).round();
  }

  DutyShift _calculateThisWeekDuty(DateTime now) {
    DateTime thisSaturday = _getThisSaturday(now);
    int diffWeeks = _calculateCurrentWeekDiff(now);
    int personIndex = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;

    String defaultPerson = baseMembers[personIndex].name;
    String assignedPerson = defaultPerson;
    bool isSwapped = false;

    String dateKey = "${thisSaturday.year}-${thisSaturday.month.toString().padLeft(2, '0')}-${thisSaturday.day.toString().padLeft(2, '0')}";
    if (swapShifts.containsKey(dateKey)) {
      assignedPerson = swapShifts[dateKey]!["nguoiDoi"]!;
      isSwapped = true;
    }

    String? holiday = checkHoliday(thisSaturday);
    return DutyShift(
      date: thisSaturday,
      assignedPerson: assignedPerson,
      isHoliday: holiday != null,
      holidayName: holiday,
      isSwapped: isSwapped,
      originalPerson: defaultPerson,
    );
  }

  List<Map<String, dynamic>> _getRotatedMembersWithDate(DateTime now) {
    DateTime thisSaturday = _getThisSaturday(now);
    int diffWeeks = _calculateCurrentWeekDiff(now);
    int startIndex = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;

    List<Map<String, dynamic>> rotated = [];
    for (int i = 0; i < baseMembers.length; i++) {
      final baseMember = baseMembers[(startIndex + i) % baseMembers.length];
      final targetSat = thisSaturday.add(Duration(days: i * 7));
      final holiday = checkHoliday(targetSat);

      String dateKey = "${targetSat.year}-${targetSat.month.toString().padLeft(2, '0')}-${targetSat.day.toString().padLeft(2, '0')}";
      Member currentMember = baseMember;
      bool isSwapped = false;
      String? originalName;

      if (swapShifts.containsKey(dateKey)) {
        String swapToName = swapShifts[dateKey]!["nguoiDoi"]!;
        currentMember = baseMembers.firstWhere((m) => m.name == swapToName || m.shortName == swapToName, orElse: () => baseMember);
        isSwapped = true;
        originalName = baseMember.name;
      }

      String timelineText = (i == 0) ? "Trực tuần này" : (i == 1 ? "Tuần tới" : "$i tuần nữa");
      final dateStr = "${targetSat.day.toString().padLeft(2, '0')}/${targetSat.month.toString().padLeft(2, '0')}/${targetSat.year}";

      rotated.add({
        "member": currentMember,
        "baseMember": baseMember,
        "date": targetSat,
        "dateKey": dateKey,
        "dateStr": dateStr,
        "timelineText": timelineText,
        "isHoliday": holiday != null,
        "holidayName": holiday,
        "isSwapped": isSwapped,
        "originalName": originalName,
      });
    }
    return rotated;
  }

  // Lấy các ngày thứ Bảy trực sắp tới của 1 thành viên
  static List<DateTime> getUpcomingSaturdaysForMember(String memberName, DateTime fromDate) {
    List<DateTime> list = [];
    DateTime sat = fromDate;
    if (sat.weekday != DateTime.saturday) {
      sat = sat.add(Duration(days: (6 - sat.weekday + 7) % 7));
    }
    for (int i = 0; i < 30; i++) {
      int diffDays = sat.difference(baseSaturday).inDays;
      int diffWeeks = (diffDays / 7).round();
      int personIdx = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;
      if (baseMembers[personIdx].name == memberName) {
        list.add(sat);
      }
      sat = sat.add(const Duration(days: 7));
      if (list.length >= 6) break;
    }
    return list;
  }

  // Hộp thoại đổi ca chọn đích danh ngày trực của người kia
  void showTwoWaySwapDialog(BuildContext context, DateTime sourceDate, String sourcePerson) {
    final dateStr = "${sourceDate.day.toString().padLeft(2, '0')}/${sourceDate.month.toString().padLeft(2, '0')}/${sourceDate.year}";
    final otherMembers = baseMembers.where((m) => m.name != sourcePerson).toList();

    Member targetMember = otherMembers.first;
    List<DateTime> targetDates = getUpcomingSaturdaysForMember(targetMember.name, _currentDate);
    DateTime? selectedTargetDate = targetDates.isNotEmpty ? targetDates.first : null;
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.swap_horiz, color: Color(0xFF00796B), size: 28),
                SizedBox(width: 8),
                Text("HOÁN ĐỔI CA TRỰC", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17, color: Color(0xFF00796B))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(8)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ca của bạn: $sourcePerson", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
                        Text("Ngày: Thứ Bảy, $dateStr", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("1. Chọn người muốn đổi ca cùng:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<Member>(
                    value: targetMember,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: otherMembers.map((m) {
                      return DropdownMenuItem<Member>(
                        value: m,
                        child: Text(m.name, style: TextStyle(fontWeight: FontWeight.bold, color: m.themeColor, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() {
                          targetMember = val;
                          targetDates = getUpcomingSaturdaysForMember(targetMember.name, _currentDate);
                          selectedTargetDate = targetDates.isNotEmpty ? targetDates.first : null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  Text("2. Chọn ca trực của ${targetMember.shortName} để đổi:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  if (targetDates.isEmpty)
                    const Text("Không tìm thấy ngày trực sắp tới", style: TextStyle(color: Colors.red, fontSize: 12))
                  else
                    DropdownButtonFormField<DateTime>(
                      value: selectedTargetDate,
                      decoration: InputDecoration(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      items: targetDates.map((d) {
                        final s = "Thứ Bảy, ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}";
                        return DropdownMenuItem<DateTime>(value: d, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setDialogState(() => selectedTargetDate = val);
                        }
                      },
                    ),
                  const SizedBox(height: 14),
                  const Text("Lý do đổi (tùy chọn):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: "Ví dụ: Bận việc gia đình...",
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY", style: TextStyle(color: Colors.grey))),
              ElevatedButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text("XÁC NHẬN HOÁN ĐỔI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedTargetDate == null) return;
                  Navigator.pop(ctx);
                  await sendTwoWaySwapRequest(sourceDate, sourcePerson, selectedTargetDate!, targetMember.name, reasonController.text);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // Gửi lệnh đổi ca qua GET để chống lỗi CORS trên web
  Future<void> sendTwoWaySwapRequest(DateTime d1, String p1, DateTime d2, String p2, String note) async {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Đang ghi nhận đổi ca lên Google Sheets..."), duration: Duration(seconds: 2)),
    );

    final sD1 = "${d1.year}-${d1.month.toString().padLeft(2, '0')}-${d1.day.toString().padLeft(2, '0')}";
    final sD2 = "${d2.year}-${d2.month.toString().padLeft(2, '0')}-${d2.day.toString().padLeft(2, '0')}";

    final url = Uri.parse(scriptApiUrl).replace(queryParameters: {
      "action": "swap",
      "ngay1": sD1,
      "nguoi1": p1,
      "ngay2": sD2,
      "nguoi2": p2,
      "ghiChu": note.isEmpty ? "Đổi ca qua App" : note,
    });

    try {
      final res = await http.get(url).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Hoán đổi ca thành công!"), backgroundColor: Colors.teal),
        );
        await _fetchSwappedShifts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi máy chủ: ${res.statusCode}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Lỗi kết nối: $e"), backgroundColor: Colors.red),
      );
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentDuty = _calculateThisWeekDuty(_currentDate);
    final rotatedList = _getRotatedMembersWithDate(_currentDate);

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
            tooltip: "Đồng bộ & Làm mới",
            icon: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _initData,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
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
                      const Text(
                        "TRỰC THỨ BẢY TUẦN NÀY",
                        style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
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
                  if (currentDuty.isSwapped)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        "🔄 Đã đổi ca: ${currentDuty.assignedPerson} trực thay ${currentDuty.originalPerson}",
                        style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Text(
                    currentDuty.isHoliday ? "Trùng dịp nghỉ: ${currentDuty.holidayName} (Được nghỉ)" : "Đến lượt cày cuốc, chuẩn bị tinh thần!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  if (!currentDuty.isHoliday) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text("Đổi ca tuần này", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF00796B),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        onPressed: () => showTwoWaySwapDialog(context, currentDuty.date, currentDuty.assignedPerson),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "THỨ TỰ XOAY TUA (KÈM NGÀY TRỰC CỤ THỂ)",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rotatedList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final item = rotatedList[idx];
                      final Member m = item["member"];
                      final String timeline = item["timelineText"];
                      final String dateStr = item["dateStr"];
                      final DateTime targetSat = item["date"];
                      final bool isHoliday = item["isHoliday"];
                      final String? holidayName = item["holidayName"];
                      final bool isSwapped = item["isSwapped"];
                      final String? originalName = item["originalName"];
                      final bool isCurrentWeek = (idx == 0);

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
                                  members: _MainDutyScreenState.baseMembers,
                                  initialYear: _currentDate.year >= 2026 && _currentDate.year <= 2050 ? _currentDate.year : 2026,
                                  onSwapRequested: (d, p) => showTwoWaySwapDialog(context, d, p),
                                ),
                              ),
                            ).then((_) => _initData());
                          },
                          child: Ink(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isCurrentWeek ? Colors.deepOrange.shade300 : Colors.grey.shade200,
                                width: isCurrentWeek ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isCurrentWeek ? Colors.deepOrange : m.themeColor.withOpacity(0.15),
                                  foregroundColor: isCurrentWeek ? Colors.white : m.themeColor,
                                  radius: 20,
                                  child: Text("${idx + 1}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            m.name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15,
                                              color: isCurrentWeek ? Colors.deepOrange.shade900 : Colors.black87,
                                            ),
                                          ),
                                          if (isSwapped) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(4)),
                                              child: const Text("ĐÃ ĐỔI CA", style: TextStyle(color: Colors.brown, fontSize: 10, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isHoliday
                                            ? "$timeline - $dateStr (Miễn trực: $holidayName)"
                                            : (isSwapped ? "$timeline - $dateStr (Đổi thay cho $originalName)" : "$timeline - $dateStr"),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isHoliday ? Colors.red : (isCurrentWeek ? Colors.deepOrange : Colors.grey.shade700),
                                          fontWeight: (isCurrentWeek || isHoliday) ? FontWeight.bold : FontWeight.normal,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (!isHoliday)
                                  IconButton(
                                    icon: const Icon(Icons.swap_horiz, size: 22, color: Color(0xFF00796B)),
                                    tooltip: "Đổi ca",
                                    onPressed: () => showTwoWaySwapDialog(context, targetSat, m.name),
                                  )
                                else
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

// Màn hình chi tiết tra cứu lịch đến 2050 (Kèm nút đổi ca từng ngày)
class YearRangeMemberDetailScreen extends StatefulWidget {
  final Member member;
  final List<Member> members;
  final int initialYear;
  final Function(DateTime date, String person) onSwapRequested;

  const YearRangeMemberDetailScreen({
    super.key,
    required this.member,
    required this.members,
    required this.initialYear,
    required this.onSwapRequested,
  });

  @override
  State<YearRangeMemberDetailScreen> createState() => _YearRangeMemberDetailScreenState();
}

class _YearRangeMemberDetailScreenState extends State<YearRangeMemberDetailScreen> {
  late int _selectedYear;
  final List<int> _years = List.generate(25, (index) => 2026 + index);

  @override
  void initState() {
    super.initState();
    _selectedYear = widget.initialYear;
  }

  List<DutyShift> _getShiftsForYear(int year) {
    List<DutyShift> shifts = [];
    DateTime date = DateTime(year, 1, 1);
    int daysUntilFirstSat = (6 - date.weekday + 7) % 7;
    DateTime saturday = date.add(Duration(days: daysUntilFirstSat));

    while (saturday.year == year) {
      int diffDays = saturday.difference(_MainDutyScreenState.baseSaturday).inDays;
      int diffWeeks = (diffDays / 7).round();
      int personIndex = (diffWeeks % widget.members.length + widget.members.length) % widget.members.length;

      String defaultPerson = widget.members[personIndex].name;
      String assignedName = defaultPerson;
      bool isSwapped = false;

      String dateKey = "${saturday.year}-${saturday.month.toString().padLeft(2, '0')}-${saturday.day.toString().padLeft(2, '0')}";
      if (_MainDutyScreenState.swapShifts.containsKey(dateKey)) {
        assignedName = _MainDutyScreenState.swapShifts[dateKey]!["nguoiDoi"]!;
        isSwapped = true;
      }

      if (assignedName == widget.member.name) {
        String? holiday = _MainDutyScreenState.checkHoliday(saturday);
        shifts.add(DutyShift(
          date: saturday,
          assignedPerson: assignedName,
          isHoliday: holiday != null,
          holidayName: holiday,
          isSwapped: isSwapped,
          originalPerson: defaultPerson,
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00796B), Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.teal.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.calendar_month, color: Colors.amber, size: 22),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("ĐANG XEM LỊCH", style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                          Text("Chọn năm tra cứu:", style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00796B), size: 28),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00796B)),
                        dropdownColor: Colors.white,
                        items: _years.map((int year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text("NĂM $year", style: TextStyle(fontWeight: year == _selectedYear ? FontWeight.w900 : FontWeight.bold)),
                          );
                        }).toList(),
                        onChanged: (int? newYear) {
                          if (newYear != null) setState(() => _selectedYear = newYear);
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
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
                      _buildStatBox("Miễn trực (Lễ/Tết)", "$holidayCount ca", Colors.deepOrange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
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
                          Flexible(
                            child: Text(
                              "MIỄN TRỰC (${shift.holidayName})",
                              textAlign: TextAlign.right,
                              style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
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
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateStr, style: const TextStyle(fontWeight: FontWeight.w600)),
                                if (shift.isSwapped)
                                  Text("Đã đổi thay cho ${shift.originalPerson}", style: const TextStyle(color: Colors.brown, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.swap_horiz, size: 14),
                          label: const Text("Đổi ca", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.teal.shade50,
                            foregroundColor: const Color(0xFF00796B),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onSwapRequested(shift.date, widget.member.name);
                          },
                        )
                      ],
                    ),
                  );
                },
              ),
            const SizedBox(height: 25),
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
