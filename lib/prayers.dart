class Prayers {
  Prayers({
    required this.Fajr,
    required this.Dhuhr,
    required this.Asr,
    required this.Maghrib,
    required this.Isha,
    // required this.day,
    // required this.month,
    // required this.year,
    required this.date
  });
  String Fajr;
  String Dhuhr;
  String Asr;
  String Maghrib;
  String Isha;
  // String day;
  // String month;
  // String year;
  DateTime date;

  String getPrayerName(int salahNo){ //  ""
    String time ='';
    switch(salahNo){
      case 1:
        time= 'Fajr';
        break;
      case 2:
        time= 'Dhuhr';
        break;
      case 3:
        time= 'Asr';
        break;
      case 4:
        time= 'Maghrib';
        break;
      case 5:
        time= 'Isha';
        break;
    }
    return ''+ YMD()+' '+time;
  }
    String getPrayer(int salahNo){ //  "2012-02-27 13:27:00"
      String time ='';
      switch(salahNo){
        case 1:
          time= Fajr+':00';
          break;
        case 2:
          time= Dhuhr+':00';
          break;
        case 3:
          time= Asr+':00';
          break;
        case 4:
          time= Maghrib+':00';
          break;
        case 5:
          time= Isha+':00';
          break;
      }
    return ''+ YMD()+' '+time;
  }



  String briefDate() {
    return '${date.day}/${date.month}';
  }
  @override
  String YMD() {  //  IT RETURNS  YYYY-mm-dd  FORMAT
    return '${date.toString().split(' ')[0]}';
  }
  @override
  String toString() {
    return '${date.day}/${date.month}    ${Fajr}    ${Dhuhr}    ${Asr}    ${Maghrib}    ${Isha}    ${date.year}';
  }
  String writeStorage() {
    //   2021-05-01.23:32+3:32+23:32+3:32+23:32;2021-05-01.23:32+3:32+23:32+3:32+23:32;
    return '${date.toString().split(' ')[0]}.${Fajr}+${Dhuhr}+${Asr}+${Maghrib}+${Isha};';
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
