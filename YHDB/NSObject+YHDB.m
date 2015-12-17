//
//  NSObject+YHDB.m
//  TaskMgr2
//
//  Created by 一鸿温 on 15/12/1.
//  Copyright © 2015年 szl. All rights reserved.
//

#import "NSObject+YHDB.h"
#include <stdarg.h>

@implementation NSObject (YHDB)

+ (void)resetDB {
    [YHDB resetDB];
}

+ (void)executeUpdateWithSql:(id)obj {
    [YHDB executeUpdateWithSql:obj];
}

+ (NSArray *)executeQueryWithSql:(NSString *)sql {
    return [YHDB executeQueryWithSql:sql];
}

- (void)save {
    [YHDB save:self];
}

- (void)insert {
    [YHDB insert:self];
}

- (void)update {
    [YHDB update:self];
}

+ (void)save:(id)obj {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [YHDB save:obj];
    });
}

+ (void)insert:(id)obj {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [YHDB insert:obj];
    });
}

+ (void)update:(id)obj {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [YHDB update:obj];
    });
}

- (id)initWithPK:(id)value {
    self = [self init];
    if (self) {
        self = [YHDB selectModelFrom:self wherePrimaryKeyEqualTo:value];
    }
    return self;
}

+ (NSArray *)selectModelsWithSql:(NSString *)sql {
    id model = [[self alloc] init];
    return [YHDB selectModelsFrom:model sql:sql];
}

+ (id)where:(id)obj {
    return [YHDB where:obj];
}

+ (id)whereIn:(id)obj {
    return [YHDB whereIn:obj];
}

+ (id)select:(id)obj {
    id model = [[self alloc] init];
    return [YHDB select:obj from:model];
}

+ (id)groupBy:(id)obj {
    return [YHDB groupBy:obj];
}

+ (id)orderBy:(id)obj {
    return [YHDB orderBy:obj];
}

+ (id)limit:(NSUInteger)start, ... {
    va_list args;
    va_start(args, start);
    NSUInteger size = va_arg(args, NSUInteger);
    va_end(args);
    size = size > 0 ? size : NSUIntegerMax;
    return [YHDB limit:start size:size];
}

+ (NSArray *)executeQuery {
    return [YHDB executeQuery];
}

+ (id)selectCount {
    id model = [[self alloc] init];
    return [YHDB selectCountFrom:model];
}

+ (NSInteger)executeQueryCount {
    return [YHDB executeQueryCount];
}

+ (id)deleteSelf {
    id model = [[self alloc] init];
    return [YHDB deleteFrom:model];
}

+ (void)executeDelete {
    [YHDB executeDelete];
}

+ (void)createIndexOnColumn:(id)column {
    id model = [[self alloc] init];
    [YHDB createIndexOnTable:model column:column];
}

+ (void)dropIndexOnColumn:(id)column {
    id model = [[self alloc] init];
    [YHDB dropIndexOnTable:model column:column];
}

+ (void)alterTableAddColumn:(id)column {
    id model = [[self alloc] init];
    [YHDB alterTable:model addColumn:column];
}

+ (void)drop {
    id model = [[self alloc] init];
    [YHDB dropTable:model];
}

@end
