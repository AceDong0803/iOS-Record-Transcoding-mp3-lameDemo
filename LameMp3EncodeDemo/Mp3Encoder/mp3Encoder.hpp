//
//  mp3Encoder.hpp
//  LameMp3EncodeDemo
//
//  Created by AnDong on 2018/2/13.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#ifndef mp3Encoder_hpp
#define mp3Encoder_hpp

#include <stdio.h>
#include "lame.h"

class Mp3Encoder {
    private:
    FILE* pcmFile;
    FILE* mp3File;
    lame_t lameClient;
    
    public:
    
    //标志位，用于编录音编解码的录音结束标识符
    bool encodeEnd;
    
    Mp3Encoder();
    ~Mp3Encoder();
    /**
     pcm编码成Mp3文件
     @param pcmFilePath pcm源文件路径
     @param mp3FilePath 编码完成mp3文件路径
     @param sampleRate 采样率
     @param channels 通道数
     @param bitRate 码率
     */
    //每个任务都需要初始化一次
    int Init(const char* pcmFilePath,const char *mp3FilePath,int sampleRate,int channels,int bitRate);
    
    //编码本地文件
    void EncodeLocalFile();
    
    //边录制边解码
    void EncodeStreamFile();
    
    //销毁资源
    void Destroy();
    
};

#endif /* mp3Encoder_hpp */
