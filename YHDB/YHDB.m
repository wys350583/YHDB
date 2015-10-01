//
//  YHDB.m
//
//  Created by wenyihong on 15/6/4.
//  Copyright (c) 2015年 yh. All rights reserved.
//

#import "YHDB.h"
#import <objc/runtime.h>

typedef NS_ENUM(NSInteger, ExecuteType) {
    Create = 0,
    Insert = 1,
    Update = 2,
    Delete = 3,
    Save   = 4,
};

static YHDB *yhDB = nil;

@implementation YHDB

ExecuteType EType;              //数据库操作类型
id _model;                      //实体
id _tbModel;                    //数据库实体
NSArray *_modelArray;           //modelArray;
NSString *_primaryKey;          //主键
NSMutableArray *_createTBArray; //创建语句
NSString *_selectString;        //select 语句
NSString *_whereString;         //where 语句
NSString *_whereInString;       //where in 语句
NSString *_orderByString;       //order by 语句
NSString *_groupByString;       //group by 语句
NSString *_limitString;         //limit语句

/**
 *  0 create path in document with a database name
 *
 *  @param name   0.a database:ever name you like
 *                  1.many databases:advise to use userId
 */
+ (void)createDB:(NSString *)name {
    if ([YHDB createFinderInDocumentWithFinderName:name]) {
        NSString *dBPath = [name stringByAppendingPathComponent:[name stringByAppendingString:@".db"]];
        [self userDefaultsSetObject:dBPath forKey:@"YHDBPATH"];
    }
    [self share];
}

/**
 *  1 create singleton
 *
 *  @return singleton
 */
+ (YHDB *)share {
    @synchronized(self) {
        if (!yhDB) {
            yhDB = [[YHDB alloc] initWithPath:[[self documentPath] stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] objectForKey:@"YHDBPATH"]]];
#if DEBUG
            NSLog(@"\n----------[YHDB Path]----------\n%@\n-------------------------------\n", yhDB.path);
#endif
        }
        return yhDB;
    }
}

/**
 *  2 set singleton = nil
 *
 *  @return result
 */
+ (void)shareRelease {
    if (yhDB) {
        yhDB = nil;
#if DEBUG
        NSLog(@"----------[YHDB Release]----------");
#endif
    }
}

/**
 *  3 create table
 *
 *  @param model      [[Model alloc] init]
 *  @param primaryKey table has primary key ? primaryKey = a key from model : nil;
 *
 *  @return result of create
 */
+ (BOOL)createTB:(id)model primaryKey:(NSString *)primaryKey {
    __block BOOL result;
    [[YHDB share] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        NSMutableArray *memberArray = [NSMutableArray array];
        NSString *primaryString = primaryKey == nil ? @"id integer PRIMARY KEY AUTOINCREMENT" : [NSString stringWithFormat:@"%@ %@ PRIMARY KEY", primaryKey, KT_Dic[primaryKey]];
        [memberArray addObject:primaryString];
        if (primaryKey) {
            [KT_Dic removeObjectForKey:primaryKey];
        }
        [KT_Dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [memberArray addObject:[NSString stringWithFormat:@"%@ %@", key, obj]];
        }];
        NSString *sql=[NSString stringWithFormat:@"CREATE TABLE if not exists %@ (%@)", [self tableName:model], [memberArray componentsJoinedByString:@","]];
        result = [db executeUpdate:sql];
#if DEBUG
        NSString *log = result ? @"\n----------[YHDB CreateTBSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB CreateTBFailed]----------\n%@\n-------------------------------\n",sql];
        NSLog(@"%@",log);
#endif
    }];
    return result;
}

/**
 *  4 auto match to update or insert the data of a model or models which you input
 *
 *  @param modelArray NSArray of model has value
 *  @param primaryKey table has primary key ? primaryKey = a key from model : nil;
 *  @param whereDic   if primary key == nil, then you need to input a whereDic{key0 : value0, key1 : value1, ...} to select the data in table which equal to the data you input and then the method will delele the data in table and insert you data
 *  @param whereInDic if primary key == nil, like param "whereDic"
 */
