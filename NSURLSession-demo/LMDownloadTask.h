//
//  LMDownloadTask.h
//  NSURLSession-demo
//  下载任务类，单例模式
//  Created by zhuo on 16/7/11.
//  Copyright © 2016年 zhuo. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LMDownLoadModel.h"
@class LMDownloadModel;

@interface LMDownloadTask : NSObject <NSURLSessionDownloadDelegate>
/** 下载中的模型 只读*/
@property (nonatomic, strong,readonly) NSMutableArray *waitingDownloadModels;
/** 等待中的模型 只读*/
@property (nonatomic, strong,readonly) NSMutableArray *downloadingModels;
/** 最大下载数 */
@property (nonatomic, assign) NSInteger maxDownloadCount;
/** 后台session configure */
@property (nonatomic, strong) NSString *backgroundConfigure;

// 单例
+ (LMDownloadTask *)shareDonwLoadTask;

// 开始下载
- (LMDownloadModel *)startDownloadURLString:(NSString *)URLString toDestinationPath:(NSString *)destinationPath progress:(LMDownloadProgressBlock)progress state:(LMDownloadStateBlock)state;

- (void)startWithDownloadModel:(LMDownloadModel *)downloadModel progress:(LMDownloadProgressBlock)progress state:(LMDownloadStateBlock)state;
@end
