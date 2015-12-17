//
//  YHDB.m
//
//  Created by wenyihong on 15/6/4.
//  Copyright (c) 2015年 yh. All rights reserved.
//

#import "YHDB.h"
#import <objc/runtime.h>

// Log 开关
#if DEBUG
#define yhLOG(...) NSLog(@"\n---------- LOG ----------\n%@\n-------------------------\n",__VA_ARGS__);
#else
#define yhLOG(...);
#endif

#define yhweak(o) autoreleasepool{} __weak typeof(o) o##Weak = o;
#define yhstrong(o) autoreleasepool{} __strong typeof(o) o = o##Weak;

typedef NS_ENUM(NSInteger, ExecuteUpdateType) {
    ExecuteUpdateTypeDefault = 0,
    ExecuteUpdateTypeCreateTable,
    ExecuteUpdateTypeDropTable,
    ExecuteUpdateTypeInsert,
    ExecuteUpdateTypeDelete,
    ExecuteUpdateTypeUpdate,
    ExecuteUpdateTypeCreateIndex,
    ExecuteUpdateTypeDropIndex,
    ExecuteUpdateTypeAlterTableAddColumn,
};

@interface YHDB()

@property (nonatomic, strong)id model;
@property (nonatomic, strong)NSString *select;
@property (nonatomic, strong)NSString *from;
@property (nonatomic, strong)NSString *where;
@property (nonatomic, strong)NSString *whereIn;
@property (nonatomic, strong)NSString *groupBy;
@property (nonatomic, strong)NSString *orderBy;
@property (nonatomic, strong)NSString *limit;
@property (nonatomic, strong)NSString *delete;

@end

@implementation YHDB

static YHDB *yhDB = nil;

# pragma mark --------------------public method--------------------

# pragma mark --protocol

+ (NSString *)dbName {
    return @"YHDB";
}

+ (NSString *)primaryKey {
    return @"yhId";
}

+ (NSArray *)whereKeysForPrimaryKeyAutoIncrement {
    return nil;
}

# pragma mark --database

+ (YHDB *)share {
    @synchronized(self) {
        if (!yhDB) {
            NSString *DBPath = [[self _documentPath] stringByAppendingPathComponent:[[NSUserDefaults standardUserDefaults] objectForKey:@"YHDBPATH"]];
            yhDB = [[YHDB alloc] initWithPath:DBPath];
            NSString *log = [NSString stringWithFormat:@"[YHDB Path]\n%@", yhDB.path ? yhDB.path : @"数据库不存在"];
            yhLOG(log);
        }
        return yhDB;
    }
}

+ (void)resetDB {
    if (yhDB) {
        yhDB = nil;
        yhLOG(@"[YHDB have reset]");
    }
}

# pragma mark --execute

+ (void)executeUpdateWithSql:(id)obj {
    [self _executeUpdateWithSql:obj type:ExecuteUpdateTypeDefault];
}

+ (NSArray *)executeQueryWithSql:(NSString *)sql {
    __block NSMutableArray *dictMArray = [NSMutableArray array];
    [[self share] inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql];
        if (!rs) {
            NSString *log = [NSString stringWithFormat:@"[YHDB SelectFailed]\n%@", rs.query];
            yhLOG(log);
        }
        while ([rs next]) {
            [dictMArray addObject:[rs resultDictionary]];
        }
        [rs close];
    }];
    return dictMArray;
}

# pragma mark --save

+ (void)save:(id)model {
    if ([model isKindOfClass:[NSArray class]]) {
        [self _saveModels:model];
    }
    else {
        [self _createTB:model];
        //有唯一主键
        if ([model respondsToSelector:@selector(primaryKey)]) {
            id dbModel = [self _isExistDataInTable:model];
            if (dbModel) {
                [self _update:model compareWith:dbModel];
            }
            else {
                [self insert:model];
            }
        }
        else {
            [self _deleteSelfFrom:model];
            [self insert:model];
        }
    }
}

# pragma mark --insert
+ (void)insert:(id)obj {
    id sql;
    if ([obj isKindOfClass:[NSString class]]) {//sql
        sql = obj;
    }
    else if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *array = obj;
        if ([[array lastObject] isKindOfClass:[NSString class]]) {//sqls
            sql = array;
        }
        else {//models
            NSMutableArray *mArray = [NSMutableArray array];
            [obj enumerateObjectsUsingBlock:^(id  _Nonnull obj0, NSUInteger idx0, BOOL * _Nonnull stop0) {
                [mArray addObject:[self _sql_insert:obj0]];
            }];
            sql = mArray;
        }
    }
    else {//model
        sql = [self _sql_insert:obj];
    }
    [self _insertWithSql:sql];
}

