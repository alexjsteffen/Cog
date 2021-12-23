#import "PluginController.h"
#import "Plugin.h"
#import "CogPluginMulti.h"

#import "Logging.h"

@implementation PluginController

@synthesize sources;
@synthesize containers;
@synthesize metadataReaders;

@synthesize propertiesReadersByExtension;
@synthesize propertiesReadersByMimeType;

@synthesize decodersByExtension;
@synthesize decodersByMimeType;

@synthesize configured;

static PluginController *sharedPluginController = nil;

+ (id<CogPluginController>)sharedPluginController
{
	@synchronized(self) {
		if (sharedPluginController == nil) {
			sharedPluginController = [[self alloc] init];
		}
	}
	
	return sharedPluginController;
}


- (id)init {
	self = [super init];
	if (self) {
        self.sources = [[NSMutableDictionary alloc] init];
        self.containers = [[NSMutableDictionary alloc] init];
 
        self.metadataReaders = [[NSMutableDictionary alloc] init];
 
        self.propertiesReadersByExtension = [[NSMutableDictionary alloc] init];
        self.propertiesReadersByMimeType = [[NSMutableDictionary alloc] init];
 
        self.decodersByExtension = [[NSMutableDictionary alloc] init];
        self.decodersByMimeType = [[NSMutableDictionary alloc] init];
        
        [self setup];
	}
	
	return self;
}

- (void)setup
{
	if (self.configured == NO) {
		self.configured = YES;
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(bundleDidLoad:) name:NSBundleDidLoadNotification object:nil];

		[self loadPlugins];
		[self printPluginInfo];
	}	
}

- (void)bundleDidLoad:(NSNotification *)notification
{
	NSArray *classNames = [[notification userInfo] objectForKey:@"NSLoadedClasses"];
	for (NSString *className in classNames)
	{
		DLog(@"Class loaded: %@", className);
		Class bundleClass = NSClassFromString(className);
		if ([bundleClass conformsToProtocol:@protocol(CogContainer)]) {
			[self setupContainer:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogDecoder)]) {
			[self setupDecoder:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogMetadataReader)]) {
			[self setupMetadataReader:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogPropertiesReader)]) {
			[self setupPropertiesReader:className];
		}
		if ([bundleClass conformsToProtocol:@protocol(CogSource)]) {
			[self setupSource:className];
		}
	}
}

- (void)loadPluginsAtPath:(NSString *)path
{

	NSArray *dirContents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:nil];

	for (NSString *pname in dirContents)
	{
		NSString *ppath;
		ppath = [NSString pathWithComponents:[NSArray arrayWithObjects:path,pname,nil]];
		
		if ([[pname pathExtension] isEqualToString:@"bundle"])
		{
			NSBundle *b = [NSBundle bundleWithPath:ppath];
			[b load];
		}
	}
}

- (void)loadPlugins
{
	[self loadPluginsAtPath:[[NSBundle mainBundle] builtInPlugInsPath]];
	[self loadPluginsAtPath:[@"~/Library/Application Support/Cog/Plugins" stringByExpandingTildeInPath]];
}

- (void)setupContainer:(NSString *)className
{
	Class container = NSClassFromString(className);
	if (container && [container respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [container fileTypes])
		{
            NSString *ext = [fileType lowercaseString];
            NSMutableArray *containerSet;
            if (![containers objectForKey:ext])
            {
                containerSet = [[NSMutableArray alloc] init];
                [containers setObject:containerSet forKey:ext];
            }
            else
                containerSet = [containers objectForKey:ext];
            [containerSet addObject:className];
		}
	}
}