+ (void)updateOrInsert:(NSArray *)modelArray
            primaryKey:(NSString *)primaryKey
                 where:(NSDictionary *)whereDic
               whereIn:(NSDictionary *)whereInDic {
    if (modelArray.count > 0) {
        if (primaryKey) {
            //全部主键
            NSMutableArray *allPkMArray = [self getPkArrayFromModelArray:modelArray
                                                             primaryKey:primaryKey];
            //表中存在的主键:1条sql
            NSArray *updatePkArray = [self selectPrimaryKey:primaryKey
                                                       from:[modelArray lastObject]
                                          wherePrimaryKeyIn:allPkMArray];
            //如果存在更新的行
            if (updatePkArray.count > 0) {
                NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:[modelArray lastObject]];
                NSDictionary *whereInDic = [NSDictionary dictionaryWithObject:updatePkArray forKey:primaryKey];
                //表中存在的行
                NSMutableArray *updataModelMArray = [self select:[modelArray lastObject]
                                                           where:nil
                                                         whereIn:whereInDic
                                                         orderBy:nil
                                                         groupBy:nil
                                                           limit:nil];
                __block BOOL haveUpdate;
                NSMutableArray *modelMArray = [NSMutableArray arrayWithArray:modelArray];
                [modelMArray enumerateObjectsUsingBlock:^(id obj0, NSUInteger idx0, BOOL *stop0) {
                    haveUpdate = NO;
                    [updataModelMArray enumerateObjectsUsingBlock:^(id obj1, NSUInteger idx1, BOOL *stop1) {
                        if ([KT_Dic[primaryKey] isEqualToString:@"integer"]) {
                            if ([obj0 valueForKey:primaryKey] == [obj1 valueForKey:primaryKey]) {
                                haveUpdate = YES;
                            }
                        }
                        if ([KT_Dic[primaryKey] isEqualToString:@"text"]) {
                            if ([[obj0 valueForKey:primaryKey] isEqualToString:[obj1 valueForKey:primaryKey]]) {
                                haveUpdate = YES;
                            }
                        }
                        if (haveUpdate) {
                            [self update:obj0
                                 tbModel:obj1
                              whereArray:@[primaryKey]];
                            *stop1 = YES;
                        }
                    }];
                    if (!haveUpdate) {
                        [self insert:obj0];
                    }
                }];
            }
            else {//全部都是插入
                [modelArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [self insert:obj];
                }];
            }
        }
        else {//无主键:先删后插
            [self delete:[modelArray lastObject] where:whereDic whereIn:whereInDic];
            [modelArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [self insert:obj];
            }];
        }
    }
}


/**
 *  5 insert data into table
 *
 *  @param model [[Model alloc] init]
 *
 *  @return result of insert
 */
+(BOOL)insert:(id)model {
    __block BOOL result;
    [[YHDB share] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        __block NSMutableDictionary *KV_Dic = [NSMutableDictionary dictionary];
        [KT_Dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            id value = [model valueForKey:key];
            if (value) {
                [KV_Dic setObject:[self dbValue:value type:obj] forKey:key];
            }
            else {
                [KV_Dic setObject:@"''" forKey:key];
            }
        }];
        NSMutableString *sql= [NSMutableString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", [self tableName:model], [KV_Dic.allKeys componentsJoinedByString:@","], [KV_Dic.allValues componentsJoinedByString:@","]];
        result = [db executeUpdate:sql];
#if DEBUG
        NSString *log = result ? @"\n----------[YHDB InsertSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB InsertFailed]----------\n%@\n-------------------------------\n",sql];
        NSLog(@"%@",log);
#endif
    }];
    return result;
}

/**
 *  6 delete data from table
 *
 *  @param model      [[Model alloc] init]
 *  @param whereDic   like sql 'where whereDic.key = whereDic.value'
 *  @param whereInDic like sql 'where whereInDic.allKeys[0] in (whereInDic.allValues[0])'
 *
 *  @return rusult of delete
 */
+ (BOOL)delete:(id)model
         where:(NSDictionary *)whereDic
       whereIn:(NSDictionary *)whereInDic {
    __block BOOL result;
    [[YHDB share] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        NSString *deleteString;
        
        //WHERE字典:WHERE ? = ?
        if (whereDic) {
            NSMutableArray *whereArray = [NSMutableArray array];
            [whereDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [whereArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [self dbValue:obj type:KT_Dic[key]]]];
            }];
            deleteString = [NSString stringWithFormat:@"WHERE %@",[whereArray componentsJoinedByString:@"AND"]];
        }
        
        //WHERE IN (?)
        if (whereInDic && whereInDic.count == 1) {
            NSMutableArray *inArray = [NSMutableArray array];
            [whereInDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:[NSArray class]]) {
                    NSArray *objArray = obj;
                    [objArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        [inArray addObject:[NSString stringWithFormat:@" %@ ", [self dbValue:obj type:KT_Dic[key]]]];
                    }];
                }
            }];
            deleteString = [NSString stringWithFormat:@"WHERE %@ IN (%@)", whereInDic.allKeys[0], [inArray componentsJoinedByString:@","]];
        }
        
        
        NSString *sql= [NSString stringWithFormat:@"DELETE FROM %@ %@", [self tableName:model], deleteString];
        result = [db executeUpdate:sql];
#if DEBUG
        NSString *log = result ? @"\n----------[YHDB DeleteSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB DeleteFailed]----------\n%@\n-------------------------------\n",sql];
        NSLog(@"%@",log);
#endif
    }];
    return result;
}