# pragma mark --update
+ (void)update:(id)obj {
    id sql;
    if ([obj isKindOfClass:[NSString class]]) {//sql
        sql = obj;
    }
    else if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *array = obj;
        if ([[array lastObject] isKindOfClass:[NSString class]]) {//sqls
            sql = array;
        }
        else {//models
            NSMutableArray *mArray = [NSMutableArray array];
            [obj enumerateObjectsUsingBlock:^(id  _Nonnull obj0, NSUInteger idx0, BOOL * _Nonnull stop0) {
                [mArray addObject:[self _sql_update:obj0]];
            }];
            sql = mArray;
        }
    }
    else {
        sql = [self _sql_update:obj];
    }
    if (sql) {
        [self _updateWithSql:sql];
    }
}

# pragma mark --select

+ (id)selectModelFrom:(id)model wherePrimaryKeyEqualTo:(id)value {
    NSString *sql = [self _sql_select:@[@"*"] from:model wherePrimaryKeyEqualTo:value];
    NSArray *dbModels = [self selectModelsFrom:model sql:sql];
    return dbModels.count > 0 ? dbModels[0] : nil;
}

+ (NSArray *)selectModelsFrom:(id)model sql:(NSString *)sql {
    __block NSMutableArray *dbModels = [NSMutableArray array];
    __block id dbModel;
    [[self share] inDatabase:^(FMDatabase *db) {
        FMResultSet *rs = [db executeQuery:sql];
        if (!rs) {
            NSString *log = [NSString stringWithFormat:@"[YHDB SelectFailed]\n%@", rs.query];
            yhLOG(log);
        }
        while ([rs next]) {
            dbModel = [[[model class] alloc] init];
            [rs kvcMagic:dbModel];
            [dbModels addObject:dbModel];
        }
        [rs close];
    }];
    return dbModels;
}

# pragma mark --splice

+ (id)where:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        [self share].where = [@"WHERE " stringByAppendingString:obj];
    }
    else if ([obj isKindOfClass:[NSDictionary class]]) {
        [self share].where = [self _sql_from:[self share].model where:obj];
    }
    else {
        [self share].where = @"";
    }
    return self;
}

+ (id)whereIn:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        [self share].whereIn = [@"WHERE " stringByAppendingString:obj];
    }
    else if ([obj isKindOfClass:[NSDictionary class]]) {
        [self share].whereIn = [self _sql_from:[self share].model whereIn:obj];
    }
    else {
        [self share].whereIn = @"";
    }
    return self;
}

+ (id)select:(id)obj from:(id)model {
    if ([obj isKindOfClass:[NSString class]]) {
        [self share].select = [@"SELECT " stringByAppendingString:obj];
    }
    else if ([obj isKindOfClass:[NSArray class]]) {
        [self share].select = [@"SELECT " stringByAppendingString:[obj componentsJoinedByString:@", "]];
    }
    else {
        [self share].select = @"SELECT *";
    }
    [self share].from = [@" FROM " stringByAppendingString:[self _tableName:model]];
    [self share].model = model;
    return self;
}

+ (id)groupBy:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        [self share].groupBy = [@"GROUP BY " stringByAppendingString:obj];
    }
    else if ([obj isKindOfClass:[NSArray class]]) {
        NSArray *array = obj;
        if (array && array.count == 1) {
            [self share].groupBy = [NSString stringWithFormat:@"GROUP BY  %@", [array componentsJoinedByString:@","]];
        }
    }
    else {
        [self share].groupBy = @"";
    }
    return self;
}

+ (id)orderBy:(id)obj {
    if ([obj isKindOfClass:[NSString class]]) {
        [self share].orderBy = [@"ORDER BY " stringByAppendingString:obj];
    }
    else if ([obj isKindOfClass:[NSDictionary class]]) {
        //ORDER BY字典:ORDER BY ? ASC||DESC
        NSDictionary *dict = obj;
        if (dict && dict.count == 1) {
            [self share].orderBy = [NSString stringWithFormat:@"ORDER BY %@ %@", [dict.allValues[0]  componentsJoinedByString:@","], dict.allKeys[0]];
        }
    }
    else {
        [self share].orderBy = @"";
    }
    return self;
}

