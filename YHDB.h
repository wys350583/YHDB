//
//  YHDB.h
//
//  Created by wenyihong on 15/6/4.
//  Copyright (c) 2015年 yh. All rights reserved.
//

#import "FMDatabase.h"

@interface YHDB : FMDatabaseQueue

/**
 *  0 create path in document with a database name
 *
 *  @param name   0.a database:ever name you like
 *                  1.many databases:advise to use userId
 */
+ (void)createDB:(NSString *)name;

/**
 *  1 create singleton
 *
 *  @return singleton
 */
+ (YHDB *)share;

/**
 *  2 set singleton = nil
 *
 *  @return result
 */
+ (void)shareRelease;

/**
 *  3 create table
 *
 *  @param model      [[Model alloc] init]
 *  @param primaryKey table has primary key ? primaryKey = a key from model : nil;
 *
 *  @return result of create
 */
+ (BOOL)createTB:(id)model primaryKey:(NSString *)primaryKey;

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
               whereIn:(NSDictionary *)whereInDic;

/**
 *  5 insert data into table
 *
 *  @param model [[Model alloc] init]
 *
 *  @return result of insert
 */
+(BOOL)insert:(id)model;

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
whereIn:(NSDictionary *)whereInDic;

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
   whereArray:(NSArray *)whereArray;

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
                     limit:(NSDictionary *)limitDic;

/**
 *  9 select data from table with sql
 *
 *  @param model [[Model alloc] init]
 *  @param sql   sql
 *
 *  @return modelArray with data
 */
+ (NSMutableArray *)select:(id)model sql:(NSString *)sql;

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
                   wherePrimaryKeyIn:(NSArray *)primaryKeyArray;

/**
 *  11 select count from table
 *
 *  @param model    [[Model alloc] init]
 *  @param whereDic like sql 'where whereDic.key = whereDic.value'
 *
 *  @return count of table
 */
+ (int)selectCount:(id)model
          whereDic:(NSDictionary *)whereDic;

//////////////////////////////////////another way /////////////////////////////////////////////

/**
 *  0 create table
 *
 *  ex:[YHDB share].createTB([[Account alloc] init]).primaryKey(@"auth_phone").executeUpdate();
 *
 *  ex(no primaryKey):[YHDB share].createTB([[Account alloc] init]).executeUpdate();
 *
 */
- (YHDB *(^)(id))createTB;

/**
 *
 *  1 auto match to update or insert the data of a model or models which you input
 *
 *  ex(table with primaryKey):[YHDB share].save([NSArray arrayWithObjects:acc0, acc1, nil]).primaryKey(@"auth_phone").executeUpdate();
 *
 *  ex(table without primaryKey):[YHDB share].save([NSArray arrayWithObjects:acc0, acc1, nil]).where([NSDictionary dictionaryWithObjectsAndKeys:obj0, key0, obj1, key1, nil]).executeUpdate();
 *
 *  ex(table without primaryKey):[YHDB share].save([NSArray arrayWithObjects:acc0, acc1, nil]).whereIn([NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:obj0, obj1,nil] forKey:key]).executeUpdate();
 */
- (YHDB *(^)(NSArray *))save;

/**
 *  2 insert data into table
 *
 *  ex:[YHDB share].insert_(acc0).executeUpdate();
 *
 */
- (YHDB *(^)(id))insert_;

/**
 *  3 delete data from table
 *
 *  ex(delete all):[YHDB share].delete_().from([[Account alloc] init]).executeUpdate();
 *
 *  ex(delete some):[YHDB share].delete_().from([[Account alloc] init]).whereIn([NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:@"0", @"1",nil] forKey:@"accountId"]).executeUpdate();
 *
 *  ex(delete one):[YHDB share].delete_().from([[Account alloc] init]).where([NSDictionary dictionaryWithObject:[NSArray arrayWithObject:@"0",nil] forKey:@"accountId"]).executeUpdate();
 *
 */
- (YHDB *(^)())delete_;

/**
 *  4 update table
 *
 *  ex:[YHDB share].update(acc0).where([NSDictionary dictionaryWithObjectsAndKeys:obj0, key0, obj1, key1, nil]).executeUpdate();
 *
 */
- (YHDB *(^)(id))update;

/**
 *  5 select data from table: select(@"*") = select *
 *
 *  ex:[YHDB share].select([NSString stringWithString:string]).from([[Account alloc] init]).executeQuery();
 *  choose what you need:.where() | .whereIn() | .orderBy() | .groupBy() | .limit()
 *
 */
- (YHDB *(^)(NSString *))select;

/**
 *  6 primaryKey
 */
- (YHDB *(^)(NSString *))primaryKey;

/**
 *  7 form tablename : [[Model alloc] init]
 */
- (YHDB *(^)(id))from;

/**
 *  9   @{key : obj}
 */
- (YHDB *(^)(NSDictionary *))where;

/**
 *  10  @{key : arrayWithObjects}
 */
- (YHDB *(^)(NSDictionary *))whereIn;

/**
 *  11  @{@"ASC" : arrayWithObjects} | @{@"DESC" : arrayWithObjects}
 */
- (YHDB *(^)(NSDictionary *))orderBy;

/**
 *  12  @{@"GROUP BY" : arrayWithObjects}
 */
- (YHDB *(^)(NSDictionary *))groupBy;

/**
 *  13  @{@(start) : @(count)}
 */
- (YHDB *(^)(NSDictionary *))limit;

/**
 *  14 create | save | insert | update | delete
 */
- (void (^)())executeUpdate;

/**
 *  15 select
 */
- (NSMutableArray *(^)())executeQuery;

@end
