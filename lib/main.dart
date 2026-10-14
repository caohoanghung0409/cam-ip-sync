import 'package:flutter/material.dart';

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
  // Đúng thứ tự xoay tua: SÂM -> MINH -> TRINH -> HƯNG
  final List<Member> members = const [
    Member(name: "NGUYỄN THỊ SÂM", shortName: "SÂM", themeColor: Colors.deepOrange),
    Member(name: "NGUYỄN NGỌC HOÀNG MINH", shortName: "MINH", themeColor: Colors.blue),
    Member(name: "LÂM TỐ TRINH", shortName: "TRINH", themeColor: Colors.purple),
    Member(name: "CAO HOÀNG HƯNG", shortName: "HƯNG", themeColor: Colors.teal),
  ];

  late List<DutyShift> schedule;

  @override
  void initState() {
    super.initState();
    schedule = _generateSchedule();
  }

  // Nhận diện ngày lễ rơi vào Thứ 7
  String? _checkHoliday(DateTime date) {
    if (date.month == 1 && date.day == 1) return "Tết Dương Lịch";
    if (date.month == 4 && date.day == 30) return "Giải Phóng Miền Nam";
    if (date.month == 5 && date.day == 1) return "Quốc Tế Lao Động";
    if (date.month == 9 && (date.day >= 1 && date.day <= 3)) return "Quốc Khánh 2/9";
    if (date.year == 2027 && date.month == 2 && date.day == 6) return "Tết Nguyên Đán";
    return null;
  }

  // Thuật toán: Bắt đầu Thứ 7 tuần này (17/10/2026) cho SÂM
  List<DutyShift> _generateSchedule() {
    List<DutyShift> list = [];
    DateTime currentSaturday = DateTime(2026, 10, 17);

    int personIndex = 0; // 0: Sâm, 1: Minh, 2: Trinh, 3: Hưng

    for (int i = 0; i < 52; i++) {
      DateTime satDate = currentSaturday.add(Duration(days: i * 7));
      String? holiday = _checkHoliday(satDate);
      String person = members[personIndex % members.length].name;

      if (holiday != null) {
        // Nghỉ lễ: Đánh dấu miễn trực, KHÔNG DỒN
        list.add(DutyShift(
          date: satDate,
          assignedPerson: person,
          isHoliday: true,
          holidayName: holiday,
        ));
      } else {
        list.add(DutyShift(
          date: satDate,
          assignedPerson: person,
          isHoliday: false,
        ));
      }

      // Tuần tiếp theo vẫn chuyển
