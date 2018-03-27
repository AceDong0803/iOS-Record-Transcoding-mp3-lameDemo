//
//  MP3EncodeTool.m
//  LameMp3EncodeDemo
//
//  Created by AnDong on 2018/2/13.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#import "MP3EncodeTool.h"
#include "lame.h"
#include <stdio.h>

@implementation MP3EncodeTool
    
+ (instancetype)shareInstance{
    static MP3EncodeTool *tool = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(tool == nil){
            tool = [[MP3EncodeTool alloc]init];
        }
    });
    return tool;
}
    
- (BOOL)encodeMp3FileWithPcmFilePath:(NSString *)pcmFilePath
                 destinationFilePath:(NSString *)mp3FilePath
                          sampleRate:(int)sampleRate
                            channels:(int)channels
                             bitRate:(int)bitRate{
    FILE* pcmFile;
    FILE* mp3File;
    lame_t lameClient;
    
    int ret = -1;
    pcmFile = fopen([pcmFilePath cStringUsingEncoding:NSUTF8StringEncoding], "rb");
    if(pcmFile){
        mp3File = fopen([mp3FilePath cStringUsingEncoding:NSUTF8StringEncoding], "wb");
    }
    else{
        //返回路径错误
        NSLog(@"输入pcm文件路径不正确");
        return ret;
    }

    if(mp3File){
        //初始化参数
        lameClient = lame_init();
        lame_set_in_samplerate(lameClient,sampleRate);
        lame_set_out_samplerate(lameClient, sampleRate);
        lame_set_num_channels(lameClient, channels);
        lame_set_brate(lameClient, bitRate);
        lame_init_params(lameClient);
    }
    else{
        //返回路径错误
        NSLog(@"目的存放路径不正确");
        return ret;
    }
    
    //开始编码
    int bufferSize = bitRate * 2;
    short *buffer = new short[bufferSize/2];
    short *leftBuffer = new short[bufferSize/4];
    short *rightBuffer = new short[bufferSize/4];
    unsigned char* mp3_buffer = new unsigned char[bufferSize];
    size_t readBufferSize = 0;
    while ((readBufferSize = fread(buffer, 2, bufferSize/2, pcmFile))>0) {
        for(int i = 0;i < readBufferSize;i++){
            if(i % 2 == 0){
                leftBuffer[i/2] = buffer[i];
            }
            else{
                rightBuffer[i/2] = buffer[i];
            }
        }
        size_t wroteSize = lame_encode_buffer(lameClient, (short int *)leftBuffer, (short int *)rightBuffer, (int)(readBufferSize / 2), mp3_buffer, bufferSize);
        fwrite(mp3_buffer, 1, wroteSize, mp3File);
    }
    delete []buffer;
    delete []leftBuffer;
    delete []rightBuffer;
    delete []mp3_buffer;
    
    
    //编码完成后关闭文件流，释放资源
    fclose(pcmFile);
    fclose(mp3File);
    lame_close(lameClient);

    return ret;
}

@end
