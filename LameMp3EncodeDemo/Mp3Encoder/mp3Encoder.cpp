//
//  mp3Encoder.cpp
//  LameMp3EncodeDemo
//
//  Created by AnDong on 2018/2/13.
//  Copyright © 2018年 AnDong. All rights reserved.
//

#include "mp3Encoder.hpp"
#include  <stdlib.h>
#include  <stdio.h>
#include  <unistd.h>


Mp3Encoder::Mp3Encoder(){
    
}

int Mp3Encoder::Init(const char *pcmFilePath, const char *mp3FilePath, int sampleRate, int channels, int bitRate){
    encodeEnd = false;
    int ret = -1;
    pcmFile = fopen(pcmFilePath, "rb");
    if(pcmFile){
        mp3File = fopen(mp3FilePath, "wb+");
    }
    
    if(mp3File){
        lameClient = lame_init();
        lame_set_in_samplerate(lameClient,sampleRate);
        lame_set_out_samplerate(lameClient, sampleRate);
        lame_set_num_channels(lameClient, channels);
        lame_set_brate(lameClient, bitRate);
        lame_init_params(lameClient);
        lame_set_quality(lameClient,2);
    }
    
    return ret;
}


void Mp3Encoder::EncodeLocalFile(){
    
    //跳过 PCM header 否者会有一些噪音在MP3开始播放处
    fseek(pcmFile, 4*1024,  SEEK_CUR);
    
    //双声道获取比特率的数据
    int bufferSize = 256 * 1024;
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
    
    //写入Mp3 VBR Tag，不是必须的步骤
    lame_mp3_tags_fid(lameClient, mp3File);
    delete []buffer;
    delete []leftBuffer;
    delete []rightBuffer;
    delete []mp3_buffer;
}

void Mp3Encoder::EncodeStreamFile(){
    
    //双声道获取比特率的数据
    int bufferSize = 256 * 1024;
    short *buffer = new short[bufferSize/2];
    short *leftBuffer = new short[bufferSize/4];
    short *rightBuffer = new short[bufferSize/4];
    unsigned char* mp3_buffer = new unsigned char[bufferSize];
    size_t readBufferSize = 0;
    
    bool isSkipPcmHeader = false;
    long curPos;
    
    //循环读取数据编码
    do {
            curPos = ftell(pcmFile);
            long startPos = ftell(pcmFile);
            fseek(pcmFile, 0, SEEK_END);
            long endPos = ftell(pcmFile);
            long totalDataLength = endPos - startPos;
            fseek(pcmFile, curPos, SEEK_SET);
            if (totalDataLength > bufferSize) {
                if (!isSkipPcmHeader) {
                    //跳过 PCM header 否者会有一些噪音在MP3开始播放处
                    fseek(pcmFile, 4*1024,  SEEK_CUR);
                    isSkipPcmHeader = true;
                }
                readBufferSize = fread(buffer, 2, bufferSize/2, pcmFile);
                //双声道的处理
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
        //sleep 0.05s
        sleep(0.05);
        
    } while (!encodeEnd);
    
    //这里需要注意的是，一旦录音结束encodeEnd就会导致上面的函数结束，有可能出现解码慢，导致录音结束，仍然没有解码完所有数据的可能
    //循环读取剩余数据进行编码
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
    
    //写入Mp3 VBR Tag，不是必须的步骤
    lame_mp3_tags_fid(lameClient, mp3File);
    delete []buffer;
    delete []leftBuffer;
    delete []rightBuffer;
    delete []mp3_buffer;
    
}


void Mp3Encoder::Destroy(){
    if(pcmFile){
        fclose(pcmFile);
    }
    if(mp3File){
        fclose(mp3File);
        lame_close(lameClient);
    }
}

Mp3Encoder::~Mp3Encoder(){
    
}
