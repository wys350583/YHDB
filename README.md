# YHDB
Package based on fmdb,used to conveniently call database operation.

##Install
Download the [YHDB](https://github.com/wyhazq/YHDB/archive/master.zip) &  [fmdb](https://github.com/ccgus/fmdb) 

##Create Database
1.Create a database for all users.
```Objective-C
[YHDB createDB:@"CB"];
```
2.Create databases for every user.
```Objective-C
[YHDB createDB:obj0.userId];
```

##Create Table
1.Table with primary key
```Objective-C
//a
[YHDB createTB:[[User alloc] init] primaryKey:@"userId"];
//or b
[YHDB share].createTB([[User alloc] init]).primaryKey(@"userId").executeUpdate();
```
2.Table without primary key
```Objective-C
//a
[YHDB createTB:[[User alloc] init] primaryKey:nil];
//or b
[YHDB share].createTB([[User alloc] init]).executeUpdate();
```

##Save
    Automatic matching for insert or update
    1.Table with primary key
```Objective-C
//a
[YHDB updateOrInsert:[NSArray arrayWithObjects:obj0, ..., nil] primaryKey:@"userId" where:nil whereIn:nil];
//or b
[YHDB share].save([NSArray arrayWithObjects:obj0, ..., nil]).primaryKey(@"userId").executeUpdate();
```
2.Table without primary key
```Objective-C
//a
[YHDB updateOrInsert:[NSArray arrayWithObjects:obj0, ..., nil] primaryKey:nil where:[NSDictionary dictionaryWithObjectsAndKeys:@(0), @(userId), ..., nil] whereIn:nil];
[YHDB updateOrInsert:[NSArray arrayWithObjects:obj0, ..., nil] primaryKey:nil where:nil whereIn:[NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:@(0), ..., nil] forKey:@(userId)]];
//or b
[YHDB share].save([NSArray arrayWithObjects:obj0, ..., nil]).where([NSDictionary dictionaryWithObjectsAndKeys:@(0), @(userId), ..., nil]).executeUpdate();
[YHDB share].save([NSArray arrayWithObjects:obj0, ..., nil]).whereIn([NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:@(0), ..., nil] forKey:@(userId)]).executeUpdate();
```
##Insert
```Objective-C
//a
[YHDB insert:obj0];
//or b
[YHDB share].insert(obj0).executeUpdate();
```
##Delete
```Objective-C
//a
[YHDB delete:[[User alloc] init] where:nil whereIn:nil]; //delete all
[YHDB delete:[[User alloc] init] where:[NSDictionary dictionaryWithObject:obj0.userId forKey:@"userId"] whereIn:nil];//delete one
[YHDB delete:[[User alloc] init] where:nil whereIn:[NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:obj0.userId, ..., nil]];//delete some
//or b
[YHDB share].delete_().from([[User alloc] init]).executeUpdate();//delete all
[YHDB share].delete_().from([[User alloc] init]).where([NSDictionary dictionaryWithObject:obj0.userId forKey:@"userId"]).executeUpdate();//delete one
[YHDB share].delete_().from([[User alloc] init]).whereIn([NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:obj0.userId, ..., nil].executeUpdate();//delete some
```
##Update
```Objective-C
//a
[YHDB update:obj0 tbModel:nil whereArray:[NSArray arrayWithObjects:@"userId", ..., nil]];
//or b
[YHDB share].update(obj0).where([NSDictionary dictionaryWithObject:obj0.userId forKey:@"userId"]).executeUpdate();
[YHDB share].update(obj0).whereIn([NSDictionary dictionaryWithObject:[NSArray arrayWithObjects:obj0.userId, ..., nil] forKey:@"userId"]).executeUpdate();
```
##Select
```Objective-C
//a
[YHDB select:[[User alloc] init] where:nil whereIn:nil orderBy:nil groupBy:nil limit:nil];
//or b
[YHDB share].select(@"*").from([[User alloc] init]).executeQuery();
//choose what you need:.where() | .whereIn() | .orderBy() | .groupBy() | .limit()
//where     @{key : obj}
//whereIn   @{key : arrayWithObjects} 
//orderBy   @{@"ASC" : arrayWithObjects} | @{@"DESC" : arrayWithObjects}
//groupBy   @{@"GROUP BY" : arrayWithObjects}
//limit     @{@(start) : @(count)}
```

