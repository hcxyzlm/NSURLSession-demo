//
//  LMDownLoadModel.h
//  NSURLSession-demo
//  // 下载模型类
//  Created by zhuo on 16/7/11.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, LMDownloadOperationState){
    LMDonwloadOperationUnknown          = 0,    //未下载
    LMDownloadOperationReadyState       = 1,    //等待下载
    LMDownloadOperationExecutingState   = 2,    // 正在下载
    LMDownloadOperationPausedState      = 3,    // 暂停下载
    LMDownloadOperationFinishedState    = 4,    // 完成下载
    LMDownloadOperationErrorState       = 5     // 下载失败
};

@interface LMDownLoadModel : NSObject
/** 下载地址RUL*/
@property (nonatomic, strong, readonly) NSString *downloadURL;
/** 文件名*/
@property (nonatomic, strong) NSString *fileName;
/** 下载目录，缓存目录*/
@property (nonatomic, strong) NSString *downloadDirectory;
/** 下载状态 */
@property (nonatomic, assign) LMDownloadOperationState state;
/** 下载任务 */
@property (nonatomic, strong) NSURLSessionTask *task;
/** 文件流 */
@property (nonatomic, strong) NSOutputStream *stream;
/** 下载路径 */
@property (nonatomic, strong) NSString *filePath;

/**
 *  初始化方法
 *
 *  @param URLString 下载地址
 */
- (instancetype)initWithURLString:(NSString *)URLString;
/**
 *  初始化方法
 *
 *  @param URLString 下载地址
 *  @param filePath  缓存地址 当为nil 默认缓存到cache
 */
- (instancetype)initWithURLString:(NSString *)URLString filePath:(NSString *)filePath;
@end
