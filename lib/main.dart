import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pro/prayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());

class MyApp extends StatefulWidget implements PreferredSizeWidget {
  MyApp({Key? key})
      : preferredSize = Size.fromHeight(kToolbarHeight),
        super(key: key);

  // var myFile = File('file.txt');
  void readFile() {}

  @override
  final Size preferredSize; // default is 56.0

  // var myFile = File('file.txt');
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future fetchAlbum([month = '7', year = '2021']) async {
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

  Future<File> writeCounter(counter) async {
    final file = await _localFile;

    // Write the file
    return file.writeAsString('$counter');
  }

  Future readTimingData() async {
    try {
      final file = await _localFile;
      // Read the file
      final contents = await file.readAsString();
      return contents;
    } catch (e) {
      return 0;
    }
  }

  bool _Loading = true;
  List<Prayers> prayers = [];

  Future<List<Prayers>> start() async {
    var res = await readTimingData();
    bool fetchMonthTimings = false;
    print('at the start method');

    print(res);

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
            year: d['date']['gregorian']['year']);
        prayers.add(prayer1);
        saveTimingLocalStorage += prayer1.write();
      }
    }

    ;
    void addINFO_from_local() {
      // print(value['data'][0]['timings']);
      print('------------- ${entries[0]}');
      for (var i = 0; i < entries.length - 1; i++) {
        print(entries[i]);
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
    }

    ;

    if ((saved_year == '$now_year') &&
        (saved_month == '$now_month')) // information already exist
    {
      print('same same samesamesame same same same same same');
      addINFO_from_local();
    } else {
      await fetchAlbum(now_month, now_year).then((value) async {
        addINFO_from_fetch(value);
        if (now_month == 12) {
          now_month = 0;
          now_year += 1;
        } // PREPARING PARAMETER FOR FETCH FOR THE NEXT MONTH
        now_month += 1;
        print('second fetch month $now_month year $now_year');

        await fetchAlbum(now_month, now_year).then((value2) {
          print('month $now_month year $now_year');
          addINFO_from_fetch(value2);
        });
        no = prayers.length;
        print('------------- $no');
        print('-->  $saveTimingLocalStorage');
        print('------------- ${prayers[prayers.length - 3]}');
        print(prayers[prayers.length - 1].write());
        var temp = saveTimingLocalStorage.split(';');
        print('${temp[temp.length - 2]}   <--');
        writeCounter(saveTimingLocalStorage);
      });
    }
    print('I am gone');
    return prayers;
  }

  late Future<List<Prayers>> futureAlbum;

  @override
  void initState() {
    super.initState();
    futureAlbum = start();
    // start();
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
          toolbarHeight: 69,
          title: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Text('Fetch Data Example'),
              Container(
                margin: EdgeInsets.fromLTRB(32, 11, 12, 1),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Date       '),
                      Text('Fajr  '),
                      Text('Duhur '),
                      Text('Asr   '),
                      Text('Magrib'),
                      Text('Isha  '),
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
            print(prayers.length);
            return ListView.builder(
              itemCount: prayers.length,
              itemBuilder: (con, index) {
                Prayers pray = prayers[index];
                print(con);
                print(index);
                return Card(
                  // color: (((saved_year == '$now_year') && (saved_month == '$now_month')) ?Colors.blue.shade50 : Colors.white,
                  child: Container(
                    margin: EdgeInsets.symmetric(vertical: 13, horizontal: 21),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        FlatButton(
                          onPressed: () async {
                            print('button is pressed');
                            var res = await readTimingData();
                            print(res);
                            writeCounter(
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
          onPressed: () {
            start();
          }
          // print(res);
          ,
          child: const Icon(Icons.cloud_download_outlined),
        ),
      ),
    );
  }
}
// Card(
// child: Container(
// margin: EdgeInsets.symmetric(vertical: 13, horizontal: 21),
// child: Row(
// mainAxisAlignment: MainAxisAlignment.spaceBetween,
// children: <Widget>[
// FlatButton(
// onPressed: () async {
// print('button is pressed');
// var res = await readTimingData();
// print(res);
// writeCounter(
// '2021/5/1.+1/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32;2021/6.+1/6=23:32 3:32 23:32 3:32 23:32+3/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32');
// },
// child: Text(
// '${pray.briefDate()}',
// ),
// ),
// Text('ddd'),
// Text('${pray.Dhuhr}'),
// Text('${pray.Asr}'),
// Text('${pray.Maghrib}'),
// Text('${pray.Isha}'),
// ],
// ),
// ),
// );