+ (id)limit:(NSUInteger)start size:(NSUInteger)size {
    [self share].limit = [NSString stringWithFormat:@"LIMIT %ld, %ld", (long)start, (long)size];
    return self;
}


+ (NSArray *)executeQuery {
    //'*' 替换成列名，加快查询速度。
    if ([[self share].select containsString:@"*"]) {
        NSDictionary *kTDict = [self _tableDict:[self share].model];
        [self share].select = [[self share].select stringByReplacingOccurrencesOfString:@"*" withString:[kTDict.allKeys componentsJoinedByString:@", "]];
    }
    NSString *sql = [NSString stringWithFormat:@"%@ %@ %@ %@ %@ %@ %@",[self _toString:[self share].select], [self _toString:[self share].from], [self _toString:[self share].where], [self _toString:[self share].whereIn], [self _toString:[self share].groupBy], [self _toString:[self share].orderBy], [self _toString:[self share].limit]];
    [self resetProperty];
    return [self selectModelsFrom:[self share].model sql:sql];
}

+ (id)selectCountFrom:(id)model {
    [self share].select = @"SELECT COUNT(1) AS COUNT";
    [self share].from = [@" FROM " stringByAppendingString:[self _tableName:model]];
    [self share].model = model;
    return self;
}

+ (NSInteger)executeQueryCount {
    NSString *sql = [NSString stringWithFormat:@"%@ %@ %@ %@",[self _toString:[self share].select], [self _toString:[self share].from], [self _toString:[self share].where], [self _toString:[self share].whereIn]];
    __block NSInteger count;
    [[YHDB share] inDatabase:^(FMDatabase *db){
        FMResultSet *rs = [db executeQuery:sql];
        if (!rs) {
            NSString *log = [NSString stringWithFormat:@"[YHDB SelectFailed]\n%@", rs.query];
            yhLOG(log);
        }
        while ([rs next]) {
            count = [rs intForColumn:@"COUNT"];
        }
        [rs close];
    }];
    [self resetProperty];
    return count;
}

+ (id)deleteFrom:(id)model {
    [self share].model = model;
    [self share].delete = [@"DELETE FROM " stringByAppendingString:[self _tableName:model]];
    return self;
}

+ (void)executeDelete {
    NSString *sql = [NSString stringWithFormat:@"%@ %@ %@",[self share].delete, [self _toString:[self share].where], [self _toString:[self share].whereIn]];
    [self resetProperty];
    [self _deleteWithSql:sql];
}

# pragma mark --createIndex
+ (void)createIndexOnTable:(id)model column:(id)column {
    if (column) {
        [self _createIndexWithSql:[self _sql_createIndexOnTable:model column:column]];
    }
}

# pragma mark --drop

+ (void)dropIndexOnTable:(id)model column:(id)column {
    if (column) {
        [self _dropIndexWithSql:[self _sql_dropIndexOnTable:model column:column]];
    }
}

+ (void)dropTable:(id)model {
    [self _dropTableWithSql:[self _sql_dropTable:model]];
}

# pragma mark --alter

+ (void)alterTable:(id)model addColumn:(id)column {
    [self _alterTableAddColumnWithSql:[self _sql_alterTable:model addColumn:column]];
}

# pragma mark --------------------private method--------------------

# pragma mark --exist
+ (BOOL)_isExistDBInSandbox {
    if ([self share]) {
        return YES;
    }
    return NO;
}

+ (BOOL)_isExistTableInDB:(id)model {
    NSDictionary *tableDict = [[[NSUserDefaults standardUserDefaults] objectForKey:[self _tableName:model]] copy];
    if (tableDict) {
        return YES;
    }
    return NO;
}

//model中已有主键的值的查询
+ (id)_isExistDataInTable:(id)model {
    id value = [model valueForKey:[model primaryKey]];
    id dbModel = [self selectModelFrom:model wherePrimaryKeyEqualTo:value];
    return dbModel;
}

# pragma mark --base

+ (void)_executeUpdateWithSql:(id)obj type:(ExecuteUpdateType)type {
    if ([obj isKindOfClass:[NSString class]]) {
        [self _executeUpdateWithOneSql:obj type:type];
    }
    else if ([obj isKindOfClass:[NSArray class]]){
        [self _executeUpdateWithSqls:obj type:type];
    }
}

