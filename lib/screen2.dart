import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'main.dart';

class SettingScreen extends StatefulWidget{
  const SettingScreen({Key? key}) : super(key: key);
  @override
  _Settings createState() => _Settings();
}
class _Settings extends State<SettingScreen> {
  @override
  void initState() {
    super.initState();
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
               title: Text('Athan London',
                    style: TextStyle(fontWeight: FontWeight.normal)),

          ),
          body:

          ListView.builder(
            itemCount: 4,
            itemBuilder: (
                con,
                index,
                ) {

              return Card(
                // color: today ? Colors.blue.shade50 : Colors.white,
                child: Container(
                  margin: EdgeInsets.symmetric(vertical: 13, horizontal: 21),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('hello'),
                      TextButton(
                        onPressed: () async {
                          print('button is pressed');

                        },
                        child: Text(
                          'refresh',
                        ),
                      ),
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
              Navigator.pop(context);

            }
            // print(res);
            ,
            child: const Icon(Icons.refresh_sharp),
          ),
        ),
      );
  }
}



