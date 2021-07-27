class Prayers {
  Prayers({
    required this.Fajr,
    required this.Dhuhr,
    required this.Asr,
    required this.Maghrib,
    required this.Isha,
    required this.day,
    required this.month,
    required this.year,
    required this.date
  });
  String Fajr;
  String Dhuhr;
  String Asr;
  String Maghrib;
  String Isha;
  String day;
  String month;
  String year;
  DateTime date;


  String briefDate() {
    return '$day/$month';
  }

  @override
  String toString() {
    return '${day}/${month}    ${Fajr}    ${Dhuhr}    ${Asr}    ${Maghrib}    ${Isha}    ${year}';
  }
  String writeStorage() {
    //   2021-05-01.23:32+3:32+23:32+3:32+23:32
    return '${date.toString().split(' ')[0]}.${Fajr}+${Dhuhr}+${Asr}+${Maghrib}+${Isha};';
  }
  String write() {
    //;2021/5.+1/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32
    return '${year}/${month}/${day}.${Fajr}+${Dhuhr}+${Asr}+${Maghrib}+${Isha};';
  }
}

class monthDate {
  monthDate({
    required this.day,
    required this.month,
    required this.year,
  });
  String day;
  String month;
  String year;
}