/**
 *  7 update table
 *
 *  @param model           [[Model alloc] init]
 *  @param tbModel         model select from table，if you just want to update,you do not mind the data has change or not.
 *  @param whereArray      whereArray
 *
 *  @return result of update
 */
+(BOOL)update:(id)model
      tbModel:(id)tbModel
   whereArray:(NSArray *)whereArray {
    __block BOOL result;
    [[YHDB share] inDatabase:^(FMDatabase *db) {
        NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        NSMutableArray *memberArray = [NSMutableArray array];
        //有变化才更新
        if (tbModel) {
            [KT_Dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isEqualToString:@"integer"]) {
                    if (![[model valueForKey:key] isEqualToNumber:[tbModel valueForKey:key]]) {
                        id value = [model valueForKey:key];
                        if (value) {
                            [memberArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [self dbValue:[model valueForKey:key] type:KT_Dic[key]]]];
                        }
                    }
                }
                if ([obj isEqualToString:@"text"]) {
                    if (![[model valueForKey:key] isEqualToString:[tbModel valueForKey:key]]) {
                        id value = [model valueForKey:key];
                        if (value) {
                            [memberArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [self dbValue:[model valueForKey:key] type:KT_Dic[key]]]];
                        }

                    }
                }
            }];
        }
        //有没有变化都更新
        else {
            [KT_Dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                id value = [model valueForKey:key];
                if (value) {
                    [memberArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [self dbValue:[model valueForKey:key] type:KT_Dic[key]]]];
                }
            }];
        }
        if (memberArray.count > 0) {
            NSString *sql;
            NSString *whereString = [NSString string];
 
            if (whereArray) {
                NSMutableArray *where = [NSMutableArray array];
                [whereArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [where addObject:[NSString stringWithFormat:@" %@ = %@ ", obj, [self dbValue:[model valueForKey:obj] type:KT_Dic[obj]]]];
                }];
                whereString = [NSString stringWithFormat:@"WHERE %@", [where componentsJoinedByString:@"AND"]];
            }
            sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ %@", [self tableName:model], [memberArray componentsJoinedByString:@","], whereString];
            result = [db executeUpdate:sql];
#if DEBUG
            NSString *log = result ? @"\n----------[YHDB UpdateSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB UpdateFailed]----------\n%@\n-------------------------------\n",sql];
            NSLog(@"%@",log);
#endif
        }
    }];
    return result;
}

/**
 *  8 select data from table
 *
 *  @param model      [[Model alloc] init]
 *  @param whereDic   like sql 'where whereDic.key = whereDic.value'
 *  @param whereInDic like sql 'where whereInDic.allKeys[0] in (whereInDic.allValues[0])'
 *  @param orderByDic {"ASC||DESC" : "condition of order by"}
 *  @param groupByDic {"GROUP BY" : "condition of group by"}
 *  @param limitDic   {@(start) : @(count)}
 *
 *  @return modelArray with data
 */
+ (NSMutableArray *)select:(id)model
                     where:(NSDictionary *)whereDic
                   whereIn:(NSDictionary *)whereInDic
                   orderBy:(NSDictionary *)orderByDic
                   groupBy:(NSDictionary *)groupByDic
                     limit:(NSDictionary *)limitDic {
    __block id modelCopy;
    NSMutableArray *modelMArray = [NSMutableArray array];
    [[YHDB share] inDatabase:^(FMDatabase *db){
        NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        
        NSString *whereString = [NSString string];
        NSString *whereInString = [NSString string];
        NSString *orderByString = [NSString string];
        NSString *groupByString = [NSString string];
        NSString *limitString = [NSString string];
        
        //WHERE字典:WHERE ? = ?
        if (whereDic) {
            NSMutableArray *whereArray = [NSMutableArray array];
            [whereDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [whereArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [self dbValue:obj type:KT_Dic[key]]]];
            }];
            whereString = [NSString stringWithFormat:@"WHERE %@",[whereArray componentsJoinedByString:@"AND"]];
        }
        
        //WHERE IN (?)
        if (whereInDic && whereInDic.count == 1) {
            NSMutableArray *inArray = [NSMutableArray array];
            [whereInDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isKindOfClass:[NSArray class]]) {
                    NSArray *objArray = obj;
                    [objArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        [inArray addObject:[NSString stringWithFormat:@" %@ ", [self dbValue:obj type:KT_Dic[key]]]];
                    }];
                }
            }];
            whereInString = [NSString stringWithFormat:@"WHERE %@ IN (%@)", whereInDic.allKeys[0], [inArray componentsJoinedByString:@","]];
        }
        
        //ORDER BY字典:ORDER BY ? ASC||DESC
        if (orderByDic && orderByDic.count == 1) {
            orderByString = [NSString stringWithFormat:@"ORDER BY %@ %@", [orderByDic.allValues[0]  componentsJoinedByString:@","], orderByDic.allKeys[0]];
        }
        
        if (groupByDic && groupByDic.count == 1) {
            groupByString = [NSString stringWithFormat:@"GROUP BY  %@", [groupByDic.allValues[0] componentsJoinedByString:@","]];
        }
        if (limitDic) {
            limitString = [NSString stringWithFormat:@"LIMIT %@, %@", limitDic.allKeys[0], limitDic.allValues[0]];
        }
        
        //查询所有字段:SELECT * FROM TABLENAME
        NSMutableString *sql= [NSMutableString stringWithFormat:@"SELECT %@ FROM %@ %@ %@ %@ %@ %@", [KT_Dic.allKeys componentsJoinedByString:@", "], [self tableName:model], whereString, whereInString, orderByString, groupByString, limitString];
        FMResultSet *rs = [db executeQuery:sql];
