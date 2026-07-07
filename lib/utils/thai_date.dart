import 'package:intl/intl.dart';

/// ตัวช่วยจัดรูปแบบวันที่ภาษาไทยแบบปี พ.ศ.
///
/// `intl` (`DateFormat` locale th_TH) แสดงปีเป็น ค.ศ. เสมอ จึงต้องบวก 543 เอง
/// ใช้ตัวช่วยเหล่านี้แทนการเรียก `DateFormat('...yyyy...','th_TH')` ตรง ๆ
/// เพื่อให้ทั้งแอปแสดงวันที่เป็น "วัน + เดือนไทย + ปี พ.ศ." สม่ำเสมอ

/// "25 ก.ค. 2569" — วัน + เดือนย่อไทย + ปี พ.ศ. (ใช้กับพื้นที่จำกัด: การ์ด/ชิป/ลิสต์)
String thaiDateShort(DateTime d) =>
    '${DateFormat('d MMM', 'th_TH').format(d)} ${d.year + 543}';

/// "25 กรกฎาคม 2569" — วัน + เดือนเต็มไทย + ปี พ.ศ. (ใช้กับหัวข้อ/พื้นที่กว้าง)
String thaiDateFull(DateTime d) =>
    '${DateFormat('d MMMM', 'th_TH').format(d)} ${d.year + 543}';

/// "25 ก.ค. 2569 14:30" — วัน+เดือนย่อ+ปี พ.ศ. ตามด้วยเวลา
String thaiDateTimeShort(DateTime d) =>
    '${thaiDateShort(d)} ${DateFormat('HH:mm').format(d)}';

/// "กรกฎาคม 2569" — เดือนเต็มไทย + ปี พ.ศ. (หัวปฏิทิน)
String thaiMonthYear(DateTime d) =>
    '${DateFormat('MMMM', 'th_TH').format(d)} ${d.year + 543}';

/// "อา. 25 ก.ค. 2569" — วันในสัปดาห์ + วัน + เดือนย่อ + ปี พ.ศ.
String thaiDateShortWeekday(DateTime d) =>
    '${DateFormat('EEE d MMM', 'th_TH').format(d)} ${d.year + 543}';
