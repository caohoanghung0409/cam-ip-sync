import 'package:flutter/material.dart';

void main() {
  runApp(const NoiDayApp());
}

class Member {
  final String name;
  final String role;
  final Color badgeColor;

  const Member({required this.name, required this.role, required this.badgeColor});
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
  // Đúng thứ tự yêu cầu: SÂM -> MINH -> TRINH -> HƯNG
  final List<Member> members = const [
    Member(name: "NGUYỄN THỊ SÂM", role: "Trực T7 tuần này (17/10)", badgeColor: Colors.deepOrange),
    Member(name: "NGUYỄN NGỌC HOÀNG MINH", role: "Thành viên", badgeColor: Colors.blue),
    Member(name: "LÂM TỐ TRINH", role: "Thành viên", badgeColor: Colors.purple),
    Member(name: "CAO HOÀNG HƯNG", role: "Thành viên", badgeColor: Colors.teal),
  ];

  late List<DutyShift> schedule;

  @override
  void initState() {
    super.initState();
    schedule = _generateSchedule();
  }

  // Kiểm tra ngày lễ rơi vào Thứ 7
  String? _checkHoliday(DateTime date) {
    // Tết Dương Lịch
    if (date.month == 1 && date.day == 1) return "Tết Dương Lịch";
    // 30/4 & 1/5
    if (date.month == 4 && date.day == 30) return "Giải Phóng Miền Nam";
    if (date.month == 5 && date.day == 1) return "Quốc Tế Lao Động";
    // Quốc Khánh 2/9
    if (date.month == 9 && (date.day >= 1 && date.day <= 3)) return "Nghỉ Lễ Quốc Khánh";
    // Giỗ tổ Hùng Vương / Tết Âm lịch
    if (date.year == 2027 && date.month == 2 && date.day == 6) return "Nghỉ Tết Nguyên Đán";

    return null;
  }

  // Thuật toán xếp lịch: Bắt đầu từ 17/10/2026 (Sâm -> Minh -> Trinh -> Hưng)
  List<DutyShift> _generateSchedule() {
    List<DutyShift> list = [];
    DateTime currentSaturday = DateTime(2026, 10, 17); // Thứ 7 tuần này

    int personIndex = 0; // 0: SÂM, 1: MINH, 2: TRINH, 3: HƯNG

    for (int i = 0; i < 52; i++) {
      DateTime satDate = currentSaturday.add(Duration(days: i * 7));
      String? holiday = _checkHoliday(satDate);
      String person = members[personIndex % members.length].name;

      if (holiday != null) {
        // Nghỉ lễ: Bỏ qua ca trực, KHÔNG dồn/không bù
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

      // Tuần tiếp theo vẫn luân chuyển bình thường
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
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white24,
            ),
            child: const Icon(Icons.flash_on, color: Colors.amber, size: 24),
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
            // Banner nổi bật: Tuần này
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
                  const SizedBox(height: 8),
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

            // Danh sách 4 thành viên theo thứ tự xoay tua
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
                                  backgroundColor: m.badgeColor.withOpacity(0.15),
                                  foregroundColor: m.badgeColor,
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
                                        idx == 0 ? "👉 Trực tuần này (17/10)" : "Nhấn để xem chi tiết & lịch trực",
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

// Màn hình chi tiết: "KHOAI MÌ CỦ CHI" + Lịch trực cá nhân
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
            // Card KHOAI MÌ CỦ CHI
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.restaurant_menu, size: 48, color: Colors.deepOrange),
                  const SizedBox(height: 12),
                  const Text(
                    "KHOAI MÌ CỦ CHI",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF00796B), letterSpacing: 1),
                  ),
                  const SizedBox(height: 6),
                  Text("Món ruột của: ${member.name}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Lịch trực của cá nhân
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "LỊCH TRỰC THỨ BẢY CỦA ${member.name.split(' ').last.toUpperCase()}",
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
                            const Icon(Icons.beach_access, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        Text(
                          "NGHỈ LỄ (${shift.holidayName})",
                          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
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
                          const Icon(Icons.calendar_today, color: Colors.teal, size: 18),
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
              onPressed