- (void)setupDecoder:(NSString *)className
{
	Class decoder = NSClassFromString(className);
	if (decoder && [decoder respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [decoder fileTypes])
		{
            NSString *ext = [fileType lowercaseString];
            NSMutableArray *decoders;
            if (![decodersByExtension objectForKey:ext])
            {
                decoders = [[NSMutableArray alloc] init];
                [decodersByExtension setObject:decoders forKey:ext];
            }
            else
                decoders = [decodersByExtension objectForKey:ext];
			[decoders addObject:className];
		}
	}
	
	if (decoder && [decoder respondsToSelector:@selector(mimeTypes)]) {
		for (id mimeType in [decoder mimeTypes]) 
		{
            NSString *mimetype = [mimeType lowercaseString];
            NSMutableArray *decoders;
            if (![decodersByMimeType objectForKey:mimetype])
            {
                decoders = [[NSMutableArray alloc] init];
                [decodersByMimeType setObject:decoders forKey:mimetype];
            }
            else
                decoders = [decodersByMimeType objectForKey:mimetype];
            [decoders addObject:className];
		}
	}
}

- (void)setupMetadataReader:(NSString *)className
{
	Class metadataReader = NSClassFromString(className);
	if (metadataReader && [metadataReader respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [metadataReader fileTypes])
		{
            NSString *ext = [fileType lowercaseString];
            NSMutableArray *readers;
            if (![metadataReaders objectForKey:ext])
            {
                readers = [[NSMutableArray alloc] init];
                [metadataReaders setObject:readers forKey:ext];
            }
            else
                readers = [metadataReaders objectForKey:ext];
            [readers addObject:className];
		}
	}
}

- (void)setupPropertiesReader:(NSString *)className
{
	Class propertiesReader = NSClassFromString(className);
	if (propertiesReader && [propertiesReader respondsToSelector:@selector(fileTypes)]) {
		for (id fileType in [propertiesReader fileTypes])
		{
            NSString *ext = [fileType lowercaseString];
            NSMutableArray *readers;
            if (![propertiesReadersByExtension objectForKey:ext])
            {
                readers = [[NSMutableArray alloc] init];
                [propertiesReadersByExtension setObject:readers forKey:ext];
            }
            else
                readers = [propertiesReadersByExtension objectForKey:ext];
            [readers addObject:className];
		}
	}

	if (propertiesReader && [propertiesReader respondsToSelector:@selector(mimeTypes)]) {
		for (id mimeType in [propertiesReader mimeTypes])
		{
            NSString *mimetype = [mimeType lowercaseString];
            NSMutableArray *readers;
            if (![propertiesReadersByMimeType objectForKey:mimetype])
            {
                readers = [[NSMutableArray alloc] init];
                [propertiesReadersByMimeType setObject:readers forKey:mimetype];
            }
            else
                readers = [propertiesReadersByMimeType objectForKey:mimetype];
            [readers addObject:className];
		}
	}
}

- (void)setupSource:(NSString *)className
{
	Class source = NSClassFromString(className);
	if (source && [source respondsToSelector:@selector(schemes)]) {
		for (id scheme in [source schemes])
		{
			[sources setObject:className forKey:scheme];
		}
	}
}

- (void)printPluginInfo
{
	ALog(@"Sources: %@", self.sources);
	ALog(@"Containers: %@", self.containers);
	ALog(@"Metadata Readers: %@", self.metadataReaders);

	ALog(@"Properties Readers By Extension: %@", self.propertiesReadersByExtension);
	ALog(@"Properties Readers By Mime Type: %@", self.propertiesReadersByMimeType);

	ALog(@"Decoders by Extension: %@", self.decodersByExtension);
	ALog(@"Decoders by Mime Type: %@", self.decodersByMimeType);
}

- (id<CogSource>) audioSourceForURL:(NSURL *)url
{
	NSString *scheme = [url scheme];
	
	Class source = NSClassFromString([sources objectForKey:scheme]);
	
	return [[source alloc] init];
}