+ (void)_executeUpdateWithOneSql:(NSString *)sql type:(ExecuteUpdateType)type{
    [[YHDB share] inDatabase:^(FMDatabase *db) {
        NSString *executeUpdateSucceedString = [self _configSuccessLogWithType:type];
        NSString *log = [db executeUpdate:sql] ? executeUpdateSucceedString : [db lastErrorMessage];
        yhLOG(log);
    }];
}

+ (void)_executeUpdateWithSqls:(NSArray *)sqls type:(ExecuteUpdateType)type {
    [[YHDB share] inTransaction:^(FMDatabase *db, BOOL *rollback) {
        [sqls enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *executeUpdateSucceedString = [self _configSuccessLogWithType:type];
            NSString *log = [db executeUpdate:obj] ? executeUpdateSucceedString : [db lastErrorMessage];
            yhLOG(log);
        }];
    }];
}

# pragma mark --create
+ (void)_createTB:(id)model {
    [self _createDB:model];
    if (![self _isExistTableInDB:model]) {
        NSString *sql = [self _sql_createTable:model];
        [self _createTBWithSql:sql];
    }
}

+ (void)_createTBWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeCreateTable];
}

+ (void)_createDB:(id)model {
    if (!self._isExistDBInSandbox) {
        NSString *dbName = [model respondsToSelector:@selector(dbName)] ? [model dbName] : [self dbName];
        if ([self _createFinderInDocumentWithName:dbName]) {
            NSString *dBPath = [dbName stringByAppendingPathComponent:[dbName stringByAppendingString:@".db"]];
            [self _userDefaultsSetObject:dBPath forKey:@"YHDBPATH"];
        }
        [YHDB share];
    }
}

+ (void)_createIndexWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeCreateIndex];
}

+ (void)_alterTableAddColumnWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeAlterTableAddColumn];
}

# pragma mark --drop

+ (void)_dropTableWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeDropTable];
}

+ (void)_dropIndexWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeDropIndex];
}

# pragma mark --save

+ (void)_saveModels:(NSArray *)models {
    if (models.count > 0) {
        if (models.count == 1) {//数组只有一个数据，走单个储存流程
            [self save:[models lastObject]];
        }
        else {
            id model = [models lastObject];
            [self _createTB:model];
            if ([model respondsToSelector:@selector(primaryKey)]) {//有主键
                NSString *primaryKey = [model primaryKey];
                NSArray *updataModels = [[[self select:@"*" from:model] whereIn:[self _getPrimaryKeys:models]] executeQuery];
                if (updataModels.count > 0) {//有更新
                    NSDictionary *kTDic = [self _tableDict:model];
                    NSMutableArray *updateSqls = [NSMutableArray array];
                    NSMutableArray *insertSqls = [NSMutableArray array];
                    __block BOOL haveUpdate;
                    [models enumerateObjectsUsingBlock:^(id obj0, NSUInteger idx0, BOOL *stop0) {
                        haveUpdate = NO;
                        [updataModels enumerateObjectsUsingBlock:^(id obj1, NSUInteger idx1, BOOL *stop1) {
                            if ([kTDic[primaryKey] isEqualToString:@"integer"] || [kTDic[primaryKey] isEqualToString:@"real"]) {
                                if ([obj0 valueForKey:primaryKey] == [obj1 valueForKey:primaryKey]) {
                                    haveUpdate = YES;
                                }
                            }
                            if ([kTDic[primaryKey] isEqualToString:@"text"]) {
                                if ([[obj0 valueForKey:primaryKey] isEqualToString:[obj1 valueForKey:primaryKey]]) {
                                    haveUpdate = YES;
                                }
                            }
                            if (haveUpdate) {
                                NSString *updateSql = [self _sql_update:obj0 compareWith:obj1];
                                if (updateSql) {
                                    [updateSqls addObject:updateSql];
                                }
                                *stop1 = YES;
                            }
                        }];
                        if (!haveUpdate) {
                            [insertSqls addObject:[self _sql_insert:obj0]];
                        }
                    }];
                    [self _insertWithSql:insertSqls];
                    [self _updateWithSql:updateSqls];
                }
                else {//全部都是插入
                    NSMutableArray *insertSqls = [NSMutableArray array];
                    @yhweak(self);
                    [models enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        @yhstrong(self);
                        [insertSqls addObject:[self _sql_insert:obj]];
                    }];
                    [self _insertWithSql:insertSqls];
                }
            }
            else {//无主键:先删后插
                //取出所有实体的能确定某一行的keys和values
                NSArray *whereKeys = [model respondsToSelector:@selector(whereKeysForPrimaryKeyAutoIncrement)] ? [model whereKeysForPrimaryKeyAutoIncrement] : [self whereKeysForPrimaryKeyAutoIncrement];
                if (whereKeys) {
                    NSMutableDictionary *inDict = [NSMutableDictionary dictionary];
                    [whereKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj0, NSUInteger idx0, BOOL * _Nonnull stop0) {
                        NSMutableArray *inArray = [NSMutableArray array];
                        [models enumerateObjectsUsingBlock:^(id  _Nonnull obj1, NSUInteger idx1, BOOL * _Nonnull stop1) {
                            id value = [obj1 valueForKey:obj0];
                            [inArray addObject:value];
                        }];
                        [inDict setObject:inArray forKey:obj0];
                    }];
                    [[[self deleteFrom:model] whereIn:inDict] executeDelete];
                }
                NSMutableArray *insertSqls = [NSMutableArray array];
                @yhweak(self);
                [models enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    @yhstrong(self);
                    [insertSqls addObject:[self _sql_insert:obj]];
                }];
                [self _insertWithSql:insertSqls];
            }
        }
        
    }
}

