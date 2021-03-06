#import <JFFUtils/NSObject/NSObject+RuntimeExtensions.h>

#include <objc/message.h>

static const NSUInteger testClassMethodResult_ = 34;//just rendomize number
static const NSUInteger testInstanceMethodResult_ = 35;//just rendomize number

@interface NSTestClass : NSObject
@end

@implementation NSTestClass

+(id)allocWithZone:( NSZone* )zone_
{
    return [ super allocWithZone: zone_ ];
}

-(BOOL)isEqual:( id )object_
{
    return [ super isEqual: object_ ];
}

+(NSUInteger)classMethodWithLongNameForUniquenessPurposes
{
    return testClassMethodResult_;
}

-(NSUInteger)instanceMethodWithLongNameForUniquenessPurposes
{
    return testInstanceMethodResult_;
}

@end

@interface NSTwiceTestClass : NSObject
@end

@implementation NSTwiceTestClass

+(id)allocWithZone:( NSZone* )zone_
{
    return [ super allocWithZone: zone_ ];
}

-(BOOL)isEqual:( id )object_
{
    return [ super isEqual: object_ ];
}

+(NSUInteger)classMethodWithLongNameForUniquenessPurposes
{
    return testClassMethodResult_;
}

-(NSUInteger)instanceMethodWithLongNameForUniquenessPurposes
{
    return testInstanceMethodResult_;
}

@end

@interface HookMethodsClass : NSObject
@end

@implementation HookMethodsClass

-(NSUInteger)hookMethod
{
    [ self doesNotRecognizeSelector: _cmd ];
    return 0;
}

-(NSUInteger)prototypeMethod
{
    return [ self hookMethod ] * 2;
}

+(NSUInteger)hookMethod
{
    [ self doesNotRecognizeSelector: _cmd ];
    return 0;
}

+(NSUInteger)prototypeMethod
{
    return [ self hookMethod ] * 3;
}

@end

@interface TwiceHookMethodsClass : NSObject
@end

@implementation TwiceHookMethodsClass

-(NSUInteger)twiceHookMethod
{
    [ self doesNotRecognizeSelector: _cmd ];
    return 0;
}

-(NSUInteger)twicePrototypeMethod
{
    return [ self twiceHookMethod ] * 2;
}

+(NSUInteger)twiceHookMethod
{
    [ self doesNotRecognizeSelector: _cmd ];
    return 0;
}

+(NSUInteger)twicePrototypeMethod
{
    return [ self twiceHookMethod ] * 3;
}

@end

@interface NSObjectRuntimeExtensionsTest : GHTestCase
@end

@implementation NSObjectRuntimeExtensionsTest

-(void)testHookInstanceMethodAssertPrototypeAndTargetSelectors
{
    GHAssertThrows(
    {
        [ [ HookMethodsClass class ] hookInstanceMethodForClass: [ NSTestClass class ]
                                                   withSelector: @selector( instanceMethodWithLongNameForUniquenessPurposes )
                                        prototypeMethodSelector: @selector( instanceMethodWithLongNameForUniquenessPurposes )
                                             hookMethodSelector: @selector( hookMethod ) ];
    }, @"no prototypeMethodSelector asert expected" );

    GHAssertThrows(
    {
        [ [ HookMethodsClass class ] hookInstanceMethodForClass: [ NSTestClass class ]
                                                   withSelector: @selector( instanceMethodWithLongNameForUniquenessPurposes2 )
                                        prototypeMethodSelector: @selector( prototypeMethod )
                                             hookMethodSelector: @selector( hookMethod ) ];
    }, @"no target selector asert expected" );
}

