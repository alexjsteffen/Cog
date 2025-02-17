//
//  CogPluginMulti.m
//  CogAudio
//
//  Created by Christopher Snowhill on 10/21/13.
//
//

#import "CogPluginMulti.h"

NSArray *sortClassesByPriority(NSArray *theClasses) {
	NSMutableArray *sortedClasses = [NSMutableArray arrayWithArray:theClasses];
	[sortedClasses sortUsingComparator:
	               ^NSComparisonResult(id obj1, id obj2) {
		               NSString *classString1 = (NSString *)obj1;
		               NSString *classString2 = (NSString *)obj2;

		               Class class1 = NSClassFromString(classString1);
		               Class class2 = NSClassFromString(classString2);

		               float priority1 = [class1 priority];
		               float priority2 = [class2 priority];

		               if(priority1 == priority2)
			               return NSOrderedSame;
		               else if(priority1 > priority2)
			               return NSOrderedAscending;
		               else
			               return NSOrderedDescending;
	               }];
	return sortedClasses;
}

@interface CogDecoderMulti (Private)
- (void)registerObservers;
- (void)removeObservers;
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context;
@end

@implementation CogDecoderMulti

+ (NSArray *)mimeTypes {
	return nil;
}

+ (NSArray *)fileTypes {
	return nil;
}

+ (float)priority {
	return -1.0;
}

+ (NSArray *)fileTypeAssociations {
	return nil;
}

- (id)initWithDecoders:(NSArray *)decoders {
	self = [super init];
	if(self) {
		theDecoders = sortClassesByPriority(decoders);
		theDecoder = nil;
	}
	return self;
}

- (NSDictionary *)properties {
	if(theDecoder != nil) return [theDecoder properties];
	return nil;
}

- (NSDictionary *)metadata {
	if(theDecoder != nil) return [theDecoder metadata];
	return @{};
}

- (int)readAudio:(void *)buffer frames:(UInt32)frames {
	if(theDecoder != nil) return [theDecoder readAudio:buffer frames:frames];
	return 0;
}

- (BOOL)open:(id<CogSource>)source {
	for(NSString *classString in theDecoders) {
		Class decoder = NSClassFromString(classString);
		theDecoder = [[decoder alloc] init];
		[self registerObservers];
		if([theDecoder open:source])
			return YES;
		[self removeObservers];
		// HTTP reader supports limited rewinding
		[source seek:0 whence:SEEK_SET];
	}
	theDecoder = nil;
	return NO;
}

- (long)seek:(long)frame {
	if(theDecoder != nil) return [theDecoder seek:frame];
	return -1;
}

- (void)close {
	if(theDecoder != nil) {
		[self removeObservers];
		[theDecoder close];
		theDecoder = nil;
	}
}

- (void)registerObservers {
	[theDecoder addObserver:self
	             forKeyPath:@"properties"
	                options:(NSKeyValueObservingOptionNew)
	                context:NULL];

	[theDecoder addObserver:self
	             forKeyPath:@"metadata"
	                options:(NSKeyValueObservingOptionNew)
	                context:NULL];
}

- (void)removeObservers {
	[theDecoder removeObserver:self forKeyPath:@"properties"];
	[theDecoder removeObserver:self forKeyPath:@"metadata"];
}

- (BOOL)setTrack:(NSURL *)track {
	if(theDecoder != nil && [theDecoder respondsToSelector:@selector(setTrack:)]) return [theDecoder setTrack:track];
	return NO;
}

- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
	[self willChangeValueForKey:keyPath];
	[self didChangeValueForKey:keyPath];
}

@end

@implementation CogContainerMulti

+ (NSArray *)urlsForContainerURL:(NSURL *)url containers:(NSArray *)containers {
	NSArray *sortedContainers = sortClassesByPriority(containers);
	for(NSString *classString in sortedContainers) {
		Class container = NSClassFromString(classString);
		NSArray *urls = [container urlsForContainerURL:url];
		if([urls count])
			return urls;
	}
	return nil;
}

@end

@implementation CogMetadataReaderMulti

+ (NSDictionary *)metadataForURL:(NSURL *)url readers:(NSArray *)readers {
	NSArray *sortedReaders = sortClassesByPriority(readers);
	for(NSString *classString in sortedReaders) {
		Class reader = NSClassFromString(classString);
		NSDictionary *data = [reader metadataForURL:url];
		if([data count])
			return data;
	}
	return nil;
}

@end

@implementation CogPropertiesReaderMulti

+ (NSDictionary *)propertiesForSource:(id<CogSource>)source readers:(NSArray *)readers {
	NSArray *sortedReaders = sortClassesByPriority(readers);
	for(NSString *classString in sortedReaders) {
		Class reader = NSClassFromString(classString);
		NSDictionary *data = [reader propertiesForSource:source];
		if([data count])
			return data;
		if([source seekable])
			[source seek:0 whence:SEEK_SET];
	}
	return nil;
}

@end
