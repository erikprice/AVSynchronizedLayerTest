/*
 * For license terms please visit http://www.ottersoftwareblog.com/source-code-license/
 */

#import "AppDelegate.h"
#import "OTSTimeMethods.h"

#define kDictionaryKeySubtitleTimecode @"SubtitleTimecode"
#define kDictionaryKeySubtitleText @"SubtitleText"

static void *AVSPPlayerItemStatusContext = &AVSPPlayerItemStatusContext;
static void *AVSPPlayerLayerReadyForDisplay = &AVSPPlayerLayerReadyForDisplay;

@interface AppDelegate()

@property (retain) AVPlayer *player;
@property (assign) AVPlayerLayer *playerLayer;

- (void)setUpPlaybackOfAsset:(AVAsset *)asset withKeys:(NSArray *)keys;
- (void)stopLoadingAndHandleError:(NSError *)error;
- (void)setupSubtitles;

@end

#pragma mark -

@implementation AppDelegate

@synthesize window = _window;
@synthesize player = _player;
@synthesize playerLayer = _playerLayer;

- (void)dealloc
{
  [_player release], _player = nil;
  [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
  // Set up the top-level layer
  CALayer *layer = [CALayer layer];
  [layer setLayoutManager:[CAConstraintLayoutManager layoutManager]];
  [[[self window] contentView] setLayer:layer];
  [[[self window] contentView] setWantsLayer:YES];

	// Create the AVPlayer, add rate and status observers
  AVPlayer *aPlayer = [[AVPlayer alloc] init];
  [self setPlayer:aPlayer];
  [aPlayer release], aPlayer = nil;
  
//	[self addObserver:self forKeyPath:@"player.rate" options:NSKeyValueObservingOptionNew context:AVSPPlayerRateContext];
	[self addObserver:self forKeyPath:@"player.currentItem.status" options:NSKeyValueObservingOptionNew context:AVSPPlayerItemStatusContext];
	
	// Create an asset with our URL, asychronously load its tracks, its duration, and whether it's playable or protected.
	// When that loading is complete, configure a player to play the asset.
  NSString *videoFilePath = [kVideoFilePath stringByExpandingTildeInPath];
	AVURLAsset *asset = [AVAsset assetWithURL:[NSURL fileURLWithPath:videoFilePath]];
	NSArray *assetKeysToLoadAndTest = [NSArray arrayWithObjects:@"playable", @"duration", nil];
	[asset loadValuesAsynchronouslyForKeys:assetKeysToLoadAndTest completionHandler:^(void) {
		// The asset invokes its completion handler on an arbitrary queue when loading is complete.
		// Because we want to access our AVPlayer in our ensuing set-up, we must dispatch our handler to the main queue.
		dispatch_async(dispatch_get_main_queue(), ^(void) {
			[self setUpPlaybackOfAsset:asset withKeys:assetKeysToLoadAndTest];
		});
	}];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
	if (context == AVSPPlayerItemStatusContext) {
		AVPlayerStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
		switch (status) {
			case AVPlayerItemStatusUnknown:
        NSLog(@"%@", NSLocalizedString(@"Unknown player status", nil));
				return;
			case AVPlayerItemStatusReadyToPlay:
				return;
			case AVPlayerItemStatusFailed:
        NSLog(@"%@", NSLocalizedString(@"Cannot Load Video", @"Error message: Cannot Load Video"));
				[self stopLoadingAndHandleError:[[[self player] currentItem] error]];
				return;
		}
	} else if (context == AVSPPlayerLayerReadyForDisplay) {
		if ([[change objectForKey:NSKeyValueChangeNewKey] boolValue] == YES) {
      [[self playerLayer] setContentsGravity:kCAGravityResizeAspectFill];
      [[self player] setVolume:0.25];
      [self setupSubtitles];
      [[self player] play];
      [[self playerLayer] setHidden:NO];
		}
	} else {
		[super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
	}
}


#pragma mark -
#pragma mark Private Methods

- (void)setUpPlaybackOfAsset:(AVAsset *)asset withKeys:(NSArray *)keys
{
	// This method is called when the AVAsset for our URL has completing the loading of the values of the specified array of keys.
	// We set up playback of the asset here.
	
	// First test whether the values of each of the keys we need have been successfully loaded.
	for (NSString *key in keys) {
		NSError *error = nil;
		if ([asset statusOfValueForKey:key error:&error] == AVKeyValueStatusFailed) {
      NSLog(@"%@", NSLocalizedString(@"Unplayable Video", @"Error message: Unplayable Video"));
			[self stopLoadingAndHandleError:error];
			return;
		}
	}
  
	if (![asset isPlayable]) {
		// We can't play this asset.
    NSLog(@"%@", NSLocalizedString(@"Unplayable Video", @"Error message: Unplayable Video"));
    [self stopLoadingAndHandleError:nil];
		return;
	}
  
  if ([asset hasProtectedContent]) {
		// We can't play this asset.
    NSLog(@"%@", NSLocalizedString(@"Protected Video", @"Error message: Protected Video"));
    [self stopLoadingAndHandleError:nil];
		return;
	}
  
  // Create a new AVPlayerItem and make it our player's current item.
  AVPlayerItem *playerItem = [AVPlayerItem playerItemWithAsset:asset];
	[[self player] replaceCurrentItemWithPlayerItem:playerItem];
  
  // Set up an AVPlayerLayer according to whether the asset contains video.
	if ([[asset tracksWithMediaType:AVMediaTypeVideo] count] != 0) {
		// Create an AVPlayerLayer and add it to the player view if there is video, but hide it until it's ready for display
    AVPlayerLayer *newPlayerLayer = [AVPlayerLayer playerLayerWithPlayer:[self player]];
		[newPlayerLayer setFrame:[[[[self window] contentView] layer] bounds]];
		[newPlayerLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
		[newPlayerLayer setHidden:YES];
		[[[[self window] contentView] layer] addSublayer:newPlayerLayer];
		[self setPlayerLayer:newPlayerLayer];
		[self addObserver:self forKeyPath:@"playerLayer.readyForDisplay" options:NSKeyValueObservingOptionInitial | NSKeyValueObservingOptionNew context:AVSPPlayerLayerReadyForDisplay];
	} else {
		// This asset has no video tracks.
    NSLog(@"%@", NSLocalizedString(@"No Video Available", @"Error message: No Video Available"));
    [self stopLoadingAndHandleError:nil];
	}
}

- (void)stopLoadingAndHandleError:(NSError *)error
{
	if (error) {
    [[self window] presentError:error modalForWindow:[self window] delegate:nil didPresentSelector:NULL contextInfo:nil];
	}
}

- (void)setupSubtitles
{
  NSArray *subtitles = [NSArray arrayWithObjects:
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:00:00.000", kDictionaryKeySubtitleTimecode, @"Subtitle Number 1.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:00:10.000", kDictionaryKeySubtitleTimecode, @"Ten seconds have gone by.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:00:20.000", kDictionaryKeySubtitleTimecode, @"Got to twenty seconds.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:00:30.000", kDictionaryKeySubtitleTimecode, @"Already at half a minute.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:00:40.000", kDictionaryKeySubtitleTimecode, @"Forty second.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:00:50.000", kDictionaryKeySubtitleTimecode, @"Nearly a minute.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:01:00.000", kDictionaryKeySubtitleTimecode, @"One minute gone.", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:01:10.000", kDictionaryKeySubtitleTimecode, @"Nearly at the last subtitle...", kDictionaryKeySubtitleText, nil],
                        [NSDictionary dictionaryWithObjectsAndKeys:@"00:01:20.000", kDictionaryKeySubtitleTimecode, @"... and this is displayed until the end of the video", kDictionaryKeySubtitleText, nil],
                        nil];
  NSUInteger subtitleAreaHeight = 100;
  
  AVSynchronizedLayer *newSyncLayer = [AVSynchronizedLayer synchronizedLayerWithPlayerItem:[[self player] currentItem]];
  [newSyncLayer setFrame:[[[[self window] contentView] layer] bounds]];
  [newSyncLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerHeightSizable];
  [newSyncLayer setMasksToBounds:NO];

  CAScrollLayer *scrollLayer = [CAScrollLayer layer];
  CGRect newFrame = [[[[self window] contentView] layer] bounds];
  newFrame.size.height = subtitleAreaHeight;
  [scrollLayer setFrame:newFrame];
  [scrollLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerMaxYMargin];
  
  CALayer *containerLayer = [CALayer layer];
  [containerLayer setAnchorPoint:CGPointMake(0.0, 0.0)];
  [containerLayer setLayoutManager:[CAConstraintLayoutManager layoutManager]];
  newFrame = [[[[self window] contentView] layer] bounds];
  newFrame.size.height = subtitleAreaHeight * [subtitles count];
  [containerLayer setFrame:newFrame];
  [containerLayer setAutoresizingMask:kCALayerWidthSizable | kCALayerMaxYMargin];
  CGColorRef backgroundColor = CGColorCreateGenericRGB(0.1, 0.1, 0.1, 0.9);
  [containerLayer setBackgroundColor:backgroundColor];
  CGColorRelease(backgroundColor);

  NSMutableArray *subtitlePositions = [[NSMutableArray alloc] init];
  NSMutableArray *subtitleTimes = [[NSMutableArray alloc] init];
  
  for (NSUInteger index = 0; index < [subtitles count]; index++) {
    CALayer *sublayer = [CALayer layer];
    [sublayer setAnchorPoint:CGPointMake(0.0, 0.0)];
    CGRect newFrame = [[[[self window] contentView] layer] bounds];
    newFrame.origin.y = (subtitleAreaHeight * index);
    newFrame.size.height = subtitleAreaHeight;
    [sublayer setFrame:newFrame];
    [sublayer setAutoresizingMask:kCALayerWidthSizable];
    [sublayer setLayoutManager:[CAConstraintLayoutManager layoutManager]];
    [sublayer setBorderWidth:1.0];
    [sublayer setBorderColor:CGColorGetConstantColor(kCGColorBlack)];
    
    CATextLayer *textLayer = [CATextLayer layer];
    [textLayer setString:[[subtitles objectAtIndex:index] valueForKey:kDictionaryKeySubtitleText]];
    [textLayer setForegroundColor:CGColorGetConstantColor(kCGColorWhite)];
    [textLayer setFontSize:36.0];
    [textLayer setFont:[NSFont fontWithName:@"Helvetica" size:36.0]];
    [textLayer setAlignmentMode:kCAAlignmentCenter];
    newFrame = [sublayer frame];
    newFrame.origin.y = (newFrame.size.height - [textLayer preferredFrameSize].height) / 2.0;  // NSMidY(newFrame) - ([textLayer preferredFrameSize].height / 2.0);
    newFrame.size.height = [textLayer preferredFrameSize].height;
    [textLayer setFrame:newFrame];
    [textLayer setAutoresizingMask:kCALayerWidthSizable];
    
    [sublayer addSublayer:textLayer];
    [containerLayer addSublayer:sublayer];
    
    // Keyframe Animation
    [subtitlePositions addObject:[NSValue valueWithPoint:NSMakePoint(0.0, (NSInteger)(subtitleAreaHeight * index) * -1)]];
    [subtitleTimes addObject:[NSNumber numberWithFloat:keyframeTimeForTimeString([[subtitles objectAtIndex:index] valueForKey:kDictionaryKeySubtitleTimecode], [[[[self player] currentItem] asset] duration])]];
  }

  // Final keyframe animation elements
  [subtitlePositions addObject:[NSValue valueWithPoint:NSMakePoint(0.0, (NSInteger)(subtitleAreaHeight * [subtitles count]) * -1)]];
  [subtitleTimes addObject:[NSNumber numberWithFloat:1.0]];

  CAKeyframeAnimation *anim = [CAKeyframeAnimation animationWithKeyPath:@"position"];
  [anim setBeginTime:AVCoreAnimationBeginTimeAtZero];
  [anim setDuration:timeValueForCMTime([[[[self player] currentItem] asset] duration])];
  [anim setValues:subtitlePositions];
  [anim setKeyTimes:subtitleTimes];
  [anim setCalculationMode:kCAAnimationDiscrete];
  [containerLayer addAnimation:anim forKey:@"scrolling"];
  
  [subtitlePositions release], subtitlePositions = nil;
  [subtitleTimes release], subtitleTimes = nil;
  
  [scrollLayer addSublayer:containerLayer];
  [newSyncLayer addSublayer:scrollLayer];
  [[[[self window] contentView] layer] insertSublayer:newSyncLayer above:[self playerLayer]];
}

@end