-(void)testHookInstanceMethod
{
    static BOOL firstTestRun_ = YES;

    if ( !firstTestRun_ )
        return;

    NSTestClass* instance_ = [ NSTestClass new ];

    GHAssertEquals( testInstanceMethodResult_
                   , [ instance_ instanceMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );

    [ [ HookMethodsClass class ] hookInstanceMethodForClass: [ NSTestClass class ]
                                               withSelector: @selector( instanceMethodWithLongNameForUniquenessPurposes )
                                    prototypeMethodSelector: @selector( prototypeMethod )
                                         hookMethodSelector: @selector( hookMethod ) ];

    GHAssertEquals( testInstanceMethodResult_ * 2
                   , [ instance_ instanceMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );
}

-(void)testHookClassMethodAssertPrototypeAndTargetSelectors
{
    GHAssertThrows(
    {
        [ [ HookMethodsClass class ] hookClassMethodForClass: [ NSTestClass class ]
                                                withSelector: @selector( classMethodWithLongNameForUniquenessPurposes )
                                     prototypeMethodSelector: @selector( classMethodWithLongNameForUniquenessPurposes )
                                          hookMethodSelector: @selector( hookMethod ) ];
    }, @"no prototypeMethodSelector asert expected" );

    GHAssertThrows(
    {
        [ [ HookMethodsClass class ] hookClassMethodForClass: [ NSTestClass class ]
                                                withSelector: @selector( classMethodWithLongNameForUniquenessPurposes2 )
                                     prototypeMethodSelector: @selector( prototypeMethod )
                                          hookMethodSelector: @selector( hookMethod ) ];
    }, @"no target selector asert expected" );
}

-(void)testHookClassMethod
{
    static BOOL firstTestRun_ = YES;

    if ( !firstTestRun_ )
        return;

    Class class_ = [ NSTestClass class ];

    GHAssertEquals( testClassMethodResult_
                   , [ class_ classMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );

    [ [ HookMethodsClass class ] hookClassMethodForClass: [ NSTestClass class ]
                                            withSelector: @selector( classMethodWithLongNameForUniquenessPurposes )
                                 prototypeMethodSelector: @selector( prototypeMethod )
                                      hookMethodSelector: @selector( hookMethod ) ];

    GHAssertEquals( testClassMethodResult_ * 3
                   , [ class_ classMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );
}

-(void)testHasClassMethodWithSelector
{
    GHAssertTrue( [ NSObject hasClassMethodWithSelector: @selector( allocWithZone: ) ], @"NSOBject has allocWithZone: method" );
    GHAssertFalse( [ NSObject hasClassMethodWithSelector: @selector( allocWithZone2: ) ], @"NSOBject has no allocWithZone2: method" );

    GHAssertTrue( [ NSTestClass hasClassMethodWithSelector: @selector( allocWithZone: ) ]
                 , @"NSTestClass has allocWithZone: method" );
    GHAssertFalse( [ NSTestClass hasClassMethodWithSelector: @selector( alloc ) ]
                  , @"NSTestClass has no alloc method" );
}

-(void)testHasInstanceMethodWithSelector
{
    GHAssertTrue( [ NSObject hasInstanceMethodWithSelector: @selector( isEqual: ) ], @"NSOBject has isEqual: method" );
    GHAssertFalse( [ NSObject hasInstanceMethodWithSelector: @selector( isEqual2: ) ], @"NSOBject has no isEqual2: method" );

    GHAssertTrue( [ NSTestClass hasInstanceMethodWithSelector: @selector( isEqual: ) ]
                 , @"NSTestClass has isEqual: method" );
    GHAssertFalse( [ NSTestClass hasInstanceMethodWithSelector: @selector( description ) ]
                  , @"NSTestClass has no description method" );
}

-(void)testAddClassMethodIfNeedWithSelector
{
    static BOOL firstTestRun_ = YES;

    if ( firstTestRun_ )
    {
        BOOL result_ = [ NSTestClass addClassMethodIfNeedWithSelector: @selector( classMethodWithLongNameForUniquenessPurposes )
                                                              toClass: [ NSTestClass class ]
                                                    newMethodSelector: @selector( classMethodWithLongNameForUniquenessPurposes2 ) ];

        GHAssertTrue( result_, @"method added" );

        GHAssertTrue( [ NSTestClass hasClassMethodWithSelector: @selector( classMethodWithLongNameForUniquenessPurposes2 ) ]
                     , @"NSTestClass has classMethodWithLongNameForUniquenessPurposes2 method" );

        NSUInteger method_result_ = (NSUInteger)objc_msgSend( [ NSTestClass class ], @selector( classMethodWithLongNameForUniquenessPurposes2 ) );
        GHAssertTrue( testClassMethodResult_ == method_result_, @"check implementation of new method" );

        firstTestRun_ = NO;
    }
}

-(void)testAddInstanceMethodIfNeedWithSelector
{
    static BOOL firstTestRun_ = YES;

    if ( firstTestRun_ )
    {
        SEL newMethodSelector_ = @selector( instanceMethodWithLongNameForUniquenessPurposes2 );
        SEL selector_ = @selector( instanceMethodWithLongNameForUniquenessPurposes );
        BOOL result_ = [ NSTestClass addInstanceMethodIfNeedWithSelector: selector_
                                                                 toClass: [ NSTestClass class ]
                                                       newMethodSelector: newMethodSelector_ ];

        GHAssertTrue( result_, @"method added" );

        GHAssertTrue( [ NSTestClass hasInstanceMethodWithSelector: newMethodSelector_ ]
                     , @"NSTestClass has instanceMethodWithLongNameForUniquenessPurposes2 method" );

        NSTestClass* instance_ = [ NSTestClass new ];
        NSUInteger method_result_ = (NSUInteger)objc_msgSend( instance_, newMethodSelector_ );
        GHAssertTrue( testInstanceMethodResult_ == method_result_, @"check implementation of new method" );

        firstTestRun_ = NO;
   }
}

-(void)testTwiceHookInstanceMethod
{
    static BOOL firstTestRun_ = YES;

    if ( !firstTestRun_ )
        return;

    NSTwiceTestClass* instance_ = [ NSTwiceTestClass new ];

    GHAssertEquals( testInstanceMethodResult_
                   , [ instance_ instanceMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );

    [ [ TwiceHookMethodsClass class ] hookInstanceMethodForClass: [ NSTwiceTestClass class ]
                                                    withSelector: @selector( instanceMethodWithLongNameForUniquenessPurposes )
                                         prototypeMethodSelector: @selector( twicePrototypeMethod )
                                              hookMethodSelector: @selector( twiceHookMethod ) ];

    GHAssertEquals( testInstanceMethodResult_ * 2
                   , [ instance_ instanceMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );

    GHAssertThrows(
    {
        [ [ TwiceHookMethodsClass class ] hookInstanceMethodForClass: [ NSTwiceTestClass class ]
                                                        withSelector: @selector( instanceMethodWithLongNameForUniquenessPurposes )
                                             prototypeMethodSelector: @selector( twicePrototypeMethod )
                                                  hookMethodSelector: @selector( twiceHookMethod ) ];
    }, @"twice hook forbidden" );
}

-(void)testTwiceHookClassMethod
{
    static BOOL firstTestRun_ = YES;

    if ( !firstTestRun_ )
        return;

    Class class_ = [ NSTwiceTestClass class ];

    GHAssertEquals( testClassMethodResult_
                   , [ class_ classMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );

    [ [ TwiceHookMethodsClass class ] hookClassMethodForClass: [ NSTwiceTestClass class ]
                                                 withSelector: @selector( classMethodWithLongNameForUniquenessPurposes )
                                      prototypeMethodSelector: @selector( twicePrototypeMethod )
                                           hookMethodSelector: @selector( twiceHookMethod ) ];

    GHAssertEquals( testClassMethodResult_ * 3
                   , [ class_ classMethodWithLongNameForUniquenessPurposes ]
                   , @"result mismatch" );

    GHAssertThrows(
    {
        [ [ TwiceHookMethodsClass class ] hookClassMethodForClass: [ NSTwiceTestClass class ]
                                                     withSelector: @selector( classMethodWithLongNameForUniquenessPurposes )
                                          prototypeMethodSelector: @selector( twicePrototypeMethod )
                                               hookMethodSelector: @selector( twiceHookMethod ) ];
    }, @"twice hook forbidden" );
}

@end
