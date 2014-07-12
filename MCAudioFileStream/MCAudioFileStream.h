//
//  MCAudioFileStream.h
//  MCAudioFileStream
//
//  Created by Chengyin on 14-7-12.
//  Copyright (c) 2014年 Chengyin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MCParsedAudioData.h"

@class MCAudioFileStream;
@protocol MCAudioFileStreamDelegate <NSObject>
@required
- (void)audioFileStreamReadyToProducePackets:(MCAudioFileStream *)audioFileStream;
- (void)audioFileStream:(MCAudioFileStream *)audioFileStream audioDataParsed:(NSArray *)audioData;
@end

@interface MCAudioFileStream : NSObject

@property (nonatomic,assign,readonly) AudioFileTypeID fileType;
@property (nonatomic,assign,readonly) BOOL available;
@property (nonatomic,assign,readonly) BOOL readyToProducePackets;
@property (nonatomic,weak) id<MCAudioFileStreamDelegate> delegate;

@property (nonatomic,assign,readonly) NSTimeInterval duration;
@property (nonatomic,assign,readonly) UInt32 bitRate;

- (instancetype)initWithFileType:(AudioFileTypeID)fileType error:(NSError **)error;

- (BOOL)parseData:(NSData *)data error:(NSError **)error;

/**
 *  seek to timeinterval
 *
 *  @param time On input, timeinterval to seek.
                On output, fixed timeinterval.
 *
 *  @return seek byte offset
 */
- (SInt64)seekToTime:(NSTimeInterval *)time;

- (void)close;
@end
