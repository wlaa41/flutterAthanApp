import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_pro/prayers.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();
void initalizeSettings() async {
  var initializeAndroid = AndroidInitializationSettings('rutaul');
  var initalizeSettings = InitializationSettings(android: initializeAndroid);
  notificationsPlugin.initialize(initalizeSettings);
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBackgroundService.initialize(StartRepeatedJob);

  runApp(MyApp());
}

late AudioPlayer player2 = AudioPlayer();
void StartRepeatedJob() {
  print('++++++_________________________________________________________________+++++++++++++_______________++++++++++++++');
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
  Timer.periodic(Duration(seconds: 33), (timer) async {
    if (!(await service.isServiceRunning())) timer.cancel();
    service.setNotificationInfo(
      title: "My App Service",
      content: "Updated at ${DateTime.now()}",
    );
    print('...  --->     <---  .....');
    print('...  --->     <---  .....');
    // player2.dispose();
    // await player2.setAsset('asset/smooth.mp3');
    // print(player2);
    // player2.play();
    init

    service.sendData(
      {"current_date": DateTime.now().toString()},
    );
  });
}

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

  late Future<List<Prayers>> futureAlbum;
  bool _Loading = true;
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
  Future<List<Prayers>> startFetchTiming() async {
    var res = await readTiming();
    bool fetchMonthTimings = false;
    print('at the start method');
    // print(res);
    var entries = res.split(';');
    var now_month = DateTime.now().month;
    var now_year = DateTime.now().year;
    
    var saved_yearmonth = entries[0].split('.')[0].split('/');
    var saved_year = saved_yearmonth[0];
    var saved_month = saved_yearmonth[1];
    var saved_day = saved_yearmonth[2];
    prayers = [];
    int no = prayers.length;
    String saveTimingLocalStorage = '';
    void addINFO_from_fetch(value) {
      // print(value['data'][0]['timings']);
      List li = value['data'];
      // print('------------- $no');
      for (var i = 0; i < li.length; i++) {
        var d = li[i];
        var prayer1 = new Prayers(
            Fajr: d['timings']['Fajr'].split(' ')[0],
            Dhuhr: d['timings']['Dhuhr'].split(' ')[0],
            Asr: d['timings']['Asr'].split(' ')[0],
            Maghrib: d['timings']['Maghrib'].split(' ')[0],
            Isha: d['timings']['Isha'].split(' ')[0],
            day: d['date']['gregorian']['day'],
            month: '${d['date']['gregorian']['month']['number']}',
            year: d['date']['gregorian']['year'],
            date: DateTime.parse(d['date']['gregorian']['date'])
        );
        prayers.add(prayer1);
        saveTimingLocalStorage += prayer1.write();
      }
    };
    void addINFO_from_local() {
      // print(value['data'][0]['timings']);
      // print('------------- ${entries[0]}');
      for (var i = 0; i < entries.length - 1; i++) {
        // print(entries[i]);
        var d = entries[i];
        var date = d.split('.')[0].split('/');
        var p5 = d.split('.')[1].split('+');
        var prayer1 = new Prayers(
            Fajr: p5[0],
            Dhuhr: p5[1],
            Asr: p5[2],
            Maghrib: p5[3],
            Isha: p5[4],
            day: date[2],
            month: date[1],
            year: date[0]);
        prayers.add(prayer1);
      }
    };

    if ((saved_year == '$now_year') &&
        (saved_month == '$now_month')) // information already exist
    {
      print('same same samesamesame same same same same same');
      addINFO_from_local();
    } else {
      await fetchOnly(now_month, now_year).then((value) async {
        addINFO_from_fetch(value);
        if (now_month == 12) {
          now_month = 0;
          now_year += 1;
        } // PREPARING PARAMETER FOR FETCH FOR THE NEXT MONTH
        now_month += 1;
        print('second fetch month $now_month year $now_year');
        await fetchOnly(now_month, now_year).then((value2) {
          print('month $now_month year $now_year');
          addINFO_from_fetch(value2);
        });
        no = prayers.length;
        print('------------- $no');
        // print('-->  $saveTimingLocalStorage');
        // print('------------- ${prayers[prayers.length - 3]}');
        // print(prayers[prayers.length - 1].write());
        var temp = saveTimingLocalStorage.split(';');
        print('${temp[temp.length - 2]}   <--');
        writeTimings(saveTimingLocalStorage);
      });
    }
    print('I am gone');
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
  Future<File> writeDAYS(counter) async {
    final file = await _localFile2;
    return file.writeAsString('$counter');
  }
  Future readDAYS() async {
    try {
      final file = await _localFile2;
      // Read the file
      final contents = await file.readAsString();
      return contents;
    } catch (e) {
      return 0;
    }
  }

  Future<void> createNotification(date) async {
    notificationsPlugin.zonedSchedule(
        0,
        'Athan',
        'Notification',
        tz.TZDateTime.from(date, tz.local),
        NotificationDetails(
          android: AndroidNotificationDetails(
            'channel id',
            'channel name',
            'channel description',
            importance: Importance.max,
            priority: Priority.max,
            sound: RawResourceAndroidNotificationSound('smooth'),
          ),
        ),
        uiLocalNotificationDateInterpretation:
        UILocalNotificationDateInterpretation.absoluteTime,
        androidAllowWhileIdle: true);
  }

  @override
  void initState() {
    super.initState();
    futureAlbum = startFetchTiming();
    tz.initializeTimeZones();
    initalizeSettings();
    player = AudioPlayer();
    startFetchTiming();
    // initRepeatedJob();
    print("initState at _MyAppState");
  }

  @override
  Widget build(BuildContext context) {
    print("build at _MyAppState");

    return MaterialApp(
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
              Container(
                margin: EdgeInsets.fromLTRB(32, 23, 12, 0),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date       ',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, fontSize: 18)),
                      Text('Fajr  ',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, fontSize: 18)),
                      Text('Duhur ',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, fontSize: 18)),
                      Text('Asr   ',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, fontSize: 18)),
                      Text('Magrib',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, fontSize: 18)),
                      Text('Isha  ',
                          style: TextStyle(
                              fontWeight: FontWeight.normal, fontSize: 18)),
                    ]),
              ),
            ],
          ),
        ),
        body: FutureBuilder(
          future: futureAlbum,
          builder: (context, projectSnap) {
            print('hellow');
            // print(projectSnap.data);
            // print(prayers.length);
            return ListView.builder(
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
                // print('$now_day/$now_month');
                Prayers pray = prayers[index];
                return Card(
                  color: today ? Colors.blue.shade50 : Colors.white,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 13, horizontal: 21),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FlatButton(
                          onPressed: () async {
                            // print('button is pressed');
                            // var res = await readTiming();
                            // print(res);
                            writeTimings(
                                '2021/5/1.+1/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32;2021/6.+1/6=23:32 3:32 23:32 3:32 23:32+3/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32');
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
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            startFetchTiming();

            await writeDAYS('2021-03-12;2021-03-12;2021-03-12;2021-03-12;2021-09-12;2021-09-12;');
            print(await readDAYS());
            await initRepeatedJob();
          }
          // print(res);
          ,
          child: const Icon(Icons.cloud_download_outlined),
        ),
      ),
    );
  }
  Future<void> initRepeatedJob() async {
    var isRunning =
    await FlutterBackgroundService().isServiceRunning();
    FlutterBackgroundService.initialize(StartRepeatedJob);

    print('is it running $isRunning');
    print('is it running $isRunning');

    if (isRunning) {
      // FlutterBackgroundService().sendData(
      //   {"action": "stopService"},
      // );

      FlutterBackgroundService.initialize(StartRepeatedJob);
      var alarm_DayFile = await readDAYS();
      print(alarm_DayFile);
      List alarmDays = alarm_DayFile.split(';');
      print(alarmDays);
      var todaydate = new DateTime(DateTime.now().year,DateTime.now().month,DateTime.now().day);
      var tempAlarmDate = DateTime.parse(alarmDays[0]);

      try{
        alarmDays.removeLast();  // THE LAST ITEM IS '' AFTER ';'
      }catch(e){}

      // int length = alarmDays.length-1; // THE LAST ITEM IS '' AFTER ';'
      int deletedItem = 0;
      while(tempAlarmDate.compareTo(todaydate)<0 )
        {

          if(alarmDays.length == 0)
            break;
          alarmDays.removeAt(0);
          print(alarmDays.length);
          if(alarmDays.length > 0) {
            print(alarmDays[0]);
            tempAlarmDate = DateTime.parse(alarmDays[0]);}
        }
        print(alarmDays);
      // startFetchTiming();
      int startfrom = 0;

      for (int i = startfrom; i < 20; i++) {

      }
    }
    }
}
