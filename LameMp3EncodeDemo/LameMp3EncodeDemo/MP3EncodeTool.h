//
//  MP3EncodeTool.h
//  LameMp3EncodeDemo
//
//  Created by AnDong on 2018/2/13.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MP3EncodeTool : NSObject

+ (instancetype)shareInstance;
    
/**
 pcm编码成Mp3文件
 @param pcmFilePath pcm源文件路径
 @param mp3FilePath 编码完成mp3文件路径
 @param sampleRate 采样率
 @param channels 通道数
 @param bitRate 码率 单位kbps
 
 返回编码成功结果
 */
- (BOOL)encodeMp3FileWithPcmFilePath:(NSString *)pcmFilePath
                 destinationFilePath:(NSString *)mp3FilePath
                          sampleRate:(int)sampleRate
                            channels:(int)channels
                             bitRate:(int)bitRate;
@end
