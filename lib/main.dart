import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pro/prayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

void main() => runApp(const MyApp());

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  // var myFile = File('file.txt');
  void readFile() {}

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

  @override
  void initState() {
    super.initState();
    print("initState at _MyAppState");
    fetchAlbum().then((value) {
      print(value['data'][0]['timings']);
    });
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
          title: const Text('Fetch Data Example'),
        ),
        body: ListView.builder(
          itemBuilder: (context, index) {
            return Card(
              child: Container(
                margin: EdgeInsets.symmetric(vertical: 13, horizontal: 21),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    FlatButton(
                      onPressed: () {
                        print('button is pressed');
                        var now = DateTime.now();
                        print(now.month);
                        print(now.year);
                        writeCounter(
                            '2021/5/1.+1/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32;2021/6.+1/6=23:32 3:32 23:32 3:32 23:32+3/6=23:32 3:32 23:32 3:32 23:32+4/6=23:32 3:32 23:32 3:32 23:32');
                      },
                      child: Text(
                        'hello',
                      ),
                    ),
                    Text('hello'),
                  ],
                ),
              ),
            );
          },
          itemCount: 49,
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            var res = await readTimingData();
            bool fetchMonthTimings = false;
            var entries = res.split(';');
            print(entries);
            var now_month = DateTime.now().month;
            var now_year = DateTime.now().year;
            var saved_yearmonth = entries[0].split('.')[0].split('/');
            var saved_year = saved_yearmonth[0];
            var saved_month = saved_yearmonth[1];
            var saved_day = saved_yearmonth[2];

            print('SAVED  ---- month $saved_month year $saved_year');
            print('month $now_month year $now_year');
            if (saved_year == now_year &&
                saved_month == now_month) // information already exist
            {
              print('same same samesamesame same same same same same');
            } else {
              print('not the same -------------------------------------------');

              prayers = [];
              String saveTimingLocalStorage = '';
              var value = await fetchAlbum(now_month, now_year).then((value) {
                print(value['data'][0]['timings']);
                List li = value['data'];
                int no = prayers.length;
                print('------------- $no');
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
                if (now_month == '12') {
                  now_month = 1;
                  now_year += 1;
                } // PREPARING PARAMETER FOR FETCH FOR THE NEXT MONTH

                no = prayers.length;
                print('------------- $no');
                print('-->  $saveTimingLocalStorage');
                print('------------- ${prayers[prayers.length - 3]}');
              });
            }

            print(res);
          },
          child: const Icon(Icons.cloud_download_outlined),
        ),

        // body: Center(
        //   child: FutureBuilder<Album>(
        //     future: futureAlbum,
        //     builder: (context, snapshot) {
        //       if (snapshot.hasData) {
        //         return Text(snapshot.data!.title);
        //       } else if (snapshot.hasError) {
        //         return Text('${snapshot.error}');
        //       }
        //
        //       // By default, show a loading spinner.
        //       return const CircularProgressIndicator();
        //     },
        //   ),
      ),
    );
  }
}
// children: <Widget>[
//   Text(
//     'You have pushed the button this many times:',
//   ),
//   Text(
//     '$_counter',
//     style: Theme.of(context).textTheme.headline4,
//   ),
// ],