#if DEBUG
        if (!rs) {
            NSLog(@"\n----------[YHDB Select]----------\n%@\n-------------------------------\n", rs.query);
        }
#endif
        while ([rs next]) {
            modelCopy = [[[model class] alloc]init];
            [KT_Dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([KT_Dic[key] isEqualToString:@"text"]) {
                    [modelCopy setValue:[rs stringForColumn:key] forKey:key];
                }
                if ([KT_Dic[key] isEqualToString:@"integer"]) {
                    [modelCopy setValue:@([rs intForColumn:key]) forKey:key];
                }
            }];
            [modelMArray addObject:modelCopy];
        }
        [rs close];
    }];
    return modelMArray;
}

/**
 *  9 select data from table with sql
 *
 *  @param model [[Model alloc] init]
 *  @param sql   sql
 *
 *  @return modelArray with data
 */
+ (NSMutableArray *)select:(id)model sql:(NSString *)sql {
    __block id modelCopy;
    NSMutableArray *modelMArray = [NSMutableArray array];
    [[YHDB share] inDatabase:^(FMDatabase *db){
        NSMutableDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            modelCopy = [[[model class] alloc]init];
            [KT_Dic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([KT_Dic[key] isEqualToString:@"text"]) {
                    [modelCopy setValue:[rs stringForColumn:key] forKey:key];
                }
                if ([KT_Dic[key] isEqualToString:@"integer"]) {
                    [modelCopy setValue:@([rs intForColumn:key]) forKey:key];
                }
            }];
            [modelMArray addObject:modelCopy];
        }
        [rs close];
    }];
    return modelMArray;
}

/**
 *  10 select primaryKey exist in table and primaryKeyArray
 *
 *  @param primaryKey      primaryKey
 *  @param model           [[Model alloc] init]
 *  @param primaryKeyArray primaryKeyArray
 *
 *  @return array of primaryKey exist in table and primaryKeyArray
 */
+ (NSMutableArray *)selectPrimaryKey:(NSString *)primaryKey
                                from:(id)model
                   wherePrimaryKeyIn:(NSArray *)primaryKeyArray {
    __block NSMutableArray *marray = [NSMutableArray array];
    [[YHDB share] inDatabase:^(FMDatabase *db) {
        NSDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        
        NSMutableArray *inArray = [NSMutableArray array];
        [primaryKeyArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [inArray addObject:[NSString stringWithFormat:@" %@ ", [self dbValue:obj type:KT_Dic[primaryKey]]]];
        }];
        NSString *primaryKeyString = [inArray componentsJoinedByString:@","];
        
        NSMutableString *sql= [NSMutableString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ in (%@)", primaryKey, [self tableName:model], primaryKey, primaryKeyString];
        FMResultSet *rs = [db executeQuery:sql];
        if ([KT_Dic[primaryKey] isEqualToString:@"integer"]) {
            while ([rs next]) {
                [marray addObject:@([rs intForColumn:primaryKey])];
            }
        }
        if ([KT_Dic[primaryKey] isEqualToString:@"text"]) {
            while ([rs next]) {
                [marray addObject:[rs stringForColumn:primaryKey]];
            }
        }
    }];
    return marray;
}

/**
 *  11 select count from table
 *
 *  @param model    [[Model alloc] init]
 *  @param whereDic like sql 'where whereDic.key = whereDic.value'
 *
 *  @return count of table
 */
+ (int)selectCount:(id)model
          whereDic:(NSDictionary *)whereDic {
    __block int count;
    [[YHDB share] inDatabase:^(FMDatabase *db){
        NSDictionary *KT_Dic = [self getKeysAndTypesFromModel:model];
        NSString *whereString = [NSString string];
        
        //WHERE字典:WHERE ? = ?
        if (whereDic) {
            NSMutableArray *whereArray = [NSMutableArray array];
            [whereDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [whereArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [self dbValue:obj type:KT_Dic[key]]]];
            }];
            whereString = [NSString stringWithFormat:@"WHERE %@",[whereArray componentsJoinedByString:@"AND"]];
        }
        
        NSString *sql= [NSString stringWithFormat:@"SELECT COUNT(1) AS count FROM %@ %@", [self tableName:model], whereString];
        FMResultSet *rs = [db executeQuery:sql];
        while ([rs next]) {
            count = [rs intForColumn:@"count"];
        }
        [rs close];
    }];
    return count;
}

