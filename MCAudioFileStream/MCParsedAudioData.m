//
//  MCParsedAudioData.m
//  MCAudioFileStream
//
//  Created by Chengyin on 14-7-12.
//  Copyright (c) 2014年 Chengyin. All rights reserved.
//

#import "MCParsedAudioData.h"

@interface MCParsedAudioData ()
{
@private
    void *_bytes;
    AudioStreamPacketDescription _packetDescription;
}
@end

@implementation MCParsedAudioData

+ (instancetype)parsedAudioDataWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription
{
    return [[[self class] alloc] initWithBytes:bytes packetDescription:packetDescription];
}

- (instancetype)initWithBytes:(const void *)bytes packetDescription:(AudioStreamPacketDescription)packetDescription
{
    if (bytes == NULL || packetDescription.mDataByteSize == 0)
    {
        return nil;
    }
    
    self = [super init];
    if (self)
    {
        _bytes = (void *)malloc(packetDescription.mDataByteSize);
        _packetDescription = packetDescription;
        memcpy(_bytes, bytes, packetDescription.mDataByteSize);
    }
    return self;
}

- (AudioStreamPacketDescription)packetDescription
{
    return _packetDescription;
}

- (const void *)bytes
{
    return _bytes;
}

- (void)dealloc
{
    if (_bytes != NULL)
    {
        free(_bytes);
        _bytes = NULL;
    }
}
@end