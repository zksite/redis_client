library redis_client_tests;

import 'dart:async';
import 'dart:utf';

import 'package:logging/logging.dart';
import 'package:unittest/unittest.dart';

import 'package:unittest/mock.dart';

import '../lib/redis_client.dart';


import 'helper.dart';



main() {

  group("RedisClient", () {

    RedisClient client;

    setUp(() {
      return RedisClient.connect("127.0.0.1:6379")
          .then((c) {
            client = c;
            client.flushall();
          });
    });

    tearDown(() {
      try {
        client.close();
      }
      finally {

      }
    });

    group("select", () {
      test("should correctly switch databases", () {
        async(
          client.set("testkey", "database0") // Setting testskey in database 0
              .then((_) => client.select(1)) // Switching to databse 1
              .then((_) => client.set("testkey", "database1"))

              .then((_) => client.select(0)) // Switching back to database 0
              .then((_) => client.get("testkey"))
              .then((value) => expect(value, equals("database0")))

              .then((_) => client.select(1)) // Switching back to database 1
              .then((_) => client.get("testkey"))
              .then((value) => expect(value, equals("database1")))
        );
      });
    });

//    group("Basic commands: GET, SET, GETSET RANDOMKEY RENAME RENAMENX TTL PTTL:", () {

    group("parseInfoString()", () {
      test("should properly parse info strings", () {
        var string =  """
# Server
redis_version:2.6.2
redis_git_sha1:00000000
redis_git_dirty:0
redis_mode:standalone

# Clients
connected_clients:3
client_longest_output_list:0
client_biggest_input_buf:0
blocked_clients:0
""";

        var info = client.parseInfoString(string);
        expect(info["Server"]["redis_version"], equals("2.6.2"));
        expect(info["Clients"]["client_biggest_input_buf"], equals("0"));
      });
      test("should throw exception on invalid info", () {
        var string =  """
invalid_line:invalid            
# Server
redis_version:2.6.2
redis_git_sha1:00000000
""";
        expect(() => client.parseInfoString(string), throwsException);

        string =  """
# Server
invalid_line
""";
        expect(() => client.parseInfoString(string), throwsException);
      });

    });

    group("Admin commands:", () {
      test("DBSIZE", () {
        async(
          client.dbsize
                .then((size) => expect(size, equals(0)))
                .then((_) => client.set("test", "test"))
                .then((_) => client.set("test2", "test"))
                .then((_) => client.dbsize)
                .then((size) => expect(size, equals(2)))
        );
      });
      test("FLUSHDB", () {
        async(
          client.select(0)
              .then((_) => client.set("test", "testvalue"))
              .then((_) => client.get("test"))
              .then((value) => expect(value, equals("testvalue")))
              .then((_) => client.select(1))
              .then((_) => client.get("test"))
              .then((value) => expect(value, equals(null)))
              .then((_) => client.set("test2", "testvalue2"))
              .then((_) => client.get("test2"))
              .then((value) => expect(value, equals("testvalue2")))
              .then((_) => client.flushdb())
              .then((_) => client.get("test2"))
              .then((value) => expect(value, equals(null)))
              .then((_) => client.select(0))
              .then((_) => client.get("test"))
              .then((value) => expect(value, equals("testvalue")))
        );
      });
      test("FLUSHALL", () {
        async(
            client.select(0)
            .then((_) => client.set("test", "testvalue"))
            .then((_) => client.select(1))
            .then((_) => client.set("test2", "testvalue2"))
            .then((_) => client.flushall())
            .then((_) => client.get("test2"))
            .then((value) => expect(value, equals(null)))
            .then((_) => client.select(0))
            .then((_) => client.get("test"))
            .then((value) => expect(value, equals(null)))
        );
      });
      test("SAVE & LASTSAVE", () {
        async(
          client.save()
              .then((_) => client.lastsave)
              .then((DateTime saveTime) {
                expect(saveTime.difference(new DateTime.now()).inMilliseconds, lessThan(10));
              })
        );
      });
      test("BGSAVE", () {
        async(
          client.bgsave()
              .then((_) => client.lastsave)
              .then((DateTime saveTime) {
                expect(saveTime.difference(new DateTime.now()).inMilliseconds, lessThan(10));
              })
        );
      });
      test("INFO", () {
        async(
          client.info
              .then((infoMap) {
                expect(infoMap["Server"]["redis_version"] is String, equals(true));
                expect(infoMap["Clients"]["connected_clients"] is String, equals(true));
              })
        );
      });

    });

    group("Basic commands:", () {
      test("GET & SET", () {
        async(
          client.set("testkey", "testvalue")
              .then((_) => client.get("testkey"))
              .then((String value) => expect(value, equals("testvalue")))
              .then((_) => client.get("invalidkey"))
              .then((res) => expect(res, equals(null)))
        );
      });

      test("KEYS", () {
        async(
          client.keys("*o*")
              .then((List<String> keys) => expect(keys, equals([])))
              .then((_) => client.set("onekey", "a"))
              .then((_) => client.set("twokey", "a"))
              .then((_) => client.set("threekey", "a"))
              .then((_) => client.keys("*o*"))
              .then((List<String> keys) => expect(keys, equals([ "twokey", "onekey" ])))
        );
      });

      test("GETSET", () {
        async(
          client.getset("nokeysa", "value")
              .then((String value) => expect(value, equals(null)))
              .then((_) => client.getset("nokeysa", "value2"))
              .then((String value) => expect(value, equals("value")))
         );
      });

      test("MGET", () {
        async(
          client.mget([ "a", "b", "c" ])
              .then((List<Object> objects) {
                expect(objects.length, equals(3));
                expect(objects[0], equals(null));
                expect(objects[1], equals(null));
                expect(objects[2], equals(null));
              })
              .then((_) => client.set("a", "value1"))
              .then((_) => client.set("c", "value2"))
              .then((_) => client.mget([ "a", "b", "c" ]))
              .then((List<Object> objects) {
                expect(objects.length, equals(3));
                expect(objects[0], equals("value1"));
                expect(objects[1], equals(null));
                expect(objects[2], equals("value2"));
              })
        );
      });

      test("SETEX & TTL", () {
        async(
          client.setex("testkey", 10, "value")
              .then((_) => client.ttl("testkey"))
              .then((int time) => expect(time, equals(10)))
         );
      });

      test("PSETEX", () {
        async(
            client.psetex("testkey", 10000, "value")
            .then((_) => client.ttl("testkey"))
            .then((int time) => expect(time, equals(10)))
        );
      });

      test("PERSIST", () {
        async(
            client.setex("testkey", 10, "value")
            .then((_) => client.ttl("testkey"))
            .then((int time) => expect(time, equals(10)))
            .then((_) => client.persist("testkey"))
            .then((status) => expect(status, equals(true)))
            .then((_) => client.ttl("testkey"))
            .then((int time) => expect(time, equals(-1)))
            .then((_) => client.persist("invalidkey"))
            // Should return false when the key didn't exist.
            .then((status) => expect(status, equals(false)))
        );
      });

      test("MSET", () {
        async(
            client.mset({ "key1": "test1", "key2": true, "key3": 123 })
            .then((_) => client.get("key1"))
            .then((String value) => expect(value, equals("test1")))
            .then((_) => client.get("key2"))
            .then((bool value) => expect(value, equals(true)))
            .then((_) => client.get("key3"))
            .then((int value) => expect(value, equals(123)))
        );
      });

      test("MSETNX", () {
        async(
            client.msetnx({ "key1": "test1", "key2": true, "key3": 123 })
            .then((bool value) => expect(value, equals(true)))
            .then((_) => client.msetnx({ "key2": "test1", "randomkey": true, "randomkey2": 123 }))
            // Should return false if **one** key already existed.
            .then((bool value) => expect(value, equals(false)))
        );
      });

      test("EXISTS", () {
        async(
            client.exists("keyname")
            .then((bool value) => expect(value, equals(false)))
            .then((_) => client.set("keyname", "test"))
            .then((_) => client.exists("keyname"))
            .then((bool value) => expect(value, equals(true)))
        );
      });

      test("DEL", () {
        async(
            client.del("keyname")
            .then((bool value) => expect(value, equals(false)))
            .then((_) => client.set("keyname", "test"))
            .then((_) => client.del("keyname"))
            .then((bool value) => expect(value, equals(true)))
        );
      });

      test("MDEL", () {
        async(
            client.mdel([ "keyname", "keyname2", "keyname3" ])
            .then((int value) => expect(value, equals(0)))
            .then((_) => client.mset({ "keyname2": "test", "keyname3": "test" }))
            .then((_) => client.mdel([ "keyname", "keyname2", "keyname3" ]))
            .then((int value) => expect(value, equals(2)))
        );
      });


    });


  });

}