import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const NoiDayApp());
}

class Member {
  final String username;
  final String name;
  final String shortName;
  final Color themeColor;

  const Member({
    required this.username,
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
  final String? swapStatus;

  DutyShift({
    required this.date,
    required this.assignedPerson,
    this.isHoliday = false,
    this.holidayName,
    this.isSwapped = false,
    this.originalPerson,
    this.swapStatus,
  });
}

// ================= THUẬT TOÁN ÂM LỊCH VIỆT NAM =================
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
    c1 += 0.0104 * sin((2 * f - mpr) * dr) + 0.0005 * sin((2 * mpr + m) * dr);
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF00695C),
          primary: const Color(0xFF00695C),
          surface: const Color(0xFFF6F8FA),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F8FA),
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
    Member(username: "sam.nt", name: "NGUYỄN THỊ SÂM", shortName: "SÂM", themeColor: Color(0xFFE65100)),
    Member(username: "minh.nn", name: "NGUYỄN NGỌC HOÀNG MINH", shortName: "MINH", themeColor: Color(0xFF1565C0)),
    Member(username: "trinh.lt", name: "LÂM TỐ TRINH", shortName: "TRINH", themeColor: Color(0xFF6A1B9A)),
    Member(username: "hung.ch", name: "CAO HOÀNG HƯNG", shortName: "HƯNG", themeColor: Color(0xFF00695C)),
  ];

  static final DateTime baseSaturday = DateTime(2026, 10, 17);
  static const String sheetId = "12LwsnfhdvnT9WqZAiXy6lrA0GrEFpdA1IUXp5YfHf0c";
  static const String scriptApiUrl =
      "https://script.google.com/macros/s/AKfycbwC4lFvh_9Wd_P5KA5yih3-4uqqB3Wm9Yeila5GSuImfryloKEO4FYfQsICVx937vTM/exec";

  static Map<String, String> userPasswords = {
    "admin": "1111",
    "sam.nt": "1111",
    "minh.nn": "1111",
    "trinh.lt": "1111",
    "hung.ch": "1111",
  };

  static Map<String, String> customHolidays = {};
  static Map<String, Map<String, dynamic>> swapShifts = {};

  DateTime _currentDate = DateTime.now();
  bool _isLoading = false;
  String _filterMember = "ALL";

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
      _fetchRemotePasswordsFast(),
    ]);
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchRemotePasswordsFast() async {
    final String url = "https://docs.google.com/spreadsheets/d/$sheetId/gviz/tq?tqx=out:csv&sheet=User";
    try {
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final lines = const LineSplitter().convert(res.body);
        for (int i = 1; i < lines.length; i++) {
          final row = lines[i].replaceAll('"', '').split(',');
          if (row.length >= 2) {
            String u = row[0].trim().toLowerCase();
            String p = row[1].replaceAll("'", "").trim();
            if (u.isNotEmpty && p.isNotEmpty) {
              userPasswords[u] = p;
            }
          }
        }
      }
    } catch (_) {}
  }

  static void updateRemotePasswordAsync(String username, String newPassword) {
    userPasswords[username.toLowerCase()] = newPassword;
    final uri = Uri.parse(scriptApiUrl).replace(queryParameters: {
      "action": "change_pass",
      "username": username.toLowerCase(),
      "new_pass": newPassword,
    });
    http.get(uri).catchError((_) {});
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

  static String _matchMemberName(String input) {
    String clean = input.trim().toUpperCase();
    for (var m in baseMembers) {
      if (clean == m.name.toUpperCase() || clean == m.shortName.toUpperCase() || clean == m.username.toUpperCase()) {
        return m.name;
      }
    }
    return input.trim();
  }

  static String? _getUsernameOfPerson(String personName) {
    String clean = personName.trim().toUpperCase();
    for (var m in baseMembers) {
      if (clean == m.name.toUpperCase() || clean == m.shortName.toUpperCase() || clean == m.username.toUpperCase()) {
        return m.username;
      }
    }
    return null;
  }

  Future<void> _fetchSwappedShifts() async {
    try {
      final res = await http.get(Uri.parse(scriptApiUrl)).timeout(const Duration(seconds: 10));
      if (res.statusCode == 200 && res.body.isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded["status"] == "success" && decoded["data"] != null) {
          Map<String, Map<String, dynamic>> parsedSwap = {};
          for (var item in decoded["data"]) {
            String d1 = _normalizeDate(item["ngay1"]?.toString() ?? "");
            String d2 = _normalizeDate(item["ngay2"]?.toString() ?? "");
            String p1 = _matchMemberName(item["nguoi1"]?.toString() ?? "");
            String p2 = _matchMemberName(item["nguoi2"]?.toString() ?? "");
            String status = item["trangThai"]?.toString().trim().toUpperCase() ?? "CONFIRMED";

            if (d1.isNotEmpty && p2.isNotEmpty) {
              parsedSwap[d1] = {
                "nguoiGoc": p1,
                "nguoiDoi": p2,
                "trangThai": status,
                "ngayDoi": d2,
                "laNguoiYeuCau": true,
              };
            }
            if (d2.isNotEmpty && p1.isNotEmpty) {
              parsedSwap[d2] = {
                "nguoiGoc": p2,
                "nguoiDoi": p1,
                "trangThai": status,
                "ngayDoi": d1,
                "laNguoiYeuCau": false, // Người được đề nghị đổi (người cần bấm xác nhận)
              };
            }
          }

          if (mounted) {
            setState(() {
              swapShifts = parsedSwap;
            });
          }
        }
      }
    } catch (e) {
      debugPrint("Lỗi tải ca đổi: $e");
    }
  }

  static String _normalizeDate(String input) {
    try {
      String clean = input.replaceAll("'", "").replaceAll('"', '').trim();
      if (clean.isEmpty) return "";
      if (clean.contains('T')) clean = clean.split('T')[0].trim();

      final matches = RegExp(r'\d+').allMatches(clean).map((m) => m.group(0)!).toList();
      if (matches.length >= 3) {
        if (matches[0].length == 4) {
          String y = matches[0];
          String m = matches[1].padLeft(2, '0');
          String d = matches[2].padLeft(2, '0');
          return "$y-$m-$d";
        } else if (matches[2].length == 4) {
          String d = matches[0].padLeft(2, '0');
          String m = matches[1].padLeft(2, '0');
          String y = matches[2];
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
    String? swapStatus;

    String dateKey = "${thisSaturday.year}-${thisSaturday.month.toString().padLeft(2, '0')}-${thisSaturday.day.toString().padLeft(2, '0')}";
    if (swapShifts.containsKey(dateKey)) {
      swapStatus = swapShifts[dateKey]!["trangThai"];
      if (swapStatus == "CONFIRMED") {
        assignedPerson = swapShifts[dateKey]!["nguoiDoi"]!;
      }
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
      swapStatus: swapStatus,
    );
  }

  List<Map<String, dynamic>> _getUpcomingShiftsList(DateTime now, {int totalWeeks = 104}) {
    DateTime thisSaturday = _getThisSaturday(now);
    int diffWeeks = _calculateCurrentWeekDiff(now);
    int startIndex = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;

    List<Map<String, dynamic>> shifts = [];
    for (int i = 0; i < totalWeeks; i++) {
      final baseMember = baseMembers[(startIndex + i) % baseMembers.length];
      final targetSat = thisSaturday.add(Duration(days: i * 7));
      final holiday = checkHoliday(targetSat);

      String dateKey = "${targetSat.year}-${targetSat.month.toString().padLeft(2, '0')}-${targetSat.day.toString().padLeft(2, '0')}";
      Member currentMember = baseMember;
      bool isSwapped = false;
      String? originalName;
      String? swapStatus;
      String? targetSwapPerson;
      bool isRequester = false;

      if (swapShifts.containsKey(dateKey)) {
        swapStatus = swapShifts[dateKey]!["trangThai"];
        targetSwapPerson = swapShifts[dateKey]!["nguoiDoi"];
        isRequester = swapShifts[dateKey]!["laNguoiYeuCau"] == true;

        if (swapStatus == "CONFIRMED") {
          currentMember = baseMembers.firstWhere(
            (m) => m.name.toUpperCase() == targetSwapPerson!.toUpperCase() || m.shortName.toUpperCase() == targetSwapPerson.toUpperCase(),
            orElse: () => baseMember,
          );
          originalName = baseMember.name;
        } else {
          originalName = targetSwapPerson;
        }
        isSwapped = true;
      }

      String timelineText = (i == 0) ? "Tuần này" : (i == 1 ? "Tuần tới" : "$i tuần nữa");
      final dateStr = "${targetSat.day.toString().padLeft(2, '0')}/${targetSat.month.toString().padLeft(2, '0')}/${targetSat.year}";
      final monthGroup = "Tháng ${targetSat.month}/${targetSat.year}";

      shifts.add({
        "index": i + 1,
        "member": currentMember,
        "baseMember": baseMember,
        "date": targetSat,
        "dateKey": dateKey,
        "dateStr": dateStr,
        "monthGroup": monthGroup,
        "timelineText": timelineText,
        "isHoliday": holiday != null,
        "holidayName": holiday,
        "isSwapped": isSwapped,
        "originalName": originalName,
        "swapStatus": swapStatus,
        "targetSwapPerson": targetSwapPerson,
        "isRequester": isRequester,
      });
    }
    return shifts;
  }

  static List<DateTime> getUpcomingSaturdaysForMember(String memberName, DateTime fromDate) {
    List<DateTime> list = [];
    DateTime sat = fromDate;
    if (sat.weekday != DateTime.saturday) {
      sat = sat.add(Duration(days: (6 - sat.weekday + 7) % 7));
    }
    for (int i = 0; i < 60; i++) {
      int diffDays = sat.difference(baseSaturday).inDays;
      int diffWeeks = (diffDays / 7).round();
      int personIdx = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;
      String person = baseMembers[personIdx].name;

      String dateKey = "${sat.year}-${sat.month.toString().padLeft(2, '0')}-${sat.day.toString().padLeft(2, '0')}";
      if (swapShifts.containsKey(dateKey) && swapShifts[dateKey]!["trangThai"] == "CONFIRMED") {
        person = swapShifts[dateKey]!["nguoiDoi"]!;
      }

      if (_matchMemberName(person) == _matchMemberName(memberName)) {
        list.add(sat);
      }
      sat = sat.add(const Duration(days: 7));
      if (list.length >= 8) break;
    }
    return list;
  }

  // ================= TỰ ĐỔI MẬT MÃ =================
  void _showChangePasswordDialog() {
    String selectedUsername = baseMembers.first.username;
    final oldPassController = TextEditingController();
    final newPassController = TextEditingController();

    final allAccounts = [
      ...baseMembers.map((m) => {"username": m.username, "label": "${m.shortName} (${m.name})"}),
      {"username": "admin", "label": "ADMIN (Quản trị viên)"},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.key, color: Color(0xFF00695C), size: 24),
                SizedBox(width: 8),
                Text("ĐỔI MẬT MÃ CÁ NHÂN", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF00695C))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("1. Chọn tài khoản của bạn:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedUsername,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    items: allAccounts.map((acc) {
                      return DropdownMenuItem<String>(
                        value: acc["username"],
                        child: Text(acc["label"]!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setDialogState(() => selectedUsername = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text("2. Mật mã hiện tại:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: oldPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "••••",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("3. Mật mã mới:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: newPassController,
                    obscureText: true,
                    decoration: InputDecoration(
                      hintText: "Nhập mật mã mới...",
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY", style: TextStyle(color: Colors.grey))),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white),
                onPressed: () {
                  final oldPass = oldPassController.text.trim();
                  final newPass = newPassController.text.trim();
                  final currentActual = userPasswords[selectedUsername.toLowerCase()] ?? "1111";

                  if (oldPass != currentActual) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mật mã hiện tại không đúng!"), backgroundColor: Colors.red));
                    return;
                  }
                  if (newPass.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mật mã mới không được để trống!"), backgroundColor: Colors.red));
                    return;
                  }

                  Navigator.pop(ctx);
                  updateRemotePasswordAsync(selectedUsername, newPass);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã đổi mật mã thành công!"), backgroundColor: Colors.teal));
                },
                child: const Text("LƯU MẬT MÃ", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  // ================= 1. GỬI YÊU CẦU ĐỔI CA (PENDING) =================
  void showTwoWaySwapDialog(BuildContext context, DateTime sourceDate, String sourcePerson) {
    final dateStr = "${sourceDate.day.toString().padLeft(2, '0')}/${sourceDate.month.toString().padLeft(2, '0')}/${sourceDate.year}";
    final cleanSourcePerson = _matchMemberName(sourcePerson);
    final otherMembers = baseMembers.where((m) => m.name != cleanSourcePerson).toList();

    Member targetMember = otherMembers.first;
    List<DateTime> targetDates = getUpcomingSaturdaysForMember(targetMember.name, _currentDate);
    DateTime? selectedTargetDate = targetDates.isNotEmpty ? targetDates.first : null;
    final reasonController = TextEditingController();
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.swap_horizontal_circle_outlined, color: Color(0xFF00695C), size: 26),
                SizedBox(width: 8),
                Text("ĐỀ NGHỊ ĐỔI CA TRỰC", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF00695C))),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: const Color(0xFFE0F2F1), borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ca của bạn: $cleanSourcePerson", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF004D40))),
                        const SizedBox(height: 2),
                        Text("Thứ Bảy, $dateStr", style: const TextStyle(fontSize: 12, color: Colors.black87)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text("1. Người muốn đổi cùng:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
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
                  Text("2. Chọn ca của ${targetMember.shortName} để đổi:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
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
                  const Text("3. Lý do đổi (tùy chọn):", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueGrey)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: reasonController,
                    decoration: InputDecoration(
                      hintText: "Ví dụ: Đi công tác, bận việc cá nhân...",
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text("4. Mật mã xác thực của $cleanSourcePerson:", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.redAccent)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      hintText: "Nhập mật mã xác nhận...",
                      hintStyle: const TextStyle(fontSize: 12, color: Colors.grey),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("HỦY", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold))),
              ElevatedButton.icon(
                icon: const Icon(Icons.send, size: 16),
                label: const Text("GỬI ĐỀ NGHỊ ĐỔI", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white),
                onPressed: () async {
                  if (selectedTargetDate == null) return;

                  final inputPass = passwordController.text.trim();
                  final userKey = _getUsernameOfPerson(cleanSourcePerson);
                  final correctUserPass = userPasswords[userKey ?? ""] ?? "1111";
                  final adminPass = userPasswords["admin"] ?? "1111";

                  if (inputPass.isEmpty || (inputPass != correctUserPass && inputPass != adminPass)) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Mật mã không đúng!"), backgroundColor: Colors.red));
                    return;
                  }

                  Navigator.pop(ctx);
                  await sendSwapRequest(sourceDate, cleanSourcePerson, selectedTargetDate!, targetMember.name, reasonController.text);
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> sendSwapRequest(DateTime d1, String p1, DateTime d2, String p2, String note) async {
    setState(() => _isLoading = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đang gửi đề nghị đổi ca lên Google Sheets..."), duration: Duration(seconds: 2)));

    final sD1 = "${d1.year}-${d1.month.toString().padLeft(2, '0')}-${d1.day.toString().padLeft(2, '0')}";
    final sD2 = "${d2.year}-${d2.month.toString().padLeft(2, '0')}-${d2.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(scriptApiUrl).replace(queryParameters: {
      "action": "swap_request",
      "ngay1": sD1,
      "nguoi1": p1,
      "ngay2": sD2,
      "nguoi2": p2,
      "ghiChu": note.isEmpty ? "Đổi ca qua App" : note,
    });

    try {
      // Dùng http.get trực tiếp tương thích 100% Flutter Web & Mobile
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      debugPrint("swap_request Response: ${response.statusCode} - ${response.body}");

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Đã gửi đề nghị! Chờ $p2 vào xác nhận."), backgroundColor: Colors.teal));
      await Future.delayed(const Duration(seconds: 1));
      await _fetchSwappedShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi gửi dữ liệu: $e"), backgroundColor: Colors.red));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ================= 2. XÁC NHẬN ĐỒNG Ý ĐỔI CA (CONFIRMED) =================
  void _confirmAcceptSwap(DateTime date, String requester, String targetPerson) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("XÁC NHẬN ĐỒNG Ý ĐỔI CA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF00695C))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("$requester đã gửi đề nghị hoán đổi ca trực với bạn ($targetPerson)."),
            const SizedBox(height: 12),
            Text("Nhập mật mã của $targetPerson để đồng ý hoán đổi:", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                hintText: "••••",
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("ĐÓNG", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00695C), foregroundColor: Colors.white),
            onPressed: () async {
              final inputPass = passwordController.text.trim();
              final targetKey = _getUsernameOfPerson(targetPerson);
              final correctPass = userPasswords[targetKey ?? ""] ?? "1111";
              final adminPass = userPasswords["admin"] ?? "1111";

              if (inputPass.isEmpty || (inputPass != correctPass && inputPass != adminPass)) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Mật mã của $targetPerson không đúng!"), backgroundColor: Colors.red));
                return;
              }

              Navigator.pop(ctx);
              await sendConfirmSwap(date);
            },
            child: const Text("ĐỒNG Ý ĐỔI", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> sendConfirmSwap(DateTime d1) async {
    setState(() => _isLoading = true);
    final sD1 = "${d1.year}-${d1.month.toString().padLeft(2, '0')}-${d1.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(scriptApiUrl).replace(queryParameters: {
      "action": "swap_confirm",
      "ngay1": sD1,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      debugPrint("swap_confirm Response: ${response.statusCode} - ${response.body}");

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Hoán đổi ca thành công!"), backgroundColor: Colors.teal));
      await Future.delayed(const Duration(seconds: 1));
      await _fetchSwappedShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi xác nhận: $e"), backgroundColor: Colors.red));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  // ================= 3. HỦY CA ĐỔI =================
  void _confirmCancelSwap(DateTime date, String shiftOwner) {
    final passwordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("XÁC NHẬN HỦY ĐỔI CA", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Bạn đang hủy lượt đổi của ca ngày này (thuộc $shiftOwner)."),
            const SizedBox(height: 14),
            Text("Bắt buộc nhập đúng mật mã của $shiftOwner (hoặc admin):", style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
            const SizedBox(height: 6),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.lock_outline, size: 18),
                hintText: "••••",
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("KHÔNG", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              final inputPass = passwordController.text.trim();
              final ownerKey = _getUsernameOfPerson(shiftOwner);
              final ownerPass = userPasswords[ownerKey ?? ""] ?? "1111";
              final adminPass = userPasswords["admin"] ?? "1111";

              if (inputPass.isEmpty || (inputPass != ownerPass && inputPass != adminPass)) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Sai mật mã! Phải nhập đúng mật mã của $shiftOwner"), backgroundColor: Colors.red));
                return;
              }

              Navigator.pop(ctx);
              sendCancelSwapRequest(date);
            },
            child: const Text("HỦY ĐỔI CA", style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> sendCancelSwapRequest(DateTime d1) async {
    setState(() => _isLoading = true);
    final sD1 = "${d1.year}-${d1.month.toString().padLeft(2, '0')}-${d1.day.toString().padLeft(2, '0')}";

    final uri = Uri.parse(scriptApiUrl).replace(queryParameters: {
      "action": "cancel",
      "ngay1": sD1,
    });

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      debugPrint("cancel Response: ${response.statusCode} - ${response.body}");

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Đã hủy và khôi phục ca gốc!"), backgroundColor: Colors.teal));
      await Future.delayed(const Duration(seconds: 1));
      await _fetchSwappedShifts();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Lỗi hủy ca: $e"), backgroundColor: Colors.red));
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final currentDuty = _calculateThisWeekDuty(_currentDate);
    final allUpcoming = _getUpcomingShiftsList(_currentDate, totalWeeks: 104);

    final displayedShifts = (_filterMember == "ALL")
        ? allUpcoming
        : allUpcoming.where((item) {
            final Member m = item["member"];
            return m.shortName == _filterMember || m.name == _filterMember || m.username == _filterMember;
          }).toList();

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF00695C),
        leading: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Icon(Icons.shield_outlined, color: Colors.amberAccent, size: 24),
        ),
        title: const Text(
          "NỔI DẬY • LỊCH TRỰC",
          style: TextStyle(fontWeight: FontWeight.w900, color: Colors.white, fontSize: 17, letterSpacing: 0.5),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: "Đổi mật mã cá nhân",
            icon: const Icon(Icons.key, color: Colors.amberAccent, size: 22),
            onPressed: _showChangePasswordDialog,
          ),
          IconButton(
            tooltip: "Làm mới dữ liệu",
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
            // BANNER TRỰC TUẦN NÀY
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(
                  colors: currentDuty.isHoliday
                      ? [const Color(0xFFC62828), const Color(0xFF8E0000)]
                      : [const Color(0xFF00695C), const Color(0xFF004D40)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (currentDuty.isHoliday ? Colors.red : Colors.teal).withOpacity(0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      currentDuty.isHoliday ? Icons.beach_access : Icons.event_available,
                      size: 130,
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                children: [
                                  CircleAvatar(radius: 3, backgroundColor: Colors.amberAccent),
                                  SizedBox(width: 6),
                                  Text("TRỰC THỨ BẢY TUẦN NÀY", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: currentDuty.isHoliday ? Colors.white : Colors.amberAccent,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                "${currentDuty.date.day.toString().padLeft(2, '0')}/${currentDuty.date.month.toString().padLeft(2, '0')}/${currentDuty.date.year}",
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                  color: currentDuty.isHoliday ? const Color(0xFFC62828) : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          currentDuty.isHoliday ? "${currentDuty.assignedPerson} (MIỄN TRỰC)" : currentDuty.assignedPerson,
                          style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900, letterSpacing: 0.2),
                        ),
                        const SizedBox(height: 4),
                        if (currentDuty.isSwapped)
                          Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: currentDuty.swapStatus == "PENDING" ? Colors.orange.shade100 : Colors.amberAccent.withOpacity(0.25),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              currentDuty.swapStatus == "PENDING"
                                  ? "⏳ Đang chờ xác nhận đổi ca..."
                                  : "🔄 Đã đổi: trực thay cho ${currentDuty.originalPerson}",
                              style: TextStyle(
                                color: currentDuty.swapStatus == "PENDING" ? Colors.orange.shade900 : Colors.amberAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        Text(
                          currentDuty.isHoliday ? "Nghỉ lễ: ${currentDuty.holidayName} (Được nghỉ)" : "Đến lượt cày cuốc, chuẩn bị tinh thần!",
                          style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 13),
                        ),
                        if (!currentDuty.isHoliday) ...[
                          const SizedBox(height: 14),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (currentDuty.isSwapped)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 8.0),
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.undo, size: 15),
                                      label: const Text("Hủy đổi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red.shade100,
                                        foregroundColor: Colors.red.shade900,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                      ),
                                      onPressed: () => _confirmCancelSwap(currentDuty.date, currentDuty.assignedPerson),
                                    ),
                                  ),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: const Text("Đổi ca", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF00695C),
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                  ),
                                  onPressed: () => showTwoWaySwapDialog(context, currentDuty.date, currentDuty.assignedPerson),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // BỘ LỌC THÀNH VIÊN
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterChip("Tất cả", "ALL"),
                  const SizedBox(width: 8),
                  ...baseMembers.map((m) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _buildFilterChip(m.shortName, m.shortName, color: m.themeColor),
                      )),
                ],
              ),
            ),

            // DANH SÁCH 2 NĂM GOM THEO THÁNG
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _filterMember == "ALL" ? "LỊCH TRỰC 2 NĂM TỚI (104 TUẦN)" : "LỊCH CỦA ${_filterMember.toUpperCase()}",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.blueGrey, letterSpacing: 0.5),
                      ),
                      Text(
                        "${displayedShifts.length} ngày",
                        style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayedShifts.length,
                    itemBuilder: (context, idx) {
                      final item = displayedShifts[idx];
                      final Member m = item["member"];
                      final String timeline = item["timelineText"];
                      final String dateStr = item["dateStr"];
                      final DateTime targetSat = item["date"];
                      final bool isHoliday = item["isHoliday"];
                      final String? holidayName = item["holidayName"];
                      final bool isSwapped = item["isSwapped"];
                      final String? originalName = item["originalName"];
                      final String monthGroup = item["monthGroup"];
                      final String? swapStatus = item["swapStatus"];
                      final bool isRequester = item["isRequester"] ?? false;

                      bool showMonthHeader = false;
                      if (idx == 0 || displayedShifts[idx - 1]["monthGroup"] != monthGroup) {
                        showMonthHeader = true;
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showMonthHeader)
                            Padding(
                              padding: const EdgeInsets.only(top: 14, bottom: 8),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.blueGrey.shade100,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      monthGroup.toUpperCase(),
                                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.blueGrey.shade800),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(child: Divider(color: Colors.grey.shade300, thickness: 1)),
                                ],
                              ),
                            ),
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: swapStatus == "PENDING" ? Colors.orange.shade300 : Colors.grey.shade200,
                                width: swapStatus == "PENDING" ? 1.5 : 1,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => YearRangeMemberDetailScreen(
                                        member: m,
                                        members: baseMembers,
                                        initialYear: _currentDate.year >= 2026 && _currentDate.year <= 2050 ? _currentDate.year : 2026,
                                        onSwapRequested: (d, p) => showTwoWaySwapDialog(context, d, p),
                                      ),
                                    ),
                                  ).then((_) => _initData());
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: IntrinsicHeight(
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 5,
                                          color: isHoliday ? Colors.red : (swapStatus == "PENDING" ? Colors.orange : m.themeColor),
                                        ),
                                        const SizedBox(width: 12),
                                        CircleAvatar(
                                          backgroundColor: m.themeColor.withOpacity(0.12),
                                          foregroundColor: m.themeColor,
                                          radius: 18,
                                          child: Text(
                                            m.shortName[0],
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Text(
                                                      m.name,
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87),
                                                    ),
                                                    if (isSwapped) ...[
                                                      const SizedBox(width: 6),
                                                      Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: swapStatus == "PENDING" ? Colors.orange.shade100 : Colors.amber.shade100,
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          swapStatus == "PENDING" ? "CHỜ XÁC NHẬN" : "ĐÃ ĐỔI",
                                                          style: TextStyle(
                                                            color: swapStatus == "PENDING" ? Colors.orange.shade900 : Colors.brown,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4)),
                                                      child: Text(
                                                        timeline,
                                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.blueGrey.shade700),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      dateStr,
                                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                                                    ),
                                                  ],
                                                ),
                                                if (isHoliday)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: Text("Miễn trực: $holidayName", style: const TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                                  )
                                                else if (isSwapped && swapStatus == "PENDING")
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: Text(
                                                      isRequester
                                                          ? "Đã gửi đề nghị đổi cho $originalName"
                                                          : "$originalName đề nghị đổi ca với bạn",
                                                      style: TextStyle(color: Colors.orange.shade900, fontSize: 11, fontWeight: FontWeight.bold),
                                                    ),
                                                  )
                                                else if (isSwapped)
                                                  Padding(
                                                    padding: const EdgeInsets.only(top: 3),
                                                    child: Text("Đổi thay cho $originalName", style: const TextStyle(color: Colors.brown, fontSize: 11, fontWeight: FontWeight.w600)),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        // NÚT ĐỒNG Ý: Hiển thị ngay cho người được đề nghị đổi khi ở trạng thái PENDING
                                        if (isSwapped && swapStatus == "PENDING" && !isRequester)
                                          Padding(
                                            padding: const EdgeInsets.only(right: 6.0),
                                            child: ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.orange.shade700,
                                                foregroundColor: Colors.white,
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                elevation: 0,
                                              ),
                                              onPressed: () => _confirmAcceptSwap(targetSat, originalName ?? "", m.name),
                                              child: const Text("Đồng ý", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ),
                                        // Nút Hủy đổi ca
                                        if (isSwapped)
                                          IconButton(
                                            icon: const Icon(Icons.undo, size: 20, color: Colors.redAccent),
                                            tooltip: "Hủy ca này (nhập pass của ${m.shortName})",
                                            onPressed: () => _confirmCancelSwap(targetSat, m.name),
                                          ),
                                        // Nút Đổi ca
                                        if (!isHoliday && !isSwapped)
                                          IconButton(
                                            icon: const Icon(Icons.swap_horiz, size: 20, color: Color(0xFF00695C)),
                                            tooltip: "Đổi ca này",
                                            onPressed: () => showTwoWaySwapDialog(context, targetSat, m.name),
                                          )
                                        else if (isHoliday)
                                          const Padding(
                                            padding: EdgeInsets.only(right: 14),
                                            child: Icon(Icons.beach_access, size: 18, color: Colors.redAccent),
                                          ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, {Color? color}) {
    final bool isSelected = _filterMember == value;
    final chipColor = color ?? const Color(0xFF00695C);

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _filterMember = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? chipColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? chipColor : Colors.grey.shade300, width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: chipColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 2))] : [],
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

// ================= MÀN HÌNH CHI TIẾT THEO NĂM =================
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
      String? swapStatus;

      String dateKey = "${saturday.year}-${saturday.month.toString().padLeft(2, '0')}-${saturday.day.toString().padLeft(2, '0')}";
      if (_MainDutyScreenState.swapShifts.containsKey(dateKey)) {
        swapStatus = _MainDutyScreenState.swapShifts[dateKey]!["trangThai"];
        if (swapStatus == "CONFIRMED") {
          assignedName = _MainDutyScreenState.swapShifts[dateKey]!["nguoiDoi"]!;
        }
        isSwapped = true;
      }

      if (_MainDutyScreenState._matchMemberName(assignedName) == _MainDutyScreenState._matchMemberName(widget.member.name)) {
        String? holiday = _MainDutyScreenState.checkHoliday(saturday);
        shifts.add(DutyShift(
          date: saturday,
          assignedPerson: assignedName,
          isHoliday: holiday != null,
          holidayName: holiday,
          isSwapped: isSwapped,
          originalPerson: defaultPerson,
          swapStatus: swapStatus,
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
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FA),
      appBar: AppBar(
        title: Text(widget.member.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF00695C),
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF00695C), Color(0xFF004D40)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.calendar_month, color: Colors.amberAccent, size: 22)),
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
                        icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF00695C), size: 28),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF00695C)),
                        dropdownColor: Colors.white,
                        items: _years.map((int year) => DropdownMenuItem<int>(value: year, child: Text("NĂM $year", style: TextStyle(fontWeight: year == _selectedYear ? FontWeight.w900 : FontWeight.bold)))).toList(),
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
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
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
              child: Text("CÁC THỨ BẢY TRỰC NĂM $_selectedYear (${memberShiftsInYear.length} LƯỢT)", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
            ),
            const SizedBox(height: 10),
            if (memberShiftsInYear.isEmpty)
              const Padding(padding: EdgeInsets.all(20.0), child: Text("Không có ca trực nào trong năm này.", style: TextStyle(color: Colors.grey)))
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: memberShiftsInYear.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, idx) {
                  final shift = memberShiftsInYear[idx];
                  final dateStr = "${shift.date.day.toString().padLeft(2, '0')}/${shift.date.month.toString().padLeft(2, '0')}/${shift.date.year}";
                  final isPast = shift.date.isBefore(todayStart);

                  if (shift.isHoliday) {
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.red.shade200)),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [const Icon(Icons.beach_access, color: Colors.red, size: 18), const SizedBox(width: 10), Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red))]),
                          Flexible(child: Text("MIỄN TRỰC (${shift.holidayName})", textAlign: TextAlign.right, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11))),
                        ],
                      ),
                    );
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: isPast ? Colors.grey.shade100 : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(isPast ? Icons.check_circle_outline : Icons.event_available, color: isPast ? Colors.grey : Colors.teal, size: 18),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateStr, style: TextStyle(fontWeight: FontWeight.w600, color: isPast ? Colors.grey.shade600 : Colors.black87)),
                                if (shift.isSwapped)
                                  Text(
                                    shift.swapStatus == "PENDING" ? "Chờ xác nhận đổi" : "Đã đổi thay cho ${shift.originalPerson}",
                                    style: TextStyle(
                                      color: shift.swapStatus == "PENDING" ? Colors.orange.shade800 : Colors.brown,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                        if (!isPast && !shift.isSwapped)
                          ElevatedButton.icon(
                            icon: const Icon(Icons.swap_horiz, size: 14),
                            label: const Text("Đổi ca", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade50, foregroundColor: const Color(0xFF00695C), elevation: 0, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4)),
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onSwapRequested(shift.date, widget.member.name);
                            },
                          )
                        else if (isPast)
                          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4)), child: const Text("ĐÃ QUA", style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)))
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