# pragma mark --insert
+ (void)_insertWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeInsert];
}

# pragma mark --delete

+ (void)_deleteSelfFrom:(id)model {
    NSString *whereString = [self _sql_deleteWhere_from:model];
    [self _deleteFrom:model where:whereString];
}

+ (void)_deleteFrom:(id)model where:(NSString *)whereString {
    NSString *sql= [NSString stringWithFormat:@"DELETE FROM %@ %@", [self _tableName:model], whereString];
    [self _deleteWithSql:sql];
}

+ (void)_deleteWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeDelete];
}

# pragma mark --update
+ (void)_updateWithSql:(id)sql {
    [self _executeUpdateWithSql:sql type:ExecuteUpdateTypeUpdate];
}

+ (void)_update:(id)model compareWith:(id)dbModel {
    NSString *sql = [self _sql_update:model compareWith:dbModel];
    if (sql) {
        [self _updateWithSql:sql];
    }
}

# pragma mark --sqls
+ (NSString *)_sql_createTable:(id)model {
    NSDictionary *kTDict = [self _tableDict:model];
    __block NSMutableString *mString = [NSMutableString string];
    NSString *primaryKey = [model respondsToSelector:@selector(primaryKey)] ? [model primaryKey] : [self primaryKey];
    
    if (![kTDict.allKeys containsObject:primaryKey]) {
        mString = [self _mergeSuperString:mString subString:[NSString stringWithFormat:@"%@ integer PRIMARY KEY AUTOINCREMENT", self.primaryKey] withString:@","];
    }
    @yhweak(self);
    [kTDict enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
        @yhstrong(self);
        NSString *subString;
        if ([key isEqualToString:primaryKey]) {
            subString = [NSString stringWithFormat:@"%@ %@ PRIMARY KEY", key, obj];
        }
        else {
            subString = [NSString stringWithFormat:@"%@ %@", key, obj];
        }
        mString = [self _mergeSuperString:mString subString:subString withString:@","];
    }];
    NSString *sql = [NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ (%@)", [self _tableName:model], mString];
    return sql;
}

+ (id)_sql_alterTable:(id)model addColumn:(id)column {
    NSString *tableName = [self _tableName:model];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:tableName];//删除记录在UserDefault中的原有表数据
    NSDictionary *kTDict = [self _tableDict:model];
    NSArray *columnArray;
    if ([column isKindOfClass:[NSString class]]) {
        columnArray = [column componentsSeparatedByString:@" "];
    }
    if ([column isKindOfClass:[NSArray class]]) {
        columnArray = column;
    }
    NSMutableArray *sqls = [NSMutableArray array];
    [columnArray enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [sqls addObject:[NSString stringWithFormat:@"ALTER TABLE %@ ADD COLUMN %@ %@", tableName, obj, kTDict[obj]]];
    }];
    return sqls;
}

+ (NSString *)_sql_dropTable:(id)model {
    return [NSString stringWithFormat:@"DROP TABLE %@", [self _tableName:model]];
}

