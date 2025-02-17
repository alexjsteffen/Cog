//
//  MIDIMetadataReader.mm
//  MIDI
//
//  Created by Christopher Snowhill on 10/16/13.
//  Copyright 2013 __NoWork, Inc__. All rights reserved.
//

#import "MIDIMetadataReader.h"

#import "MIDIDecoder.h"

#import <midi_processing/midi_processor.h>

@implementation MIDIMetadataReader

+ (NSArray *)fileTypes {
	return [MIDIDecoder fileTypes];
}

+ (NSArray *)mimeTypes {
	return [MIDIDecoder mimeTypes];
}

+ (float)priority {
	return 1.0f;
}

+ (NSDictionary *)metadataForURL:(NSURL *)url {
	id audioSourceClass = NSClassFromString(@"AudioSource");
	id<CogSource> source = [audioSourceClass audioSourceForURL:url];

	if(![source open:url])
		return 0;

	if(![source seekable])
		return 0;

	[source seek:0 whence:SEEK_END];
	long size = [source tell];
	[source seek:0 whence:SEEK_SET];

	std::vector<uint8_t> data;
	data.resize(size);
	[source read:&data[0] amount:size];

	midi_container midi_file;

	if(!midi_processor::process_file(data, [[url pathExtension] UTF8String], midi_file))
		return 0;

	int track_num;
	if([[url fragment] length] == 0)
		track_num = 0;
	else
		track_num = [[url fragment] intValue];

	midi_meta_data metadata;

	midi_file.get_meta_data(track_num, metadata);

	midi_meta_data_item item;
	bool remap_display_name = !metadata.get_item("title", item);

	NSArray *allowedKeys = @[@"title", @"artist", @"album", @"year"];

	NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithCapacity:10];

	for(size_t i = 0; i < metadata.get_count(); ++i) {
		const midi_meta_data_item &item = metadata[i];
		NSString *name = [[NSString stringWithUTF8String:item.m_name.c_str()] lowercaseString];
		if(![name isEqualToString:@"type"]) {
			if(remap_display_name && [name isEqualToString:@"display_name"])
				name = @"title";
			if([allowedKeys containsObject:name])
				[dict setObject:[NSString stringWithUTF8String:item.m_value.c_str()] forKey:name];
		}
	}

	std::vector<uint8_t> albumArt;

	if(metadata.get_bitmap(albumArt)) {
		[dict setObject:[NSData dataWithBytes:&albumArt[0] length:albumArt.size()] forKey:@"albumArt"];
	}

	return dict;
}

@end
