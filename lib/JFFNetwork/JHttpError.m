#import "JHttpError.h"

@implementation JHttpError

-(id)initWithDescription:( NSString* )description_
                    code:( NSInteger )code_
{
    return [ self initWithDescription: description_
                               domain: @"com.just_for_fun.library.http"
                                 code: code_ ];
}

-(id)initWithHttpCode:( CFIndex )statusCode_
{
    return [ self initWithDescription: NSLocalizedString( @"JFF_HTTP_ERROR", nil )
                                 code: statusCode_ ];
}

@end