#pragma utils
+ (void)userDefaultsSetObject:(id)obj forKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:obj forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (BOOL)createFinderInDocumentWithFinderName:(NSString *)finderName {
    NSString *finderPath = [[self documentPath] stringByAppendingPathComponent:finderName];
    if ( NO == [[NSFileManager defaultManager] fileExistsAtPath:finderPath])
    {
        return [[NSFileManager defaultManager] createDirectoryAtPath:finderPath
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:NULL];
    }
    return NO;
}

+ (NSString *)documentPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

+(NSString *)tableName:(id)model {
    return NSStringFromClass([model class]);
}

+ (NSMutableDictionary *)getKeysAndTypesFromModel:(id)model {
    NSMutableDictionary *keysAndTypesDic = [[[NSUserDefaults standardUserDefaults] objectForKey:[self tableName:model]] mutableCopy];
    if (keysAndTypesDic) {
        return keysAndTypesDic;
    }
    else {
        return [self getAllPropertyNamesAndTypesOfObject:model];
    }
}

//得到实体的Key和类型
+ (NSMutableDictionary *)getAllPropertyNamesAndTypesOfObject:(id)model {
    unsigned int outCount, i;
    NSMutableArray *propertyName = [NSMutableArray array];
    NSMutableArray *propertyType = [NSMutableArray array];
    objc_property_t *properties = class_copyPropertyList([model class], &outCount);
    
    for (i=0; i<outCount; i++) {
        objc_property_t property = properties[i];
        const char *propName = property_getName(property);
        if(propName) {
            const char *propType = getPropertyType(property);
            NSString *name = [NSString stringWithCString:propName
                                                encoding:[NSString defaultCStringEncoding]];
            NSString *type = [self translateToDBType:[NSString stringWithCString:propType
                                                                        encoding:[NSString defaultCStringEncoding]]];
            [propertyName addObject:name];
            [propertyType addObject:type];
            if (type.length == 0) {
                NSLog(@"YHDB Warning:(Property Type Warning)YHDB have not type of '%s' in property:'%@'",propType, name);
            }
        }
    }
    free(properties);
    NSMutableDictionary *namesAndTypesDic = [NSMutableDictionary dictionaryWithObjects:propertyType forKeys:propertyName];
    [self userDefaultsSetObject:namesAndTypesDic forKey:[self tableName:model]];
    return namesAndTypesDic;
}

static const char * getPropertyType(objc_property_t property) {
    const char *attributes = property_getAttributes(property);
    char buffer[1 + strlen(attributes)];
    strcpy(buffer, attributes);
    char *state = buffer, *attribute;
    while ((attribute = strsep(&state, ",")) != NULL) {
        if (attribute[0] == 'T' && attribute[1] != '@') {
            return (const char *)[[NSData dataWithBytes:(attribute + 1) length:strlen(attribute) - 1] bytes];
        }
        else if (attribute[0] == 'T' && attribute[1] == '@' && strlen(attribute) == 2) {
            // it's an ObjC id type:
            return "id";
        }
        else if (attribute[0] == 'T' && attribute[1] == '@') {
            // it's another ObjC object type:
            return (const char *)[[NSData dataWithBytes:(attribute + 3) length:strlen(attribute) - 4] bytes];
        }
    }
    return "";
}

+ (NSString *)translateToDBType:(NSString *)modelType {
    if ([modelType hasPrefix:@"NSString"]){
        return @"text";
    }
    if ([modelType isEqualToString:@"i"] || [modelType isEqualToString:@"q"] || [modelType isEqualToString:@"B"]){
        return @"integer";
    }
    if ([modelType isEqualToString:@"d"]) {
        return @"real";
    }
    return @"";
}

//返回实体数组的所有主键
+ (NSMutableArray *)getPkArrayFromModelArray:(NSArray *)modelArray primaryKey:(NSString *)primaryKey {
    NSMutableArray *pkArray = [NSMutableArray array];
    [modelArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [pkArray addObject:[obj valueForKey:primaryKey]];
    }];
    return pkArray;
}

+ (NSString *)dbValue:(id)value type:(id)type {
    if ([type isEqualToString:@"text"]) {
        return [NSString stringWithFormat:@" '%@' ",value];
    }
    if ([type isEqualToString:@"integer"] || [type isEqualToString:@"real"]) {
        return [NSString stringWithFormat:@" %@ ",value];
    }
    return @"";
}
////////////////////////////////////////another way///////////////////////////////////////////

/**
 *  0 create table
 *
 */
- (YHDB *(^)(id))createTB {
    return ^YHDB* (id t) {
        EType = Create;
        _model = t;
        return self;
    };
}

