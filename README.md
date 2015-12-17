# YHDB
####Package based on fmdb,used to conveniently call database operation.

##Install
#####Download the [YHDB](https://github.com/wyhazq/YHDB/archive/master.zip) &  [fmdb](https://github.com/ccgus/fmdb) 

##import
```Objective-C
#import "NSObject+YHDB.h"
```

##BASE
#####Perform the protocol in Model if you need,example:
```Objective-C
@implementation

- (NSString *)dbName {
    return @"YHDB";
}

//have primaryKey
- (NSString *)primaryKey {
    return @"a";
}

//Perform if you need ensure a row or some rows while primaryKey is AutoIncrement,自增主键时，如果需要唯一确定一行或者几行时用
- (NSArray *)whereKeysForPrimaryKeyAutoIncrement {
    return @[@"c"];
}
@end
```

##Save
#####Automatic matching for insert or update
#####1.a model
```Objective-C
Model *model = [[Model alloc] init];
model.a = 1;
model.b = @"a"
model.c = 1.1;

[model save];//save data to database
```
#####2.a lot of models
```Objective-C
Model *model0 = [[Model alloc] init];
model0.a = 1;
model0.b = @"a"
model0.c = 1.1;

Model *model1 = [[Model alloc] init];
model1.a = 2;
model1.b = @"b"
model1.c = 2.2;

[Model save:@[model0, model1]];//save data to database
```
##Insert
```Objective-C
[model insert];
[Model insert:@[model0, model1]];
[Model insert:@"sql"];
[Model insert:@[sql0,sql1,...];
```
##Delete
```Objective-C
//1.delete from Model;
[[Model deleteSelf] executeDelete];

//2.delete from Model where a = 1
[[[Model deleteSelf] where:@"a = 1"] executeDelete];
[[[Model deleteSelf] where:@{@"a" : @(1)}] executeDelete];

//3.delete from Model where a in (1,2,3)
[[[Model deleteSelf] whereIn:@"a in (1,2,3)"] executeDelete];
[[[Model deleteSelf] whereIn:@{@"a" : @[@(1), @(2), @(3)]}] executeDelete];
```
##Update
```Objective-C
[model update];
[Model update:@[model0, model1]];
[Model update:@"sql"];
[Model update:@[sql0,sql1,...];
```
##Select
```Objective-C
//1.select one row to model
Model *model = [[Model alloc] initWithPK:@(1)];

//2.select a lot row to model
NSArray *array = [Model selectModelsWithSql:@"select * from Model"];
NSArray *array = [[Model select:@"*"] executeQuery];
//and...
/**choose what you need:
 *where:     @{key : obj} || @"key = obj" [... where:@{@"a" : @(1)}]; [... where:@"a = 1"];
 *whereIn:   @{key : @[obj]} || @"key in (obj)" [... whereIn:@"a in (1,2,3)"]; [... whereIn:@{@"a" : @[@(1), @(2), @(3)]}];
 *groupBy:   @[key] || @"key" [... groupBy:@"a"]; [... groupBy:@[a]];
 *having:    @"string" [... having:@"a > 1"];
 *orderBy:   @{@"ASC" : @[key]}, @{@"DESC" : @[key]} || @"key ASC", @"key DESC" [... orderBy:@"a ASC"]; [... orderBy:@{@"ASC" : @[@"a"]];
 *limit:     0, size [... limit:0, 10];
 */
 
 //3.select count
 NSInteger count = [[Model selectCount] executeQueryCount];
```

##executeUpdate
```Objective-C
[Model executeUpdateWithSql:@"sql"];
```

##executeQuery
```Objective-C
NSArray *array = [Model executeQueryWithSql:@"sql"];
```

##Other
##### resetDB
```Objective-C
[Model resetDB];
```

##### create Index
```Objective-C
[Model createIndexOnColumn:@"a"];
```
##### drop Index
```Objective-C
[Model dropIndexOnColumn:@"a"];
```

##### alter Column
```Objective-C
@interface Model
//add a property
@property (nonatomic, strong)NSString *d;
@end

[Model alterTableAddColumn:@"d"];
```

##### drop table
```Objective-C
[Model drop];
```
