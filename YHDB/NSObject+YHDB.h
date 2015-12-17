//
//  NSObject+YHDB.h
//  TaskMgr2
//
//  Created by 一鸿温 on 15/12/1.
//  Copyright © 2015年 szl. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "YHDB.h"

@interface NSObject (YHDB) <YHDBProperty>

/** 每个用户一个数据库时用，退出登录，被登出或者切换账号时把单例设为nil(建议在登录页的viewdidload中调用)
 *
 */
+ (void)resetDB;

/** 执行更新sql语句，可传:1.sql语句 2.sql语句数组
 *
 */
+ (void)executeUpdateWithSql:(id)obj;

/** 执行查询sql语句，传:sql语句,返回字典数组
 *
 */
+ (NSArray *)executeQueryWithSql:(NSString *)sql;

/** 将当前实体的值保存进数据库(自动判断更新或者插入)
 *
 */
- (void)save;

/** 将当前实体的值插入数据库
 *
 */
- (void)insert;

/** 将当前实体的值更新进数据库
 *
 */
- (void)update;

/** 保存多个实体对象时用,开启异步线程,开启事务,快到飞起(自动判断更新或者插入)。
 *  实测1ms 2~3条sql
 */
+ (void)save:(id)obj;

/** 插入多个实体对象,开启异步线程，开启事务，快到飞起,可传:1.sql语句 2.sql语句数组 3.实体对象数组
 *  实测1ms 4~6条sql
 */
+ (void)insert:(id)obj;

/** 更新多个实体对象,开启异步线程，开启事务，快到飞起,可传:1.sql语句 2.sql语句数组 3.实体对象数组
 *  实测1ms 4~6条sql
 */
+ (void)update:(id)obj;

/** 通过主键的值创建实体
 *
 */
- (id)initWithPK:(id)value;

/** 通过sql语句查询出实体数组
 *
 */
+ (NSArray *)selectModelsWithSql:(NSString *)sql;

////拼接

/** WHERE 语句,可传:1.@"属性名 = 属性值" 2.NSDictionary @{属性名 : 属性值}
 *
 */
+ (id)where:(id)obj;

/** WHERE IN 语句,可传:1.@"属性名 IN (属性值)" 2.NSDictionary @{属性名 : @[属性值]}
 *
 */
+ (id)whereIn:(id)obj;

/** SELECT 语句,obj 可传:1.@"属性名" 2.NSArray @[属性名]; model 传:self
 *
 */
+ (id)select:(id)obj;

/** GROUP BY 语句,obj 可传:1.@"属性名" 2.NSArray @[属性名]
 *  在 SELECT 语句中，GROUP BY 子句放在 WHERE 子句之后，放在 ORDER BY 子句之前。
 */
+ (id)groupBy:(id)obj;

/** ORDER BY 语句,obj 可传:@"属性名 ASC或者DESC" 2.NSDictionary @{@"ASC" : @[属性名]} 或 @{@"DESC" : @[属性名]}
 *
 */
+ (id)orderBy:(id)obj;

/** LIMIT 语句,传:start, size
 *
 */
+ (id)limit:(NSUInteger)start, ...;

/** 执行查询
 *
 */
+ (NSArray *)executeQuery;

/** 查询行数
 *
 */
+ (id)selectCount;

/** 执行查询行数
 *
 */
+ (NSInteger)executeQueryCount;

/** DELETE 语句, 传:self
 *
 */
+ (id)deleteSelf;

/** 执行删除
 *
 */
+ (void)executeDelete;

////其他

/** 创建索引,column可传:1.@"属性名" 2.@[属性名]; (索引名:INDEX_TABLENAME_column_...)是否要创建一个单列索引还是组合索引，要考虑到您在作为查询过滤条件的 WHERE 子句中使用非常频繁的列。
 如果值使用到一个列，则选择使用单列索引。如果在作为过滤的 WHERE 子句中有两个或多个列经常使用，则选择使用组合索引。
 *  索引不应该使用在较小的表上。
 *  索引不应该使用在有频繁的大批量的更新或插入操作的表上。
 *  索引不应该使用在含有大量的 NULL 值的列上。
 *  索引不应该使用在频繁操作的列上。
 */
+ (void)createIndexOnColumn:(id)column;

/** 删除索引,column可传:1.@"属性名" 2.@[属性名],加索引的时候传入多少个属性名，删除的时候就应该传入多少个(索引名:INDEX_TABLENAME_column_...)
 *
 */
+ (void)dropIndexOnColumn:(id)column;

/** 插入列,column可传:1.@"属性名 属性名 ..."(属性名之间用空格隔开) 2.@[属性名]
 *
 */
+ (void)alterTableAddColumn:(id)column;

/** 删除表(慎用)
 *
 */
+ (void)drop;

@end
