part of redis_client;


abstract class RedisSerializer {

  factory RedisSerializer() => new JsonRedisSerializer();

  List<int> serialize(Object obj);  

  String serializeToString(Object obj);
  
  List<String> serializeFromZSet(Set<ZSetEntry> zSet);
  
  List<String> serializeToList(Object obj);

  Object deserialize(List<int> bytes);
  Map<String, Object> deserializeToMap(List<RedisReply> replies);
}




class JsonRedisSerializer implements RedisSerializer {

  static final int OBJECT_START = 123; // {
  static final int ARRAY_START  = 91;  // [
  static final int ZERO         = 48;  // 0
  static final int NINE         = 57;  // 9
  static final int SIGN         = 45;  // -

  static final String DATE_PREFIX = "/Date(";
  static final String DATE_SUFFIX = ")/";
  static final String TRUE  = "true";
  static final String FALSE = "false";

  /**
   * Serializes given object into its' String representation and returns the
   * binary of it.
   */
  List<int> serialize(Object? obj) {
    if (obj == null) return [];
    return utf8.encode(serializeToString(obj));
  }
  
  /**
   * Serializes given object into its' String representation.
   */    
  String serializeToString(dynamic obj) {
    if (obj is String) return obj;
    else if (obj is DateTime) return "$DATE_PREFIX${obj.millisecondsSinceEpoch}$DATE_SUFFIX";
    else if (obj is Set) return serializeToString(obj.toList());
    else return json.encode(obj);
  }
  
  /**
   * Serializes objects into lists of strings.
   */   
  List<String> serializeToList(Object? obj) {
    if (obj == null) return [];
    
    List<String> values = [];
    if (obj is Iterable) {
      values.addAll(obj.map(serializeToString));
    } else if (obj is Map) {
      values.addAll(serializeFromMap(obj));
    } else { values.add(serializeToString(obj)); }
    return values;
  }

  /**
   * Deserializes the String form of given bytes and returns the native object
   * for it.
   */
  Object deserialize(List<int> deserializable) {
    if (deserializable == null) return deserializable;
    var decodedObject = utf8.decode(deserializable);
    try { decodedObject = json.decode(decodedObject); } 
    on FormatException catch (e) { }
    
    if (decodedObject is String) {
      if (_isDate(decodedObject)) {
        int timeSinceEpoch = int.parse(decodedObject.substring(DATE_PREFIX.length, decodedObject.length - DATE_SUFFIX.length));
        return new DateTime.fromMillisecondsSinceEpoch(timeSinceEpoch, isUtc: true);    
      }
    } 
    return decodedObject;
  }

  
  List<String> serializeFromMap(Map map) {
    List<String> variadicValueList = [];
    var i = 0;
    map.forEach((key, value) {
      variadicValueList[i++] = serializeToString(key);
      variadicValueList[i++] = serializeToString(value);
    });

    return variadicValueList;
  }
  
  List<String> serializeFromZSet(Iterable<ZSetEntry> zSet) {
    List<String> variadicValueList = [];
    var i = 0;
    
    zSet.forEach((ZSetEntry zSetEntry) {
      variadicValueList[i++] = serializeToString(zSetEntry.score);
      variadicValueList[i++] = serializeToString(zSetEntry.entry);
    });
    
    return variadicValueList;
  }

  Map<String, Object> deserializeToMap(List<RedisReply> replies) {
    Map<String, Object> multiBulkMap = new Map<String, Object>();
    if (replies.isNotEmpty) {
      for (int i = 0 ; i < replies.length ; i++) {
        String key = deserialize((replies[i] as BulkReply).bytes!) as String;
        multiBulkMap[key] = deserialize((replies[++i] as BulkReply).bytes!);
      }
    }
    return multiBulkMap;
  }
  
  bool _isDate(decodedString) => decodedString.startsWith(DATE_PREFIX);
}

class ZSetEntry<Object, num> {
  Object entry;
  num score;
  
  ZSetEntry(this.entry, this.score);
}