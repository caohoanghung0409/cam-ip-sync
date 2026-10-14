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

// ================= THUẬT TOÁN ÂM LỊCH VIỆT NAM (HỒ NGỌC ĐỨC) =================
class LunarDate {
  final int day;
  final int month;
  final int year;
  final bool isLeap;

  LunarDate(this.day, this.month, this.year, [this.isLeap = false]);

  static const double pi = 3.14159265358979323846;

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
    double dr = pi / 180;
    double jde = 2415020.75933 + 29.53058868 * k + 0.0001178 * t2 - 0.000000155 * t3;
    jde += 0.00033 * (166.56 + 132.87 * t - 0.009173 * t2) * dr;
    double m = 359.2242 + 29.10535608 * k - 0.0000333 * t2 - 0.00000347 * t3;
    double mpr = 306.0253 + 385.81691806 * k + 0.0107306 * t2 + 0.00001236 * t3;
    double f = 21.2964 + 390.67050646 * k - 0.0016528 * t2 - 0.00000239 * t3;
    double c1 = (0.1734 - 0.000393 * t) * (m * dr).sin() + 0.0021 * (2 * m * dr).sin();
    c1 -= 0.4068 * (mpr * dr).sin() + 0.0161 * (2 * mpr * dr).sin();
    c1 -= 0.0004 * (3 * mpr * dr).sin();
    c1 += 0.0104 * (2 * f * dr).sin() - 0.0051 * ((m + mpr) * dr).sin();
    c1 -= 0.0074 * ((m - mpr) * dr).sin() + 0.0004 * ((2 * f + m) * dr).sin();
    c1 -= 0.0004 * ((2 * f - m) * dr).sin() - 0.0006 * ((2 * f + mpr) * dr).sin();
    c1 += 0.0010 * ((2 * f - mpr) * dr).sin() + 0.0005 * ((2 * mpr + m) * dr).sin();
    return jde + c1;
  }

  static double _sunLongitude(double jdn) {
    double t = (jdn - 2451545.0) / 36525;
    double dr = pi / 180;
    double l0 = 280.46645 + 36000.76983 * t + 0.0003032 * t * t;
    double m = 357.52910 + 35999.05030 * t - 0.0001559 * t * t - 0.00000048 * t * t * t;
    double c = (1.914600 - 0.004817 * t - 0.000014 * t * t) * (m * dr).sin() +
        (0.019993 - 0.000101 * t) * (2 * m * dr).sin() +
        0.000290 * (3 * m * dr).sin();
    double theta = l0 + c;
    theta = theta - 360 * (theta / 360).floor();
    return theta * dr;
  }

  static int _getSunLongitude(int dayNumber, double timeZone) {
    return (_sunLongitude(dayNumber - 0.5 - timeZone / 24) / (pi / 6)).floor();
  }

  static int _getLunarMonth11(int yy, double timeZone) {
    double off = _jdFromDate(31, 12, yy) - 2415021.076998695;
    int k = (off / 29.53058868).floor();
    double nm = _newMoon(k);
    int sunLong = _getSunLongitude((nm + 0.5 + timeZone / 24).floor(), timeZone);
    if (sunLong >= 9) {
      nm = _newMoon(k - 1);
    }
    return (nm + 0.5 + timeZone / 24).floor();
  }

  static LunarDate fromSolar(int dd, int mm, int yy, [double timeZone = 7.0]) {
    int dayNumber = _jdFromDate(dd, mm, yy);
    int k = ((dayNumber - 2415021.076998695) / 29.53058868).floor();
    int lastNm = (_newMoon(k) + 0.5 + timeZone / 24).floor();
    if (lastNm > dayNumber) {
      lastNm = (_newMoon(k - 1) + 0.5 + timeZone / 24).floor();
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

// ================= APP CHÍNH =================
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
  final List<Member> baseMembers = const [
    Member(name: "NGUYỄN THỊ SÂM", shortName: "SÂM", themeColor: Colors.deepOrange),
    Member(name: "NGUYỄN NGỌC HOÀNG MINH", shortName: "MINH", themeColor: Colors.blue),
    Member(name: "LÂM TỐ TRINH", shortName: "TRINH", themeColor: Colors.purple),
    Member(name: "CAO HOÀNG HƯNG", shortName: "HƯNG", themeColor: Colors.teal),
  ];

  static final DateTime baseSaturday = DateTime(2026, 10, 17);

  DateTime _currentDate = DateTime.now();
  bool _isLoadingTime = false;

  @override
  void initState() {
    super.initState();
    _fetchInternetTime();
  }

  Future<void> _fetchInternetTime() async {
    setState(() => _isLoadingTime = true);
    try {
      final res = await http
          .get(Uri.parse('https://worldtimeapi.org/api/timezone/Asia/Ho_Chi_Minh'))
          .timeout(const Duration(seconds: 2));

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final internetDateStr = data['datetime'];
        final parsedDate = DateTime.parse(internetDateStr);

        if (mounted) {
          setState(() {
            _currentDate = parsedDate;
            _isLoadingTime = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) {
      setState(() {
        _currentDate = DateTime.now();
        _isLoadingTime = false;
      });
    }
  }

  // TÍNH CẢ LỄ DƯƠNG LỊCH & ÂM LỊCH CHUẨN XÁC
  static String? checkHoliday(DateTime date) {
    // 1. Lễ Dương Lịch
    if (date.month == 1 && date.day == 1) return "Tết Dương Lịch";
    if (date.month == 4 && date.day == 30) return "Giải Phóng Miền Nam";
    if (date.month == 5 && date.day == 1) return "Quốc Tế Lao Động";
    if (date.month == 9 && (date.day >= 1 && date.day <= 3)) return "Quốc Khánh 2/9";

    // 2. Lễ Âm Lịch (Quy đổi thiên văn Việt Nam)
    LunarDate lunar = LunarDate.fromSolar(date.day, date.month, date.year);

    // Tết Nguyên Đán (từ 29, 30 Tết đến hết Mùng 5 Tết)
    if (lunar.month == 12 && (lunar.day == 29 || lunar.day == 30)) {
      return "Nghỉ Tết Nguyên Đán (Tất Niên)";
    }
    if (lunar.month == 1 && (lunar.day >= 1 && lunar.day <= 5)) {
      return "Tết Nguyên Đán (Mùng ${lunar.day})";
    }

    // Giỗ Tổ Hùng Vương (10/3 Âm lịch)
    if (lunar.month == 3 && lunar.day == 10) {
      return "Giỗ Tổ Hùng Vương (10/3 ÂL)";
    }

    return null;
  }

  int _calculateCurrentWeekDiff(DateTime now) {
    DateTime today = DateTime(now.year, now.month, now.day);
    int daysUntilSaturday = 6 - today.weekday;
    DateTime thisSaturday = today.add(Duration(days: daysUntilSaturday));

    int diffDays = thisSaturday.difference(baseSaturday).inDays;
    return (diffDays / 7).round();
  }

  DutyShift _calculateThisWeekDuty(DateTime now) {
    DateTime today = DateTime(now.year, now.month, now.day);
    int daysUntilSaturday = 6 - today.weekday;
    DateTime thisSaturday = today.add(Duration(days: daysUntilSaturday));

    int diffWeeks = _calculateCurrentWeekDiff(now);
    int personIndex = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;

    String person = baseMembers[personIndex].name;
    String? holiday = checkHoliday(thisSaturday);

    return DutyShift(
      date: thisSaturday,
      assignedPerson: person,
      isHoliday: holiday != null,
      holidayName: holiday,
    );
  }

  List<Member> _getRotatedMembers(DateTime now) {
    int diffWeeks = _calculateCurrentWeekDiff(now);
    int startIndex = (diffWeeks % baseMembers.length + baseMembers.length) % baseMembers.length;

    List<Member> rotated = [];
    for (int i = 0; i < baseMembers.length; i++) {
      rotated.add(baseMembers[(startIndex + i) % baseMembers.length]);
    }
    return rotated;
  }

  @override
  Widget build(BuildContext context) {
    final currentDuty = _calculateThisWeekDuty(_currentDate);
    final rotatedMembers = _getRotatedMembers(_currentDate);

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
            tooltip: "Làm mới",
            icon: _isLoadingTime
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.refresh, color: Colors.white),
            onPressed: _fetchInternetTime,
          )
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Banner ca trực tuần này
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
                  Text(
                    currentDuty.isHoliday
                        ? "Trùng dịp lễ: ${currentDuty.holidayName} (Được nghỉ)"
                        : "Đến lượt cày cuốc, chuẩn bị tinh thần!",
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),

            // Thứ tự xoay tua: Người trực tuần này nằm đầu tiên
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "THỨ TỰ XOAY TUA (TUẦN NÀY & KẾ TIẾP)",
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rotatedMembers.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final m = rotatedMembers[idx];
                      final isCurrentWeekPerson = (idx == 0);

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
                                  members: baseMembers,
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
                              border: Border.all(
                                color: isCurrentWeekPerson ? Colors.deepOrange.shade300 : Colors.grey.shade200,
                                width: isCurrentWeekPerson ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: isCurrentWeekPerson
                                      ? Colors.deepOrange
                                      : m.themeColor.withOpacity(0.15),
                                  foregroundColor: isCurrentWeekPerson ? Colors.white : m.themeColor,
                                  radius: 20,
                                  child: Text(
                                    "${idx + 1}",
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.name,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: isCurrentWeekPerson ? Colors.deepOrange.shade900 : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        isCurrentWeekPerson
                                            ? "👉 Trực tuần này"
                                            : (idx == 1 ? "Tuần tới" : (idx == 2 ? "2 tuần nữa" : "3 tuần nữa")),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: isCurrentWeekPerson ? Colors.deepOrange : Colors.grey.shade600,
                                          fontWeight: isCurrentWeekPerson ? FontWeight.bold : FontWeight.normal,
                                        ),
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

// Màn hình chi tiết tra cứu lịch đến 2050
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
            // Dropdown chọn năm
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

            // Thống kê
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
