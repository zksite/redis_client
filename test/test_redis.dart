import 'dart:io';

import 'package:redis_client/redis_protocol_transformer.dart';
import 'package:test/test.dart';
import 'package:redis_client/redis_client.dart';
  main(){
  
    test("random stuff", () {
      // RedisConnection.connect("127.0.0.1:6378").then((c) async{
      //   print("..........");
      //   c.send(["SELECT", "1"]);
      //   c.send(["SADD", "test2", "hallo1"]);
      // }).catchError((e){
      //   print(e);
      // });
      Socket.connect("127.0.0.1", 6378).then((value) => print(value))
          .catchError((e){
            print(e);
      });
    });
}