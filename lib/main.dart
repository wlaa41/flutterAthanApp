import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_pro/prayers.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'myGlobals.dart';

// FlutterLocalNotificationsPlugin notificationsPlugin =
//     FlutterLocalNotificationsPlugin();
void initalizeSettings() async {
  var initializeAndroid = AndroidInitializationSettings('rutaul');
  var initalizeSettings = InitializationSettings(android: initializeAndroid);
  notificationsPlugin.initialize(initalizeSettings);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBackgroundService.initialize(StartTIMER_RepeatedJob);

  runApp(MyApp());
}

late AudioPlayer player2 = AudioPlayer();

class MyApp extends StatefulWidget implements PreferredSizeWidget {
  MyApp({Key? key})
      : preferredSize = Size.fromHeight(kToolbarHeight),
        super(key: key);
  @override
  final Size preferredSize; // default is 56.0 IT ALLOW US TO CHANGE THE APP BAR
  @override
  _MyAppState createState() => _MyAppState();
}
class _MyAppState extends State<MyApp> {
  late AudioPlayer player;
  final Stream stream = FlutterBackgroundService().onDataReceived;

  // static bool notificationIsOn  = false;



  late Future<List<Prayers>> futureAlbum;
  // bool _Loading = true;
  List<Prayers> prayers = [];