/**
 *  1 auto match to update or insert the data of a model or models which you input
 *
 */
- (YHDB *(^)(NSArray *))save {
    return ^YHDB *(NSArray * t) {
        EType = Save;
        _modelArray = t;
        return self;
    };
}

/**
 *  2 insert data into table
 *
 */
- (YHDB *(^)(id))insert_ {
    return ^YHDB* (id t) {
        EType = Insert;
        _model = t;
        return self;
    };
}

/**
 *  3 delete data from table
 *
 */
- (YHDB *(^)())delete_ {
    return ^YHDB* {
        EType = Delete;
        return self;
    };
}

/**
 *  4 update table
 *
 */
- (YHDB *(^)(id))update {
    return ^YHDB* (id t) {
        EType = Update;
        _model = t;
        return self;
    };
}

/**
 *  5 select data from table
 *
 */
- (YHDB *(^)(NSString *))select {
    return ^YHDB *(NSString * t) {
        _selectString = t;
        return self;
    };
}

/**
 *  6 primaryKey
 */
- (YHDB *(^)(NSString *))primaryKey {
    return ^YHDB *(NSString *t) {
        _primaryKey = t;
        return self;
    };
}

/**
 *  7 form tablename : [[Model alloc] init]
 */
- (YHDB *(^)(id))from {
    return ^YHDB* (id t) {
        _model = t;
        return self;
    };
}

/**
 *  8 tbModel select from table,use in update to compare to model
 */
- (YHDB *(^)(id))tbModel {
    return ^YHDB* (id t) {
        _tbModel = t;
        return self;
    };
}

/**
 *  9
 */
- (YHDB *(^)(NSDictionary *))where {
    return ^YHDB *(NSDictionary *t) {
        //WHERE字典:WHERE ? = ?
        if (t) {
            NSMutableDictionary *KT_Dic = [YHDB getKeysAndTypesFromModel:_model];
            NSMutableArray *whereArray = [NSMutableArray array];
            [t enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                [whereArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [YHDB dbValue:obj type:KT_Dic[key]]]];
            }];
            _whereString = [NSString stringWithFormat:@"WHERE %@",[whereArray componentsJoinedByString:@"AND"]];
        }
        return self;
    };
}

/**
 *  10
 */
- (YHDB *(^)(NSDictionary *))whereIn {
    return ^YHDB *(NSDictionary *t) {
        //WHERE IN (?)
        if (t && t.count == 1) {
            NSMutableDictionary *KT_Dic = [YHDB getKeysAndTypesFromModel:_model];
            if (t && t.count == 1) {
                NSMutableArray *inArray = [NSMutableArray array];
                [t enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([obj isKindOfClass:[NSArray class]]) {
                        NSArray *objArray = obj;
                        [objArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                            [inArray addObject:[NSString stringWithFormat:@" %@ ", [YHDB dbValue:obj type:KT_Dic[key]]]];
                        }];
                    }
                }];
                _whereInString = [NSString stringWithFormat:@"WHERE %@ IN (%@)", t.allKeys[0], [inArray componentsJoinedByString:@","]];
            }
        }
        return self;
    };
}

/**
 *  11
 */
- (YHDB *(^)(NSDictionary *))orderBy {
    return ^YHDB *(NSDictionary *t) {
        //ORDER BY字典:ORDER BY ? ASC||DESC
        if (t && t.count == 1) {
            _orderByString = [NSString stringWithFormat:@"ORDER BY %@ %@", [t.allValues[0]  componentsJoinedByString:@","], t.allKeys[0]];
        }
        return self;
    };
}

/**
 *  12
 */
- (YHDB *(^)(NSDictionary *))groupBy {
    return ^YHDB *(NSDictionary *t) {
        if (t && t.count == 1) {
            _groupByString = [NSString stringWithFormat:@"GROUP BY  %@", [t.allValues[0] componentsJoinedByString:@","]];
        }
        return self;
    };
}

/**
 *  13
 */
- (YHDB *(^)(NSDictionary *))limit {
    return ^YHDB *(NSDictionary *t) {
        if (t) {
            _limitString = [NSString stringWithFormat:@"LIMIT %@, %@", t.allKeys[0], t.allValues[0]];
        }
        return self;
    };
}

/**
 *  14 create | save | insert | update | delete
 */
- (void (^)())executeUpdate {
    return ^ {
        switch (EType) {
            case Create:{
                [self executeCreate];
            }
                break;
                
            case Insert:{
                [self executeInsert];
            }
                break;
                
            case Delete:{
                [self executeDelete];
            }
                break;
                
            case Update:{
                [self executeUpdate_];
            }
                break;
                
            case Save:{
                [self excuteSave];
            }
                break;
                
            default:
                break;
        }
    };
}

/**
 *  15 select
 */