+ (NSString *)_sql_createIndexOnTable:(id)model column:(id)column {
    NSString *columnName;
    NSString *indexName;
    NSString *tableName = [self _tableName:model];
    if ([column isKindOfClass:[NSString class]]) {
        columnName = [NSString stringWithFormat:@"( %@ )", column];
        indexName = [NSString stringWithFormat:@"INDEX_%@_%@", tableName, column];
    }
    else if ([column isKindOfClass:[NSArray class]]) {
        columnName = [NSString stringWithFormat:@"( %@ )", [column componentsJoinedByString:@", "]];
        indexName = [NSString stringWithFormat:@"INDEX_%@_%@", tableName, [column componentsJoinedByString:@"_"]];
    }
    return [NSString stringWithFormat:@"CREATE INDEX %@ ON %@ %@", indexName, tableName, columnName];
}

+ (NSString *)_sql_dropIndexOnTable:(id)model column:(id)column {
    NSString *indexName;
    NSString *tableName = [self _tableName:model];
    if ([column isKindOfClass:[NSString class]]) {
        indexName = [NSString stringWithFormat:@"INDEX_%@%@", tableName, column];
    }
    else if ([column isKindOfClass:[NSArray class]]) {
        indexName = [NSString stringWithFormat:@"INDEX_%@%@", tableName, [column componentsJoinedByString:@"_"]];
    }
    return [NSString stringWithFormat:@"DROP INDEX %@", indexName];
}

+ (NSString *)_sql_insert:(id)model {
    NSDictionary *kTDict = [self _tableDict:model];
    __block NSMutableString *keyString = [NSMutableString string];
    __block NSMutableString *objString = [NSMutableString string];
    @yhweak(self);
    [kTDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        @yhstrong(self);
        id value = [model valueForKey:key];
        keyString = [self _mergeSuperString:keyString subString:key withString:@","];
        objString = value ? [self _mergeSuperString:objString subString:[self _dbValue:value type:obj] withString:@","] : [self _mergeSuperString:objString subString:@"''" withString:@","];
    }];
    NSMutableString *sql= [NSMutableString stringWithFormat:@"INSERT INTO %@ (%@) VALUES (%@)", [self _tableName:model], keyString, objString];
    return sql;
}

+ (NSString *)_sql_deleteWhere_from:(id)model {
    NSArray *whereKeys = [model respondsToSelector:@selector(whereKeysForPrimaryKeyAutoIncrement)] ? [model whereKeysForPrimaryKeyAutoIncrement] : [self whereKeysForPrimaryKeyAutoIncrement];
    if (whereKeys) {
        NSDictionary *kTDict = [self _tableDict:model];
        __block NSMutableString *whereString = [NSMutableString string];
        @yhweak(self);
        [whereKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            @yhstrong(self);
            NSString *subString = [NSString stringWithFormat:@" %@ = %@ ", obj, [self _dbValue:[model valueForKey:obj] type:kTDict[obj]]];
            whereString = [self _mergeSuperString:whereString subString:subString withString:@"AND"];
        }];
        return [@"WHERE" stringByAppendingString:whereString];
    }
    else {
        return @"";
    }
}

+ (NSString *)_sql_update:(id)model {
    NSDictionary *kTDict = [self _tableDict:model];
    __block NSMutableString *memberString = [NSMutableString string];
    @yhweak(self);
    [kTDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        @yhstrong(self);
        id value = [model valueForKey:key];
        if (value) {
            NSString *subString = [NSString stringWithFormat:@" %@ = %@ ", key, [self _dbValue:[model valueForKey:key] type:obj]];
            memberString = [self _mergeSuperString:memberString subString:subString withString:@", "];
        }
    }];
    return [self _sql_update:model set:memberString];
}

+ (NSString *)_sql_update:(id)model compareWith:(id)dbModel{
    NSDictionary *kTDict = [self _tableDict:model];
    __block NSMutableString *memberString = [NSMutableString string];
    @yhweak(self);
    [kTDict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
        @yhstrong(self);
        id value = [model valueForKey:key];
        id tbValue = [dbModel valueForKey:key];
        if (value) {
            BOOL hasUpdate = NO;
            if ([obj isEqualToString:@"integer"] || [obj isEqualToString:@"real"]) {
                if (![value isEqualToNumber:tbValue]) {
                    hasUpdate = YES;
                }
            }
            else if ([obj isEqualToString:@"text"]) {
                if (![value isEqualToString:tbValue]) {
                    hasUpdate = YES;
                }
            }
            if (hasUpdate) {
                NSString *subString = [NSString stringWithFormat:@"%@ = %@", key, [self _dbValue:[model valueForKey:key] type:obj]];
                memberString = [self _mergeSuperString:memberString subString:subString withString:@", "];
            }
        }
    }];
    return [self _sql_update:model set:memberString];
}

