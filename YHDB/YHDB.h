//
//  YHDB.h
//
//  Created by wenyihong on 15/6/4.
//  Copyright (c) 2015年 yh. All rights reserved.
//

#import "FMDB.h"

@protocol YHDBProperty <NSObject>
@optional

/** 数据库名字，默认为YHDB.db
 *
 */
- (NSString *)dbName;

/** 数据库主键，默认为yhId, 自增
 *
 */
- (NSString *)primaryKey;

/** 自增主键的情况下能确定某一行的key,用于删除表数据
 *
 */
- (NSArray *)whereKeysForPrimaryKeyAutoIncrement;

@end

@interface YHDB : FMDatabaseQueue

/** 获得单例对象(好像并无卵用)
 *
 */
+ (YHDB *)share;

/** 每个用户一个数据库时用，退出登录，被登出或者切换账号时把单例设为nil(建议在登录页的viewdidload中调用)
 *
 */
+ (void)resetDB;

/** 执行更新sql语句，可传:1.sql语句 2.sql语句数组
 *
 */
+ (void)executeUpdateWithSql:(id)obj;

/** 执行查询sql语句，传:sql语句
 *
 */
+ (NSArray *)executeQueryWithSql:(NSString *)sql;

/** 保存，可传:1.实体对象 2.实体对象数组
 *
 */
+ (void)save:(id)model;

/** 插入操作,可传:1.sql语句 2.sql语句数组 3.实体对象 4.实体对象数组
 *
 */
+ (void)insert:(id)obj;

/** 更新操作,可传:1.sql语句 2.sql语句数组 3.实体对象 4.实体对象数组（3,4非自增主键时用）
 *
 */
+ (void)update:(id)obj;

/** 查询一个实体
 *
 */
+ (id)selectModelFrom:(id)model wherePrimaryKeyEqualTo:(id)value;

/** 查询一个实体数组
 *
 */
+ (NSArray *)selectModelsFrom:(id)model sql:(NSString *)sql;

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
+ (id)select:(id)obj from:(id)model;

/** GROUP BY 语句,obj 可传:1.@"属性名" 2.NSArray @[属性名]
 *
 */
+ (id)groupBy:(id)obj;

/** ORDER BY 语句,obj 可传:@"属性名 ASC或者DESC" 2.NSDictionary @{@"ASC" : @[属性名]} 或 @{@"DESC" : @[属性名]}
 *
 */
+ (id)orderBy:(id)obj;

/** LIMIT 语句,传:start, size
 *
 */
+ (id)limit:(NSUInteger)start size:(NSUInteger)size;

/** 执行查询
 *
 */
+ (NSArray *)executeQuery;

/** 查询行数, 传:self
 *
 */
+ (id)selectCountFrom:(id)model;

/** 执行查询行数
 *
 */
+ (NSInteger)executeQueryCount;

/** DELETE 语句, 传:self
 *
 */
+ (id)deleteFrom:(id)model;

/** 执行删除
 *
 */
+ (void)executeDelete;

////其他

/** 创建索引,model传:self,column可传:1.@"属性名" 2.@[属性名]
 *
 */
+ (void)createIndexOnTable:(id)model column:(id)column;

/** 删除索引,model传:self,column可传:1.@"属性名" 2.@[属性名]
 *
 */
+ (void)dropIndexOnTable:(id)model column:(id)column;

/** 删除表,传:self
 *
 */
+ (void)dropTable:(id)model;

/** 插入列,model传:self,column可传:1.@"属性名 属性名 ..."(属性名之间用空格隔开) 2.@[属性名]
 *
 */
+ (void)alterTable:(id)model addColumn:(id)column;

@end