- (NSMutableArray *(^)())executeQuery {
    return ^NSMutableArray *{
        __block id modelCopy;
        NSMutableArray *modelMArray = [NSMutableArray array];
        [yhDB inDatabase:^(FMDatabase *db){
            if (!_whereString) {
                _whereString = [NSString string];
            }
            if (!_whereInString) {
                _whereInString = [NSString string];
            }
            if (!_orderByString) {
                _orderByString = [NSString string];
            }
            if (!_groupByString) {
                _groupByString = [NSString string];
            }
            if (!_limitString) {
                _limitString = [NSString string];
            }
            NSMutableDictionary *KTDic = [YHDB getKeysAndTypesFromModel:_model];
            
            if ([_selectString isEqualToString:@"*"]) {
                _selectString = [KTDic.allKeys componentsJoinedByString:@", "];
            }
            NSMutableString *sql= [NSMutableString stringWithFormat:@"SELECT %@ FROM %@ %@ %@ %@ %@ %@", _selectString, [YHDB tableName:_model], _whereString, _whereInString, _orderByString, _groupByString, _limitString];
            FMResultSet *rs = [db executeQuery:sql];
#if DEBUG
            if (!rs) {
                NSLog(@"\n----------[YHDB Select]----------\n%@\n-------------------------------\n", rs.query);
            }
#endif
            while ([rs next]) {
                modelCopy = [[[_model class] alloc]init];
                [KTDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                    if ([KTDic[key] isEqualToString:@"text"]) {
                        [modelCopy setValue:[rs stringForColumn:key] forKey:key];
                    }
                    if ([KTDic[key] isEqualToString:@"integer"]) {
                        [modelCopy setValue:@([rs intForColumn:key]) forKey:key];
                    }
                }];
                [modelMArray addObject:modelCopy];
            }
            [rs close];
        }];
        _whereString = nil;
        _whereInString = nil;
        _orderByString = nil;
        _groupByString = nil;
        _limitString = nil;
        return modelMArray;
    };
}

/**
 *  16 create
 */
- (void)executeCreate {
    [yhDB inDatabase:^(FMDatabase *db){
        if (!_primaryKey) {
            _primaryKey = [NSString string];
        }
        _createTBArray = [NSMutableArray array];
        NSMutableDictionary *KTDic = [YHDB getKeysAndTypesFromModel:_model];
        NSString *primaryString = [_primaryKey isEqualToString: @""] ? @"id integer PRIMARY KEY AUTOINCREMENT" : [NSString stringWithFormat:@"%@ %@ PRIMARY KEY", _primaryKey, KTDic[_primaryKey]];
        [_createTBArray addObject:primaryString];
        if (_primaryKey) {
            [KTDic removeObjectForKey:_primaryKey];
        }
        [KTDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            [_createTBArray addObject:[NSString stringWithFormat:@"%@ %@", key, obj]];
        }];
        NSString *sql = [NSString stringWithFormat:@"CREATE TABLE if not exists %@ (%@)", [YHDB tableName:_model], [_createTBArray componentsJoinedByString:@","]];
        BOOL result = [db executeUpdate:sql];
        _primaryKey = nil;
#if DEBUG
        NSString *log = result ? @"\n----------[YHDB CreateTBSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB CreateTBFailed]----------\n%@\n-------------------------------\n",sql];
        NSLog(@"%@",log);
#endif
    }];
}

/**
 *  17 insert
 */
- (void)executeInsert {
    [yhDB inDatabase:^(FMDatabase *db){
        NSMutableDictionary *KTDic = [YHDB getKeysAndTypesFromModel:_model];
        __block NSMutableDictionary *KVDic = [NSMutableDictionary dictionary];
        [KTDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            id value = [_model valueForKey:key];
            if (value) {
                [KVDic setObject:[YHDB dbValue:value type:obj] forKey:key];
            }
            else {
                [KVDic setObject:@"''" forKey:key];
            }
        }];
        NSString *sql= [NSMutableString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", [YHDB tableName:_model], [KVDic.allKeys componentsJoinedByString:@","], [KVDic.allValues componentsJoinedByString:@","]];
        BOOL result = [db executeUpdate:sql];
#if DEBUG
        NSString *log = result ? @"\n----------[YHDB InsertSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB InsertFailed]----------\n%@\n-------------------------------\n",sql];
        NSLog(@"%@",log);
#endif
    }];
}

/**
 *  18
 */
- (void)executeDelete {
    [yhDB inDatabase:^(FMDatabase *db){
        if (!_whereString) {
            _whereString = [NSString string];
        }
        if (!_whereInString) {
            _whereInString = [NSString string];
        }
        NSString *sql= [NSString stringWithFormat:@"DELETE FROM %@ %@ %@", [YHDB tableName:_model], _whereString, _whereInString];
        BOOL result = [db executeUpdate:sql];
        _whereString = nil;
        _whereInString = nil;
#if DEBUG
        NSString *log = result ? @"\n----------[YHDB DeleteSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB DeleteFailed]----------\n%@\n-------------------------------\n",sql];
        NSLog(@"%@",log);
#endif
    }];
}

