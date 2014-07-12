//
//  MCParsedAudioData.h
//  MCAudioFileStream
//
//  Created by Chengyin on 14-7-12.
//  Copyright (c) 2014年 Chengyin. All rights reserved.
//  https://github.com/msching/MCAudioFileStream

#import <Foundation/Foundation.h>
#import <CoreAudio/CoreAudioTypes.h>

@interface MCParsedAudioData : NSObject

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription;

- (const void *)bytes;
- (AudioStreamPacketDescription)packetDescription;
@end
