/*
 * For license terms please visit http://www.ottersoftwareblog.com/source-code-license/
 */

#import "OTSTimeMethods.h"
#import <CoreMedia/CoreMedia.h>

CGFloat keyframeTimeForTimeString(NSString* timeString, CMTime duration)
{
  CGFloat timeValue = timeValueForTimeString(timeString);
  CGFloat durationValue = timeValueForCMTime(duration);
  
  return (1.0 / durationValue) * timeValue;
}

CGFloat timeValueForTimeString(NSString* timeString)
{
  CGFloat hours = [[timeString substringWithRange:NSMakeRange(0, 2)] floatValue];
  CGFloat minutes = [[timeString substringWithRange:NSMakeRange(3, 2)] floatValue];
  CGFloat seconds = [[timeString substringWithRange:NSMakeRange(6, 2)] floatValue];
  CGFloat thousands = [[timeString substringWithRange:NSMakeRange(9, 3)] floatValue] / 1000;
  return (hours * (60 * 60)) + (minutes * 60) + seconds + thousands;
}

CGFloat timeValueForCMTime(CMTime time)
{
  return CMTIME_IS_INVALID(time) ? 0.0f : CMTimeGetSeconds(time);
}