/**
 *  19 update
 */
- (void)executeUpdate_ {
    [yhDB inDatabase:^(FMDatabase *db){
        NSMutableDictionary *KTDic = [YHDB getKeysAndTypesFromModel:_model];
        NSMutableArray *memberArray = [NSMutableArray array];
        if (_tbModel) {
            [KTDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                if ([obj isEqualToString:@"integer"]) {
                    if (![[_model valueForKey:key] isEqualToNumber:[_tbModel valueForKey:key]]) {
                        id value = [_model valueForKey:key];
                        if (value) {
                            [memberArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [YHDB dbValue:[_model valueForKey:key] type:KTDic[key]]]];
                        }
                    }
                }
                if ([obj isEqualToString:@"text"]) {
                    if (![[_model valueForKey:key] isEqualToString:[_tbModel valueForKey:key]]) {
                        id value = [_model valueForKey:key];
                        if (value) {
                            [memberArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [YHDB dbValue:[_model valueForKey:key] type:KTDic[key]]]];
                        }
                    }
                }
            }];
        }
        else {
            [KTDic enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
                id value = [_model valueForKey:key];
                if (value) {
                    [memberArray addObject:[NSString stringWithFormat:@" %@ = %@ ", key, [YHDB dbValue:[_model valueForKey:key] type:KTDic[key]]]];
                }
            }];
        }
        if (memberArray.count > 0) {
            if (!_whereString) {
                _whereString = [NSString string];
            }
            NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ %@", [YHDB tableName:_model], [memberArray componentsJoinedByString:@","], _whereString];
            BOOL result = [db executeUpdate:sql];
            _whereString = nil;
#if DEBUG
            NSString *log = result ? @"\n----------[YHDB UpdateSucceed]----------\n" : [NSString stringWithFormat:@"\n----------[YHDB UpdateFailed]----------\n%@\n-------------------------------\n",sql];
            NSLog(@"%@",log);
#endif
        }
    }];
}

/**
 *  20 update | insert
 */
- (void)excuteSave {
    if (_primaryKey) {
        //全部主键
        NSMutableArray *allPkMArray = [YHDB getPkArrayFromModelArray:_modelArray
                                                          primaryKey:_primaryKey];
        //表中存在的主键:1条sql
        NSArray *updatePkArray = [YHDB selectPrimaryKey:_primaryKey
                                                   from:[_modelArray lastObject]
                                      wherePrimaryKeyIn:allPkMArray];
        //如果存在更新的行
        if (updatePkArray.count > 0) {
            NSMutableDictionary *KT_Dic = [YHDB getKeysAndTypesFromModel:[_modelArray lastObject]];
            NSDictionary *whereInDic = [NSDictionary dictionaryWithObject:updatePkArray forKey:_primaryKey];
            //表中存在的行
            NSMutableArray *updataModelMArray = self.select(@"*").from([_modelArray lastObject]).whereIn(whereInDic).executeQuery();
            
            __block BOOL haveUpdate;
            NSMutableArray *modelMArray = [NSMutableArray arrayWithArray:_modelArray];
            [modelMArray enumerateObjectsUsingBlock:^(id obj0, NSUInteger idx0, BOOL *stop0) {
                haveUpdate = NO;
                [updataModelMArray enumerateObjectsUsingBlock:^(id obj1, NSUInteger idx1, BOOL *stop1) {
                    if ([KT_Dic[_primaryKey] isEqualToString:@"integer"]) {
                        if ([obj0 valueForKey:_primaryKey] == [obj1 valueForKey:_primaryKey]) {
                            haveUpdate = YES;
                        }
                    }
                    if ([KT_Dic[_primaryKey] isEqualToString:@"text"]) {
                        if ([[obj0 valueForKey:_primaryKey] isEqualToString:[obj1 valueForKey:_primaryKey]]) {
                            haveUpdate = YES;
                        }
                    }
                    if (haveUpdate) {
                        NSDictionary *whereDic = [NSDictionary dictionaryWithObject:[obj1 valueForKey:_primaryKey] forKey:_primaryKey];
                        self.update(obj0).tbModel(obj1).where(whereDic).executeUpdate();
                        *stop1 = YES;
                    }
                }];
                if (!haveUpdate) {
                    self.insert_(obj0).executeUpdate();
                }
            }];
        }
        else {
            [_modelArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                self.insert_(obj).executeUpdate();
            }];
        }
        _primaryKey = nil;
    }
    else {
        if (_whereString || _whereInString) {
            self.delete_().from([_modelArray lastObject]).executeUpdate();
        }
        [_modelArray enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            self.insert_(obj).executeUpdate();
        }];
    }
    _whereString = nil;
    _whereInString = nil;
}

@end
