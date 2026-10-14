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

  String? _checkHoliday(DateTime date) {
    if (date.month == 1 && date.day == 1) return "Tết Dương Lịch";
    if (date.month == 4 && date.day == 30) return "Giải Phóng Miền Nam";
    if (date.month == 5 && date.day == 1) return "Quốc Tế Lao Động";
    if (date.month == 9 && (date.day >= 1 && date.day <= 3)) return "Quốc Khánh 2/9";
    if (date.year == 2027 && date.month == 2 && date.day == 6) return "Tết Nguyên Đán";
    return null;
  }

  List<DutyShift> _generateSchedule() {
    List<DutyShift> list = [];
    DateTime currentSaturday = DateTime(2026, 10, 17);
    int personIndex = 0;

    for (int i = 0; i < 52; i++) {
      DateTime satDate = currentSaturday.add(Duration(days: i * 7));
      String? holiday = _checkHoliday(satDate);
      String person = members[personIndex % members.length].name;

      if (holiday != null) {
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
      personIndex++;
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final nextDuty = schedule.firstWhere((s) => !s.isHoliday);

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
                          color: Colors.amber,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          "${nextDuty.date.day.toString().padLeft(2, '0')}/${nextDuty.date.month.toString().padLeft(2, '0')}/${nextDuty.date.year}",
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black87),
                        ),
                      )
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    nextDuty.assignedPerson,
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    "Đến lượt cày cuốc, chuẩn bị tinh thần!",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
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
                                builder: (context) => MemberDetailScreen(
                                  member: m,
                                  allSchedule: schedule,
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
                                      Text(
                                        idx == 0 ? "👉 Trực tuần này (17/10)" : "Nhấn để xem danh sách ca trực",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: idx == 0 ? Colors.deepOrange : Colors.grey.shade600,
                                          fontWeight: idx == 0 ? FontWeight.bold : FontWeight.normal,
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

class MemberDetailScreen extends StatelessWidget {
  final Member member;
  final List<DutyShift> allSchedule;

  const MemberDetailScreen({
    super.key,
    required this.member,
    required this.allSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final myShifts = allSchedule.where((s) => s.assignedPerson == member.name).toList();
    final actualShiftsCount = myShifts.where((s) => !s.isHoliday).length;
    final holidayShiftsCount = myShifts.where((s) => s.isHoliday).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(member.name, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: member.themeColor.withOpacity(0.15),
                    child: Icon(Icons.person, size: 32, color: member.themeColor),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    member.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatBox("Ca thực tế", "$actualShiftsCount ca", Colors.teal),
                      Container(height: 30, width: 1, color: Colors.grey.shade300),
                      _buildStatBox("Được miễn (Lễ)", "$holidayShiftsCount ca", Colors.deepOrange),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "DANH SÁCH CA TRỰC THỨ BẢY (52 TUẦN)",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
              ),
            ),
            const SizedBox(height: 10),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: myShifts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final shift = myShifts[idx];
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