+ (NSString *)_sql_update:(id)model set:(NSString *)memberString {
    NSDictionary *kTDict = [self _tableDict:model];
    if (memberString.length > 0) {
        NSString *whereString = [NSString string];
        if ([model respondsToSelector:@selector(primaryKey)]) {
            NSString *primaryKey = [model primaryKey];
            whereString = [NSString stringWithFormat:@"WHERE %@ = %@ ", primaryKey, [self _dbValue:[model valueForKey:primaryKey] type:kTDict[primaryKey]]];
        }
        else if ([model respondsToSelector:@selector(whereKeysForPrimaryKeyAutoIncrement)]) {
            NSArray *array = [model whereKeysForPrimaryKeyAutoIncrement];
            __block NSMutableString *subString = [NSMutableString string];
            [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                subString = [self _mergeSuperString:subString subString:[NSString stringWithFormat:@" %@ = %@ ", obj, [self _dbValue:[model valueForKey:obj] type:kTDict[obj]]] withString:@"AND"];
            }];
            whereString = [NSString stringWithFormat:@"WHERE %@ ", subString];
        }
        NSString *sql = [NSString stringWithFormat:@"UPDATE %@ SET %@ %@", [self _tableName:model], memberString, whereString];
        return sql;
    }
    return nil;
}

+ (NSString *)_sql_select:(NSArray *)array from:(id)model wherePrimaryKeyEqualTo:(id)value {
    NSString *selectString = [self _sql_select:array from:model];
    NSString *whereString = [self _sql_from:model where:@{[model primaryKey] : value}];
    NSString *sql = [NSString stringWithFormat:@"SELECT %@ FROM %@ %@", selectString, [self _tableName:model], whereString];
    return sql;
}

+ (NSString *)_sql_select:(NSArray *)array from:(id)model {
    __block NSMutableString *mSelectString = [NSMutableString string];
    
    @yhweak(self);
    if ([array containsObject:@"*"]) {
        NSDictionary *kTDict = [self _tableDict:model];
        mSelectString = [[kTDict.allKeys componentsJoinedByString:@", "] mutableCopy];
    }
    else {
        [array enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            @yhstrong(self);
            mSelectString = [self _mergeSuperString:mSelectString subString:obj withString:@","];
        }];
    }
    return mSelectString;
}

+ (NSString *)_sql_from:(id)model where:(NSDictionary *)dict {
    //WHERE字典:WHERE ? = ?
    if (dict) {
        NSDictionary *kTDict = [self _tableDict:model];
        __block NSMutableString *mWhereString = [NSMutableString string];
        @yhweak(self);
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            @yhstrong(self);
            NSString *subString = [NSString stringWithFormat:@" %@ = %@ ", key, [self _dbValue:obj type:kTDict[key]]];
            mWhereString = [self _mergeSuperString:mWhereString subString:subString withString:@"AND"];
        }];
        return [@"WHERE" stringByAppendingString:mWhereString];
    }
    return @"";
}

+ (NSString *)_sql_from:(id)model whereIn:(NSDictionary *)dict {
    //WHERE字典:WHERE ? = ?
    if (dict) {
        NSDictionary *kTDict = [self _tableDict:model];
        __block NSMutableString *mWhereString = [NSMutableString string];
        @yhweak(self);
        [dict enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            @yhstrong(self);
            if ([obj isKindOfClass:[NSArray class]]) {
                __block NSMutableString *inString = [NSMutableString string];
                [obj enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                    @yhstrong(self);
                    NSString *subString = [NSString stringWithFormat:@" %@ ", [self _dbValue:obj type:kTDict[key]]];
                    inString = [self _mergeSuperString:inString subString:subString withString:@","];
                }];
                NSString *subString = [NSString stringWithFormat:@" %@ IN (%@) ", key, inString];
                mWhereString = [self _mergeSuperString:mWhereString subString:subString withString:@"AND"];
            }
        }];
        return [@"WHERE" stringByAppendingString:mWhereString];
    }
    return @"";
}

