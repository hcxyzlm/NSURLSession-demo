//
//  NSString+md5.h
//  NSURLSession-demo
//
//  Created by zhuo on 16/7/12.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (md5)
/**
 *  nsstring md5格式转换
 *
 *  @param str 传入的str
 *
 *  @return 返回加密的MD5 str
 */
+ (NSString *)md5:(NSString *)str;
@end
