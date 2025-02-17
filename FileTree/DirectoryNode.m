//
//  DirectoryNode.m
//  Cog
//
//  Created by Vincent Spader on 8/20/2006.
//  Copyright 2006 Vincent Spader. All rights reserved.
//

#import "DirectoryNode.h"

#import "FileNode.h"
#import "SmartFolderNode.h"

#import "NSString+FinderCompare.h"

@implementation DirectoryNode

- (BOOL)isLeaf {
	return NO;
}

- (void)updatePath {
	NSDirectoryEnumerator *enumerator = [[NSFileManager defaultManager] enumeratorAtURL:url
	                                                         includingPropertiesForKeys:@[NSURLNameKey, NSURLIsDirectoryKey]
	                                                                            options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants | NSDirectoryEnumerationSkipsPackageDescendants | NSDirectoryEnumerationSkipsHiddenFiles)
	                                                                       errorHandler:^BOOL(NSURL *url, NSError *error) {
		                                                                       return NO;
	                                                                       }];
	NSMutableArray *fullPaths = [[NSMutableArray alloc] init];

	for(NSURL *theUrl in enumerator) {
		[fullPaths addObject:[theUrl path]];
	}

	[self processPaths:[fullPaths sortedArrayUsingSelector:@selector(finderCompare:)]];
}

@end
