#import <JFFUtils/JFFUtils.h>

@interface JHttpError : JFFError

-(id)initWithHttpCode:( CFIndex )statusCode_;

@end