- (NSArray *) urlsForContainerURL:(NSURL *)url
{
	NSString *ext = [url pathExtension];
    NSArray *containerSet = [containers objectForKey:[ext lowercaseString]];
    NSString *classString;
    if (containerSet) {
        if ( [containerSet count] > 1 ) {
            return [CogContainerMulti urlsForContainerURL:url containers:containerSet];
        }
        else {
            classString = [containerSet objectAtIndex:0];
        }
    }
    else {
        return nil;
    }
	
	Class container = NSClassFromString(classString);
	
	return [container urlsForContainerURL:url];
}

//Note: Source is assumed to already be opened.
- (id<CogDecoder>) audioDecoderForSource:(id <CogSource>)source
{
	NSString *ext = [[source url] pathExtension];
	NSArray *decoders = [decodersByExtension objectForKey:[ext lowercaseString]];
    NSString *classString;
    if (decoders) {
        if ( [decoders count] > 1 ) {
            return [[CogDecoderMulti alloc] initWithDecoders:decoders];
        }
        else {
            classString = [decoders objectAtIndex:0];
        }
    }
	else {
        decoders = [decodersByMimeType objectForKey:[[source mimeType] lowercaseString]];
        if (decoders) {
            if ( [decoders count] > 1 ) {
                return [[CogDecoderMulti alloc] initWithDecoders:decoders];
            }
            else {
                classString = [decoders objectAtIndex:0];
            }
        }
        else {
            classString = @"SilenceDecoder";
        }
	}

	Class decoder = NSClassFromString(classString);
	
	return [[decoder alloc] init];
}

- (NSDictionary *)metadataForURL:(NSURL *)url
{
    NSString * urlScheme = [url scheme];
    if ([urlScheme isEqualToString:@"http"] ||
        [urlScheme isEqualToString:@"https"])
        return nil;
    
	NSString *ext = [url pathExtension];
    NSArray *readers = [metadataReaders objectForKey:[ext lowercaseString]];
    NSString *classString;
    if (readers) {
        if ( [readers count] > 1 ) {
            return [CogMetadataReaderMulti metadataForURL:url readers:readers];
        }
        else {
            classString = [readers objectAtIndex:0];
        }
    }
    else {
        return nil;
    }
	
	Class metadataReader = NSClassFromString(classString);
	
	return [metadataReader metadataForURL:url];
}


//If no properties reader is defined, use the decoder's properties.
- (NSDictionary *)propertiesForURL:(NSURL *)url
{
    NSString * urlScheme = [url scheme];
    if ([urlScheme isEqualToString:@"http"] ||
        [urlScheme isEqualToString:@"https"])
        return nil;
    
    NSDictionary *properties = nil;
	NSString *ext = [url pathExtension];
	
	id<CogSource> source = [self audioSourceForURL:url];
	if (![source open:url])
		return nil;
    
    NSArray *readers = [propertiesReadersByExtension objectForKey:[ext lowercaseString]];
    NSString *classString = nil;
    if (readers)
    {
        if ( [readers count] > 1 ) {
            properties = [CogPropertiesReaderMulti propertiesForSource:source readers:readers];
            if (properties != nil && [properties count])
                return properties;
        }
        else {
            classString = [readers objectAtIndex:0];
        }
    }
    else {
        readers = [propertiesReadersByMimeType objectForKey:[[source mimeType] lowercaseString]];
        if (readers)
        {
            if ( [readers count] > 1 ) {
                properties = [CogPropertiesReaderMulti propertiesForSource:source readers:readers];
                if (properties != nil && [properties count])
                    return properties;
            }
            else {
                classString = [readers objectAtIndex:0];
            }
        }
    }

	if (classString)
	{
		Class propertiesReader = NSClassFromString(classString);

		properties = [propertiesReader propertiesForSource:source];
        if (properties != nil && [properties count])
            return properties;
	}

    {
		id<CogDecoder> decoder = [self audioDecoderForSource:source];
		if (![decoder open:source])
		{
			return nil;
		}
		
		NSDictionary *properties = [decoder properties];
		
		[decoder close];
		
		return properties;
	}
}

- (int)putMetadataInURL:(NSURL *)url
{
    return 0;
}

@end

