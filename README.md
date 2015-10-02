# YHDB
####Package based on fmdb,used to conveniently call database operation.

##Install
#####Download the [YHDB](https://github.com/wyhazq/YHDB/archive/master.zip) &  [fmdb](https://github.com/ccgus/fmdb) 

##Create Database
#####1.Create a database for all users.
```Objective-C
[YHDB createDB:@"CB"];
```
#####2.Create databases for every user.
```Objective-C
[YHDB createDB:obj0.userId];
```

##Create Table
#####1.Table with primary key
```Objective-C
[YHDB createTB:@{[[User alloc] init] : @"userId"}];
```
#####2.Table without primary key
```Objective-C
[YHDB createTB:@{[[User alloc] init] : @""}];
```

##Save
#####Automatic matching for insert or update
#####1.Table with primary key
```Objective-C
[YHDB save:[NSArray arrayWithObjects:obj0, ..., nil] 
      primaryKey:@"userId" 
      where:nil 
      whereIn:nil];
```
#####2.Table without primary key
```Objective-C
//1
[YHDB save:[NSArray arrayWithObjects:obj0, ..., nil] 
      primaryKey:nil 
      where:@{@(userId) : @(0), ...} 
      whereIn:nil];
//2
[YHDB save:[NSArray arrayWithObjects:obj0, ..., nil] 
      primaryKey:nil 
      where:nil 
      whereIn:@{@(userId) : @[@(0), @(1), ...]}];
```
##Insert
```Objective-C
[YHDB insert:obj0];
```
##Delete
```Objective-C
//1
[YHDB delete:[[User alloc] init] 
      where:nil 
      whereIn:nil]; //delete all
//2
[YHDB delete:[[User alloc] init] 
      where:@{@(userId) : @(0)} 
      whereIn:nil];//delete one
//3
[YHDB delete:[[User alloc] init] 
      where:nil 
      whereIn:@{@(userId) : @[@(0), @(1), ...]}];//delete some
```
##Update
```Objective-C
[YHDB update:obj0 
      tbModel:nil 
      whereArray:@[@"userId"]];
```
##Select
```Objective-C
/**choose what you need:
 *where     @{key : obj}
 *whereIn   @{key : arrayWithObjects} 
 *orderBy   @{@"ASC" : arrayWithObjects} | @{@"DESC" : arrayWithObjects}
 *groupBy   @{@"GROUP BY" : arrayWithObjects}
 *limit     @{@(start) : @(count)}
 */
[YHDB select:[[User alloc] init] 
      where:nil 
      whereIn:nil 
      orderBy:nil 
      groupBy:nil 
      limit:nil];
```