  // FETCH SALAH TIME
  Future fetchOnly([month = '', year = '']) async {
    month = month==''? '${DateTime.now().month}' : month;
    year = year==''? '${DateTime.now().year}' : year;

    final response = await http.get(Uri.parse(
        'https://api.aladhan.com/v1/calendar?latitude=51.508515&longitude=-0.1254872&method=10&month=$month&year=$year'));
    if (response.statusCode == 200) {
      // If the server did return a 200 OK response,
      // then parse the JSON.
      return jsonDecode(response.body);
    } else {
      // If the server did not return a 200 OK response,
      // then throw an exception.
      throw Exception('Failed to load album');
    }
  }
  Future<String> get _localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  Future<File> get _localFile async {
    final path = await _localPath;
    return File('$path/timingData.txt');
  }
  Future<File> writeTimings(counter) async {
    final file = await _localFile;
    // Write the file
    return file.writeAsString('$counter');
  }
  Future readTiming() async {
    try {
      final file = await _localFile;
      // Read the file
      final contents = await file.readAsString();
      return contents;
    } catch (e) {
      return 0;
    }
  }
  Future<List<Prayers>> startFetchTiming(msg) async {
    var respond = await readTiming();
    String res = respond.toString();
    print('at the start method called by $msg');
    if(respond == 0 || respond.runtimeType == int)res = '2020-05-01.23:32+3:32+23:32+3:32+23:32';//   IN CASE THE IT WAS EMPTY
    var entries = res.split(';');
    DateTime now_date = DateTime.now();
    var now_month = now_date.month;
    var now_year = now_date.year;
    DateTime saved_Date = DateTime.parse(entries[0].split('.')[0]);

    prayers = [];
    int no = prayers.length;
    String saveTimingLocalStorage = '';

    void addTO_TimingList(Prayers prayer1){// METHOD TO ADD PRAYER BUT NOT TO ADD OLDER THAN 7 DAYS

      final difference =DateTime.now().difference( prayer1.date).inDays;
      if(difference<7){
        prayers.add(prayer1);
        print(prayers.length);

      }
    }
    void addINFO_from_fetch(value) {
      print('addINFO_from_fetch method is called and ---------------------------------->>>>>');
      List li = value['data'];
      // print('------------- $no');
      for (var i = 0; i < li.length; i++) {
        var d = li[i];
        var tempdate = d['date']['gregorian']['date'].split('-');
        var prayer1 = new Prayers(
            Fajr: d['timings']['Fajr'].split(' ')[0],
            Dhuhr: d['timings']['Dhuhr'].split(' ')[0],
            Asr: d['timings']['Asr'].split(' ')[0],
            Maghrib: d['timings']['Maghrib'].split(' ')[0],
            Isha: d['timings']['Isha'].split(' ')[0],
            date: DateTime.parse('${tempdate[2]}${tempdate[1]}${tempdate[0]}')
        );

        // print(prayer1.writeStorage());
        final difference = prayer1.date.difference(DateTime.now()).inDays;
        addTO_TimingList(prayer1);
        saveTimingLocalStorage += prayer1.writeStorage();


      }
    };



    void addINFO_from_local() {
      print(' ------------->>>>>  addINFO_from_local' );

      for (var i = 0; i < entries.length - 1; i++) {
        // print(entries[i]);
        var d = entries[i];
        var date = d.split('.')[0];
        var p5 = d.split('.')[1].split('+');
        var prayer1 = new Prayers(
            Fajr: p5[0],
            Dhuhr: p5[1],
            Asr: p5[2],
            Maghrib: p5[3],
            Isha: p5[4],
            date: DateTime.parse(date));
        addTO_TimingList(prayer1);
      }
    };


    if ((saved_Date.year == now_year) &&
        (saved_Date.month == now_month)) // information already exist
    {
      print('same same samesamesame same same same same same');
      addINFO_from_local();
    } else {
      print(' same not not not samesamesame notsame same same not same not same');

      await fetchOnly(now_month, now_year).then((value) async {
        addINFO_from_fetch(value);
        if (now_month == 12) {
          now_month = 0;
          now_year += 1;
        } // PREPARING PARAMETER FOR FETCH FOR THE NEXT MONTH
        now_month += 1;
        await fetchOnly(now_month, now_year).then((value2) {
          addINFO_from_fetch(value2);
        });
        if (now_month == 12) {
          now_month = 0;
          now_year += 1;
        } // PREPARING PARAMETER FOR FETCH FOR THE NEXT MONTH
        now_month += 1;
        await fetchOnly(now_month, now_year).then((value3) {
          addINFO_from_fetch(value3);
        });
        no = prayers.length;
        print('------------- $no');
        var temp = saveTimingLocalStorage.split(';');
        print('${temp[temp.length - 2]}   <--');
        writeTimings(saveTimingLocalStorage);
      });
    }
    print('I am gone');
    setState(() {

    });
    return prayers;
  }
  // MIGHT CAUSE A PROBLEM
  Future<String> get _localPath2 async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }
  Future<File> get _localFile2 async {
    final path = await _localPath2;
    return File('$path/DAYS.txt');
  }
  Future<File> writeAlarmedDAYS(counter) async {
    final file = await _localFile2;
    return file.writeAsString('$counter');
  }
  Future readAlarmedDAYS() async {
    try {
      final file = await _localFile2;
      // Read the file
      final contents = await file.readAsString();
      return contents;
    } catch (e) {
      return 0;
    }
  }


  void ListenToBackgroundService(data){
    print('Calling the JOB_Fetch_Update_Alarm();');
    print(data["message"]);
      switch (data["message"]){
      case 'update today highlight':
        // testing = testing == '27/7'? '28/7':'27/7';
        setState(() {

        });
        break;
        case 'update EVERYTHING':
          JOB_Fetch_Update_Alarm();
          break;

      }

  }
  // var focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    stream.listen((event) {ListenToBackgroundService(event);});
    // MyGlobals.writeGLOBAL('notification is NOT running');
    // futureAlbum = startFetchTiming('futureAlbum');
    tz.initializeTimeZones();
    initalizeSettings();
    // player = AudioPlayer();
    print('Calling the JOB_Fetch_Update_Alarm() <------------------------------------------------------------------');
    JOB_Fetch_Update_Alarm();
    // initRepeatedJob();
  }
  @override
  Widget build(BuildContext context) {
    print("build at _MyAppState");
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fetch Data Example',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: Scaffold(
        appBar: AppBar(
          toolbarHeight: 119,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              SizedBox(
                height: 33,
              ),
              Text('Athan London',
                  style: TextStyle(fontWeight: FontWeight.normal)),
              // Text('rutaul London Limited',style: MyStyle.getProgressHeaderStyle(),),

              // StreamBuilder<Map<String, dynamic>?>(
              //   stream: FlutterBackgroundService().onDataReceived,
              //   builder: (context, snapshot) {
              //     if (!snapshot.hasData) {
              //       return
              //       Text('rutaul London Limited',style: MyStyle.getProgressHeaderStyle(),);
              //
              //       //   Center(
              //       //   child: CircularProgressIndicator(),
              //       // );
              //     }
              //
              //     final data = snapshot.data!;
              //     DateTime? date = DateTime.tryParse(data["message"]);
              //     print(date.toString().split('.')[0]);
              //     return
              //     Text(data,style: MyStyle.getProgressHeaderStyle(),);
              // },
              // ),
            Text('rutaul London Limited',style: MyStyle.getProgressHeaderStyle(),),

            Container(
                margin: EdgeInsets.fromLTRB(22, 23, 12, 0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date  ',
                          style: MyStyle.getProgressHeaderStyle()),
                      Text('Fajr  ',
                          style: MyStyle.getProgressHeaderStyle()),
                      Text('Duhur ',
                          style: MyStyle.getProgressHeaderStyle()),
                      Text('Asr   ',
                          style: MyStyle.getProgressHeaderStyle()),
                      Text('Magrib',
                          style: MyStyle.getProgressHeaderStyle()),
                      Text('Isha  ',
                          style: MyStyle.getProgressHeaderStyle()),
                    ]),
              ),
            ],
          ),
        ),
        body:
        // FutureBuilder(
          // future: futureAlbum,
          // builder: (context, projectSnap) {
            // return
              ListView.builder(
              itemCount: prayers.length,
              itemBuilder: (
                con,
                index,
              ) {
                int nowday = DateTime.now().day;
                var now_day = nowday > 10 ? '$nowday' : '0$nowday';
                var now_month = '${DateTime.now().month}';
                bool today =
                    prayers[index].briefDate() == '$now_day/$now_month';
                    // prayers[index].briefDate() == testing;
                // print('$now_day/$now_month');
                Prayers pray = prayers[index];
                return Card(
                  color: today ? Colors.blue.shade50 : Colors.white,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 13, horizontal: 21),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        TextButton(
                          onPressed: () async {
                            print('button is pressed');

                            MyGlobals.createNotification(DateTime.now().add(Duration(seconds: 4)) ,'testing','created ${DateTime.now().toString().split('.')[0]}');

                          },
                          child: Text(
                            '${pray.briefDate()}',
                          ),
                        ),
                        Text(pray.Fajr),
                        Text('${pray.Dhuhr}'),
                        Text('${pray.Asr}'),
                        Text('${pray.Maghrib}'),
                        Text('${pray.Isha}'),
                      ],
                    ),
                  ),
                );
              },
            // );
          // },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            // print(await readAlarmedDAYS());
            // await JOB_Fetch_Update_Alarm();
            // JOB_Fetch_Update_Alarm();
            int PendingNotificationRequests = 0;
            await _checkPendingNotificationRequests().then((value) => PendingNotificationRequests = value);
            await MyGlobals.createNotification(DateTime.now().add(Duration(seconds: 3)),
                'PendingNotificationn','Count = $PendingNotificationRequests');
            // RestartEverything();
          }
          // print(res);
          ,
          child: const Icon(Icons.refresh_sharp),
        ),
      ),
    );
  }
  
  void RestartEverything()async{
    await MyGlobals.cancelAllNotifications();
    await writeAlarmedDAYS('');
    await writeTimings('');
    FlutterBackgroundService().sendData(
        {"action": "stopService"},);
    await FlutterBackgroundService.initialize(StartTIMER_RepeatedJob);
    FlutterBackgroundService().sendData({"action": "setAsBackground"});
    tz.initializeTimeZones();
    initalizeSettings();
    // player = AudioPlayer();
    print('Calling the JOB_Fetch_Update_Alarm() <------------------------------------------------------------------');
    JOB_Fetch_Update_Alarm();

  }



  Future<int> _checkPendingNotificationRequests() async {
    final List<PendingNotificationRequest> pendingNotificationRequests =
    await flutterLocalNotificationsPlugin.pendingNotificationRequests();
    print(pendingNotificationRequests);
    // print(pendingNotificationRequests[0]);
    print(pendingNotificationRequests.length);
    return pendingNotificationRequests.length;
    // return showDialog<void>(
    //   context: context,
    //   builder: (BuildContext context) => AlertDialog(
    //     content:
    //     Text('${pendingNotificationRequests.length} pending notification '
    //         'requests'),
    //     actions: <Widget>[
    //       TextButton(
    //         onPressed: () {
    //           Navigator.of(context).pop();
    //         },
    //         child: const Text('OK'),
    //       ),
    //     ],
    //   ),
    // );
  }


  Future<void> JOB_Fetch_Update_Alarm() async {

      // MyGlobals.cancelAllNotifications();
      // MyGlobals.notificationIsOn=true;
    //   var isRunning =
    // await FlutterBackgroundService().isServiceRunning();
    // FlutterBackgroundService.initialize(StartTIMER_RepeatedJob);
    // if (isRunning) {
    //   FlutterBackgroundService.initialize(StartTIMER_RepeatedJob);
      int PendingNotificationRequests = 0;
      await _checkPendingNotificationRequests().then((value) => PendingNotificationRequests = value);
      print("PendingNotificationRequests  =>  $PendingNotificationRequests");
      if(PendingNotificationRequests==0 ) await writeAlarmedDAYS('');
      var respond = await readAlarmedDAYS();// READ ALARM LIST
      // var respond = 0;// READ ALARM LIST  // Daprecated
      // bool fetchMonthTimings = false;
      String alarm_DayFile = respond.toString();
      print('at the start method');
      if(respond == 0 || respond.runtimeType == int)alarm_DayFile = '2020-11-11;';//   IN CASE THE IT WAS EMPTY
      List alarmDays = alarm_DayFile.split(';');
      var todaydate = new DateTime(DateTime
          .now()
          .year, DateTime
          .now()
          .month, DateTime
          .now()
          .day);
        if(alarmDays.length==1)alarmDays=[];// IF IT WAS EMPTY SPLIT(';') WILL GIVE IT A LENGTH OF 1
        if (alarmDays.length > 0) {
          print('alarmDays[0]');
          print(alarmDays[0]);
          print(alarmDays.length);
          var tempAlarmDate = DateTime.parse(alarmDays[0]);
          alarmDays.removeLast();// THE LAST ITEM IS '' AFTER ';'
          while (tempAlarmDate.compareTo(todaydate) < 0) { // REMOVING PAST DATES FROM
            if (alarmDays.length == 0) {
              print('break');
              break;
            }
            print('No break');
            alarmDays.removeAt(0);
            print(alarmDays.length);
            if (alarmDays.length > 0) {
              tempAlarmDate = DateTime.parse(alarmDays[0]);
            }
          }
        }
        print('the length of alarm days list after deleting is ${alarmDays.length}');
      DateTime startAlarmForm = DateTime.parse(DateTime.now().toString().split(' ')[0]).subtract(Duration(days: 1));
      if (alarmDays.isEmpty) {}
      else {
          DateTime lastDateWithAlarm = DateTime.parse(alarmDays[alarmDays.length-1]);
          if(startAlarmForm.compareTo(lastDateWithAlarm)>0 )// ALL DATE ARE IN THE PAST
              alarmDays = [];
          else
              startAlarmForm = lastDateWithAlarm;
      }
      int startfrom = alarmDays.length;
      await startFetchTiming('JOB_Fetch_Update_Alarm');// UPDATE PRAYERS
      for(int i = 0;i<prayers.length-22; i++)
        {
          if(prayers[i].date.compareTo(startAlarmForm)>0){
              DateTime now = DateTime.now();
              for (int j = startfrom; j < 37; j++) { // change 3 to 20 and delete this
                for(int salahNo = 1; salahNo<=5;salahNo++){
                  DateTime date = DateTime.parse(prayers[i].getPrayer(salahNo));
                  String title = prayers[i].getPrayerName(salahNo);
                  if(date.compareTo(now)>0){// IF THE DAY IS TODAY AND THE PRAYER IS PASSED .. DONOT SCHADULE ALARM
                    print('Adding alarm at $date');
                    MyGlobals.createNotification(date ,title,'created ${DateTime.now().toString().split('.')[0]}');
                  }
                }
                alarmDays.add(prayers[i].YMD());
                i++;
              }
              break;
            }
        }
      String addedDays = '';
      for(var n in alarmDays){
        addedDays += n+';';
      }
      print('.................................');
      writeAlarmedDAYS(addedDays);
    }

    // }

}
void StartTIMER_RepeatedJob() {
  print('++++++_______________________ Background Timer is triggered ________________________________++++++++++');
  WidgetsFlutterBinding.ensureInitialized();
  final service = FlutterBackgroundService();
  service.onDataReceived.listen((event) {
    if (event!["action"] == "setAsForeground") {
      service.setForegroundMode(true);
      return;
    }
    if (event["action"] == "setAsBackground") {
      service.setForegroundMode(false);
    }
    if (event["action"] == "stopService") {
      service.stopBackgroundService();
    }
  });
  // bring to foreground
  service.setForegroundMode(true);
  Timer.periodic(Duration(days: 9), (timer) async {
    if (!(await service.isServiceRunning())) timer.cancel();
    service.setNotificationInfo(
      title: "My App Service",
      content: "Updated at ${DateTime.now()}",
    );
    tz.initializeTimeZones();
    initalizeSettings();
    service.sendData(
      {"message": 'update EVERYTHING'},
    );
  });
  int minutesUntilTomorrow = DateTime.parse(DateTime.now()
      .add(Duration(days: 1)).toString().split(' ')[0])
      .difference(DateTime.now()).inMinutes  +  2;// Trigger to update the selected date
  Timer.periodic(Duration(minutes:minutesUntilTomorrow), (timer) async {
    if (!(await service.isServiceRunning())) timer.cancel();
    service.setNotificationInfo(
      title: "My App Service",
      content: "Updated at ${DateTime.now()}",
    );
    tz.initializeTimeZones();
    initalizeSettings();
    service.sendData(
      {"message": 'update today highlight'},
    );
  });
}
// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
// FlutterLocalNotificationsPlugin();
