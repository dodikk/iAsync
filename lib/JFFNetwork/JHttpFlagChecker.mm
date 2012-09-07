#import "JHttpFlagChecker.h"

#include <set>

@implementation JHttpFlagChecker

+(BOOL)isDownloadErrorFlag:( CFIndex )statusCode_
{
    BOOL result_ =
        ![ self isSuccessFlag : statusCode_ ] &&
        ![ self isRedirectFlag: statusCode_ ];
    
    return result_;
}

+(BOOL)isRedirectFlag:( CFIndex )statusCode_
{
    std::set<CFIndex> redirectFlags_;
    {
        redirectFlags_.insert( 301 );
        redirectFlags_.insert( 302 );
        redirectFlags_.insert( 303 );
        redirectFlags_.insert( 307 );
    };
    auto iFlag_ = redirectFlags_.find( statusCode_ );
    
    BOOL result_ = ( redirectFlags_.end() != iFlag_ );
    return result_;
}

+(BOOL)isSuccessFlag:( CFIndex )statusCode_
{
    return ( 200 == statusCode_ );
}

@end