# pragma mark --tools
+ (BOOL)_createFinderInDocumentWithName:(NSString *)finderName {
    NSString *finderPath = [[self _documentPath] stringByAppendingPathComponent:finderName];
    if (![[NSFileManager defaultManager] fileExistsAtPath:finderPath])
    {
        return [[NSFileManager defaultManager] createDirectoryAtPath:finderPath
                                         withIntermediateDirectories:YES
                                                          attributes:nil
                                                               error:NULL];
    }
    return NO;
}

+ (NSString *)_documentPath {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
}

+ (void)_userDefaultsSetObject:(id)obj forKey:(NSString *)key {
    [[NSUserDefaults standardUserDefaults] setObject:obj forKey:key];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

+ (NSString *)_tableName:(id)model {
    return NSStringFromClass([model class]);
}

+ (NSMutableString *)_mergeSuperString:(NSMutableString *)superString subString:(NSString *)subString withString:(NSString *)withString {
    if (superString.length > 0) {
        [superString appendFormat:@"%@ %@", withString, subString];
    }
    else {
        [superString appendFormat:@"%@", subString];
    }
    return superString;
}

+ (NSDictionary *)_tableDict:(id)model {
    NSString *tableName = [self _tableName:model];
    NSDictionary *tableDict = [[[NSUserDefaults standardUserDefaults] objectForKey:tableName] copy];
    if (tableDict) {
        return tableDict;
    }
    else {
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
                NSString *type = [self _translateToDBType:[NSString stringWithCString:propType
                                                                            encoding:[NSString defaultCStringEncoding]]];
                [propertyName addObject:name];
                [propertyType addObject:type];
                if (type.length == 0) {
                    NSLog(@"YHDB Warning:(Property Type Warning)YHDB have not type of '%s' in property:'%@'",propType, name);
                }
            }
        }
        free(properties);
        NSDictionary *tableDict = [NSDictionary dictionaryWithObjects:propertyType forKeys:propertyName];
        [self _userDefaultsSetObject:tableDict forKey:tableName];
        return tableDict;
    }
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

+ (NSString *)_translateToDBType:(NSString *)modelType {
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

+ (NSString *)_dbValue:(id)value type:(id)type {
    if ([type isEqualToString:@"text"]) {
        return [NSString stringWithFormat:@"'%@'",value];
    }
    if ([type isEqualToString:@"integer"] || [type isEqualToString:@"real"]) {
        return [NSString stringWithFormat:@"%@",value];
    }
    return @"";
}

+ (NSString *)_configSuccessLogWithType:(ExecuteUpdateType)type {
    NSString *successString;
    switch (type) {
        case ExecuteUpdateTypeDefault:
            successString = @"[YHDB ExecuteUpdate_Succeed]";
            break;
            
        case ExecuteUpdateTypeCreateTable:
            successString = @"[YHDB CREATE_Table_Succeed]";
            break;
            
        case ExecuteUpdateTypeDropTable:
            successString = @"[YHDB DROP_Table_Succeed]";
            break;
            
        case ExecuteUpdateTypeInsert:
            successString = @"[YHDB INSERT_Succeed]";
            break;
            
        case ExecuteUpdateTypeDelete:
            successString = @"[YHDB DELETE_Succeed]";
            break;
            
        case ExecuteUpdateTypeUpdate:
            successString = @"[YHDB UPDATE_Succeed]";
            break;
            
        case ExecuteUpdateTypeCreateIndex:
            successString = @"[YHDB CREATE_INDEX_Succeed]";
            break;
            
        case ExecuteUpdateTypeDropIndex:
            successString = @"[YHDB DROP_INDEX_Succeed]";
            break;
            
        case ExecuteUpdateTypeAlterTableAddColumn:
            successString = @"[YHDB ALTERTABLE_ADDCOLUMN_Succeed]";
            break;
            
        default:
            successString = @"[YHDB UN_NO_Succeed]";
            break;
    }
    
    return successString;
}

+ (NSString *)_toString:(NSString *)string {
    return string ? string : @"";
}

+ (NSDictionary *)_getPrimaryKeys:(NSArray *)models {
    NSString *primariKey = [[models lastObject] primaryKey];
    NSMutableArray *array = [NSMutableArray array];
    [models enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [array addObject:[obj valueForKey:primariKey]];
    }];
    return @{primariKey : array};
}

+ (void)resetProperty {
    [self share].select = nil;
    [self share].from = nil;
    [self share].where = nil;
    [self share].whereIn = nil;
    [self share].groupBy = nil;
    [self share].orderBy = nil;
    [self share].limit = nil;
    [self share].delete = nil;
}

@end