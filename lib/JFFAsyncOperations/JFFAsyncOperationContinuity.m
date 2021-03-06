#import "JFFAsyncOperationContinuity.h"

#import "JFFCancelAsyncOperationBlockHolder.h"
#import "JFFAsyncOperationsPredefinedBlocks.h"
#import "NSError+ResultOwnerships.h"

#include <assert.h>

#import "JFFAsyncOperationHelpers.h"

typedef JFFAsyncOperationBinder (*MergeTwoBindersPtr)( JFFAsyncOperationBinder, JFFAsyncOperationBinder );
typedef JFFAsyncOperation (*MergeTwoLoadersPtr)( JFFAsyncOperation, JFFAsyncOperation );

static JFFAsyncOperationBinder MergeBinders( MergeTwoBindersPtr merger_, NSArray* blocks_ )
{
    assert( [ blocks_ lastObject ] );// should not be empty

    JFFAsyncOperationBinder firstBinder_ = blocks_[ 0 ];

    for ( NSUInteger index_ = 1; index_ < [ blocks_ count ]; ++index_ )
    {
        JFFAsyncOperationBinder secondBinder_ = blocks_[ index_ ];
        firstBinder_ = merger_( firstBinder_, secondBinder_ );
    }

    return firstBinder_;
}

JFFAsyncOperationBinder bindSequenceOfBindersPair( JFFAsyncOperationBinder firstBinder_
                                                  , JFFAsyncOperationBinder secondBinder_ );

JFFAsyncOperationBinder bindSequenceOfBindersPair( JFFAsyncOperationBinder firstBinder_
                                                  , JFFAsyncOperationBinder secondBinder_ )
{
    assert( firstBinder_ ); // should not be nil;

    firstBinder_  = [ firstBinder_  copy ];
    secondBinder_ = [ secondBinder_ copy ];

    if ( !secondBinder_ )
        return firstBinder_;

    return ^JFFAsyncOperation( id bindResult_ )
    {
        JFFAsyncOperation firstLoader_ = firstBinder_( bindResult_ );
        assert( firstLoader_ );//expected loader
        return ^JFFCancelAsyncOperation( JFFAsyncOperationProgressHandler progressCallback_
                                        , JFFCancelAsyncOperationHandler cancelCallback_
                                        , JFFDidFinishAsyncOperationHandler doneCallback_ )
        {
            __block JFFCancelAsyncOperation cancelBlockHolder_;

            progressCallback_ = [ progressCallback_ copy ];
            doneCallback_     = [ doneCallback_     copy ];

            JFFCancelAsyncOperation firstCancel_ = firstLoader_( progressCallback_
                                                                , cancelCallback_
                                                                , ^void( id result_, NSError* error_ )
            {
                if ( error_ )
                {
                    if ( doneCallback_ )
                        doneCallback_( nil, error_ );
                }
                else
                {
                    JFFAsyncOperation secondLoader_ = secondBinder_( result_ );
                    assert( secondLoader_ );//result loader should not be nil
                    cancelBlockHolder_ = secondLoader_( progressCallback_
                                                       , cancelCallback_
                                                       , doneCallback_ );
                }
            } );
            if ( !cancelBlockHolder_ )
                cancelBlockHolder_ = firstCancel_;

            return ^( BOOL canceled_ )
            {
                if ( !cancelBlockHolder_ )
                    return;
                cancelBlockHolder_( canceled_ );
                cancelBlockHolder_ = nil;
            };
        };
    };
}

JFFAsyncOperation sequenceOfAsyncOperations( JFFAsyncOperation firstLoader_
                                            , JFFAsyncOperation secondLoader_
                                            , ... )
{
    firstLoader_ = [ firstLoader_ copy ];
    JFFAsyncOperationBinder firstBlock_ = ^JFFAsyncOperation( id result_ )
    {
        return firstLoader_;
    };

    va_list args;
    va_start( args, secondLoader_ );
    for ( JFFAsyncOperation secondBlock_ = secondLoader_;
         secondBlock_ != nil;
         secondBlock_ = va_arg( args, JFFAsyncOperation ) )
    {
        secondBlock_ = [ secondBlock_ copy ];
        JFFAsyncOperationBinder secondBlockBinder_ = ^JFFAsyncOperation( id result_ )
        {
            return secondBlock_;
        };
        firstBlock_ = bindSequenceOfBindersPair( firstBlock_, secondBlockBinder_ );
    }
    va_end( args );

    return firstBlock_( nil );
}

JFFAsyncOperation sequenceOfAsyncOperationsArray( NSArray* loaders_ )
{
    assert( loaders_.lastObject ); //should not be empty
    loaders_ = [ loaders_ map: ^id( id object_ )
    {
        JFFAsyncOperation loader_ = [ object_ copy ];
        return ^JFFAsyncOperation( id result_ )
        {
            return loader_;
        };
    } ];
    return MergeBinders( bindSequenceOfBindersPair, loaders_ )( nil );
}

JFFAsyncOperationBinder binderAsSequenceOfBinders( JFFAsyncOperationBinder firstBinder_, ... )
{
    va_list args;
    va_start( args, firstBinder_ );
    for ( JFFAsyncOperationBinder secondBinder_ = va_arg( args, JFFAsyncOperationBinder );
         secondBinder_ != nil;
         secondBinder_ = va_arg( args, JFFAsyncOperationBinder ) )
    {
        firstBinder_ = bindSequenceOfBindersPair( firstBinder_, secondBinder_ );
    }
    va_end( args );

    return firstBinder_;
}

JFFAsyncOperationBinder binderAsSequenceOfBindersArray( NSArray* binders_ )
{
    binders_ = [ binders_ map: ^id( id object_ )
    {
        return [ object_ copy ];
    } ];
    return MergeBinders( bindSequenceOfBindersPair, binders_ );
}

JFFAsyncOperation bindSequenceOfAsyncOperations( JFFAsyncOperation firstLoader_
                                                , JFFAsyncOperationBinder secondLoaderBinder_, ... )
{
    NSMutableArray* binders_ = [ NSMutableArray new ];

    firstLoader_ = [ firstLoader_ copy ];
    JFFAsyncOperationBinder firstBinder_ = ^JFFAsyncOperation( id nilResult_ )
    {
        return firstLoader_;
    };
    [ binders_ addObject: [ firstBinder_ copy ] ];

    va_list args;
    va_start( args, secondLoaderBinder_ );
    for ( JFFAsyncOperationBinder nextBinder_ = secondLoaderBinder_;
         nextBinder_ != nil;
         nextBinder_ = va_arg( args, JFFAsyncOperationBinder ) )
    {
        [ binders_ addObject: [ nextBinder_ copy ] ];
    }
    va_end( args );

    return binderAsSequenceOfBindersArray( binders_ )( nil );
}

JFFAsyncOperation bindSequenceOfAsyncOperationsArray( JFFAsyncOperation firstLoader_
                                                     , NSArray* loadersBinders_ )
{
    NSUInteger size_ = [ loadersBinders_ count ] + 1;
    NSMutableArray* binders_ = [ [ NSMutableArray alloc ] initWithCapacity: size_ ];

    firstLoader_ = [ firstLoader_ copy ];
    JFFAsyncOperationBinder firstBinder_ = ^JFFAsyncOperation( id nilResult_ )
    {
        return firstLoader_;
    };
    [ binders_ addObject: [ firstBinder_ copy ] ];

     for ( JFFAsyncOperation binder_ in loadersBinders_ )
     {
         [ binders_ addObject: [ binder_ copy ] ];
     }

    return binderAsSequenceOfBindersArray( binders_ )( nil );
}

static JFFAsyncOperationBinder bindTrySequenceOfBindersPair( JFFAsyncOperationBinder firstBinder_
                                                            , JFFAsyncOperationBinder secondBinder_ )
{
    assert( firstBinder_ ); // firstLoader_ should not be nil

    firstBinder_  = [ firstBinder_  copy ];
    secondBinder_ = [ secondBinder_ copy ];

    if ( secondBinder_ == nil )
        return firstBinder_;

    return ^JFFAsyncOperation( id data_ )
    {
        JFFAsyncOperation firstLoader_ = firstBinder_( data_ );

        return ^JFFCancelAsyncOperation( JFFAsyncOperationProgressHandler progressCallback_
                                        , JFFCancelAsyncOperationHandler cancelCallback_
                                        , JFFDidFinishAsyncOperationHandler doneCallback_ )
        {
            __block JFFCancelAsyncOperation cancelBlockHolder_;

            doneCallback_ = [ doneCallback_ copy ];

            JFFCancelAsyncOperation firstCancel_ = firstLoader_( progressCallback_
                                                                 , cancelCallback_
                                                                 , ^void( id result_, NSError* error_ )
            {
                if ( error_ )
                {
                    JFFAsyncOperation secondLoader_ = secondBinder_( error_ );
                    cancelBlockHolder_ = secondLoader_( progressCallback_, cancelCallback_, doneCallback_ );
                }
                else
                {
                    if ( doneCallback_ )
                        doneCallback_( result_, nil );
                }
            } );
            if ( !cancelBlockHolder_ )
                cancelBlockHolder_ = firstCancel_;

            return ^( BOOL canceled_ )
            {
                if ( !cancelBlockHolder_ )
                    return;
                cancelBlockHolder_( canceled_ );
                cancelBlockHolder_ = nil;
            };
        };
    };
}

JFFAsyncOperation trySequenceOfAsyncOperations( JFFAsyncOperation firstLoader_
                                               , JFFAsyncOperation secondLoader_, ... )
{
    firstLoader_ = [ firstLoader_ copy ];
    JFFAsyncOperationBinder firstBlock_ = ^JFFAsyncOperation( id data_ )
    {
        return firstLoader_;
    };

    va_list args;
    va_start( args, secondLoader_ );
    for ( JFFAsyncOperation secondBlock_ = secondLoader_;
         secondBlock_ != nil;
         secondBlock_ = va_arg( args, JFFAsyncOperation ) )
    {
        secondBlock_ = [ secondBlock_ copy ];
        JFFAsyncOperationBinder secondBlockBinder_ = ^JFFAsyncOperation( id result_ )
        {
            return secondBlock_;
        };
        firstBlock_ = bindTrySequenceOfBindersPair( firstBlock_, secondBlockBinder_ );
    }
    va_end( args );

    return firstBlock_( nil );
}

JFFAsyncOperation trySequenceOfAsyncOperationsArray( NSArray* loaders_ )
{
    assert( [ loaders_ count ] != 0 );

    NSArray* binders_ = [ loaders_ map: ^id( id loader_ )
    {
        loader_ = [ loader_ copy ];
        return ^JFFAsyncOperation( id data_ )
        {
            return loader_;
        };
    } ];

    return MergeBinders( bindTrySequenceOfBindersPair, binders_ )( nil );
}

JFFAsyncOperation bindTrySequenceOfAsyncOperations( JFFAsyncOperation firstLoader_
                                                   , JFFAsyncOperationBinder secondLoaderBinder_, ... )
{
    firstLoader_ = [ firstLoader_ copy ];
    JFFAsyncOperationBinder firstBlock_ = ^JFFAsyncOperation( id data_ )
    {
        return firstLoader_;
    };

    va_list args;
    va_start( args, secondLoaderBinder_ );
    for ( JFFAsyncOperationBinder secondBlockBinder_ = secondLoaderBinder_;
         secondBlockBinder_ != nil;
         secondBlockBinder_ = va_arg( args, JFFAsyncOperationBinder ) )
    {
        firstBlock_ = bindTrySequenceOfBindersPair( firstBlock_, secondBlockBinder_ );
    }
    va_end( args );

    return firstBlock_( nil );
}

JFFAsyncOperation bindTrySequenceOfAsyncOperationsArray( JFFAsyncOperation firstLoader_, NSArray* loadersBinders_ )
{
    NSMutableArray* binders_ = [ [ NSMutableArray alloc ] initWithCapacity: [ loadersBinders_ count ] ];

    firstLoader_ = [ firstLoader_ copy ];
    JFFAsyncOperationBinder firstBinder_ = ^JFFAsyncOperation( id data_ )
    {
        return firstLoader_;
    };
    [ binders_ addObject: [ firstBinder_ copy ] ];

    for ( JFFAsyncOperation binder_ in loadersBinders_ )
    {
        [ binders_ addObject: [ binder_ copy ] ];
    }

    return MergeBinders( bindTrySequenceOfBindersPair, binders_ )( nil );
}

static void notifyGroupResult( JFFDidFinishAsyncOperationHandler doneCallback_
                              , NSArray* complexResult_
                              , NSError* error_ )
{
    if ( !doneCallback_ )
        return;

    NSMutableArray* finalResult_ = nil;
    if ( !error_ )
    {
        NSArray* firstResult_ = complexResult_[ 0 ];
        finalResult_ = [ [ NSMutableArray alloc ] initWithCapacity: [ firstResult_ count ] + 1 ];
        [ finalResult_ addObjectsFromArray: firstResult_ ];
        [ finalResult_ addObject: complexResult_[ 1 ] ];
    }
    doneCallback_( finalResult_, error_ );
}

static JFFAsyncOperation groupOfAsyncOperationsPair( JFFAsyncOperation firstLoader_
                                                    , JFFAsyncOperation secondLoader_ )
{
    assert( firstLoader_ );//do not pass nil

    firstLoader_  = [ firstLoader_  copy ];
    secondLoader_ = [ secondLoader_ copy ];

    if ( secondLoader_ == nil )
        return firstLoader_;

    return ^JFFCancelAsyncOperation( JFFAsyncOperationProgressHandler progressCallback_
                                    , JFFCancelAsyncOperationHandler cancelCallback_
                                    , JFFDidFinishAsyncOperationHandler doneCallback_ )
    {
        __block BOOL loaded_ = NO;
        __block NSError* errorHolder_;

        NSMutableArray* complexResult_ = [ @[ [ NSNull null ], [ NSNull null ] ] mutableCopy ];

        doneCallback_ = [ doneCallback_ copy ];

        JFFDidFinishAsyncOperationHandler (^makeResultHandler_)( NSUInteger ) =
            ^JFFDidFinishAsyncOperationHandler( NSUInteger index_ )
        {
            return ^void( id result_, NSError* error_ )
            {
                if ( result_ )
                    complexResult_[ index_ ] = result_;

                if ( loaded_ )
                {
                    error_ = error_ ? error_ : errorHolder_;

                    if ( result_ )
                        [ error_.lazyResultOwnerships addObject: result_ ];

                    if ( errorHolder_ && error_ != errorHolder_ && errorHolder_.resultOwnerships )
                    {
                        [ error_.lazyResultOwnerships addObject: errorHolder_.resultOwnerships ];
                        errorHolder_.resultOwnerships = nil;
                    }

                    notifyGroupResult( doneCallback_, complexResult_, error_ );
                    error_.resultOwnerships = nil;

                    return;
                }
                loaded_ = YES;

                errorHolder_ = [ error_ copy ];
                errorHolder_.resultOwnerships = error_.resultOwnerships;
            };
        };

        __block BOOL blockCanceled_ = NO;

        cancelCallback_ = [ cancelCallback_ copy ];
        JFFCancelAsyncOperationHandler (^makeCancelHandler_)( JFFCancelAsyncOperationBlockHolder* ) =
            ^( JFFCancelAsyncOperationBlockHolder* cancelHolder_ )
        {
            return ^void( BOOL canceled_ )
            {
                if ( !blockCanceled_ )
                {
                    blockCanceled_ = YES;
                    cancelHolder_.onceCancelBlock( canceled_ );
                    if ( cancelCallback_ )
                        cancelCallback_( canceled_ );
                }
            };
        };

        JFFDidFinishAsyncOperationHandler (^makeFinishHandler_)( JFFCancelAsyncOperationBlockHolder*, NSUInteger ) =
            ^JFFDidFinishAsyncOperationHandler( JFFCancelAsyncOperationBlockHolder* cancelHolder_
                                               , NSUInteger index_ )
        {
            JFFDidFinishAsyncOperationHandler handler_ = makeResultHandler_( index_ );
            return ^void( id result_, NSError* error_ )
            {
                cancelHolder_.cancelBlock = nil;
                handler_( result_, error_ );
            };
        };

        JFFCancelAsyncOperationBlockHolder* cancelHolder1_ = [ JFFCancelAsyncOperationBlockHolder new ];
        JFFCancelAsyncOperationBlockHolder* cancelHolder2_ = [ JFFCancelAsyncOperationBlockHolder new ];

        cancelHolder1_.cancelBlock = firstLoader_( progressCallback_
                                                   , makeCancelHandler_( cancelHolder2_ )
                                                   , makeFinishHandler_( cancelHolder1_, 0 ) );
        cancelHolder2_.cancelBlock = secondLoader_( progressCallback_
                                                    , makeCancelHandler_( cancelHolder1_ )
                                                    , makeFinishHandler_( cancelHolder2_, 1 ) );

        return ^void( BOOL cancel_ )
        {
            if ( !blockCanceled_ )
            {
                blockCanceled_ = YES;
                cancelHolder1_.onceCancelBlock( cancel_ );
                cancelHolder2_.onceCancelBlock( cancel_ );
                if ( cancelCallback_ )
                    cancelCallback_( cancel_ );
            }
        };
    };
}

static JFFAsyncOperation resultToArrayForLoader( JFFAsyncOperation loader_ )
{
    JFFAsyncOperationBinder secondLoaderBinder_ = asyncOperationBinderWithAnalyzer( ^( id result_, NSError** error_ )
    {
        return @[ result_ ];
    } );
    return bindSequenceOfAsyncOperations( loader_, secondLoaderBinder_, nil );
}

static JFFAsyncOperation MergeGroupLoaders( MergeTwoLoadersPtr merger_, NSArray* blocks_ )
{
    if ( ![ blocks_ lastObject ] )
        return asyncOperationWithResult( @[] );

    JFFAsyncOperation firstBlock_ = blocks_[ 0 ];
    JFFAsyncOperation arrayFirstBlock_ = resultToArrayForLoader( firstBlock_ );

    for ( JFFAsyncOperation secondBlock_ in blocks_ )
    {
        if ( secondBlock_ == firstBlock_ )
            continue;

        arrayFirstBlock_ = merger_( arrayFirstBlock_, secondBlock_ );
    }

    return arrayFirstBlock_;
}

JFFAsyncOperation groupOfAsyncOperationsArray( NSArray* blocks_ )
{
    return MergeGroupLoaders( groupOfAsyncOperationsPair, blocks_ );
}

JFFAsyncOperation groupOfAsyncOperations( JFFAsyncOperation firstLoader_, ... )
{
    NSMutableArray* loaders_ = [ NSMutableArray new ];

    va_list args;
    va_start( args, firstLoader_ );
    for ( JFFAsyncOperation nextBlock_ = firstLoader_;
         nextBlock_ != nil;
         nextBlock_ = va_arg( args, JFFAsyncOperation ) )
    {
        [ loaders_ addObject: [ nextBlock_ copy ] ];
    }
    va_end( args );

    return groupOfAsyncOperationsArray( loaders_ );
}

static JFFDidFinishAsyncOperationHandler cancelSafeResultBlock( JFFDidFinishAsyncOperationHandler resultBlock_
                                                               , JFFCancelAsyncOperationBlockHolder* cancelHolder_ )
{
    resultBlock_ = [ resultBlock_ copy ];
    return ^void( id result_, NSError* error_ )
    {
        cancelHolder_.cancelBlock = nil;
        resultBlock_( result_, error_ );
    };
}

static JFFAsyncOperation failOnFirstErrorGroupOfAsyncOperationsPair( JFFAsyncOperation firstLoader_
                                                                    , JFFAsyncOperation secondLoader_ )
{
    assert( firstLoader_ );//do not pass nil

    firstLoader_  = [ firstLoader_  copy ];
    secondLoader_ = [ secondLoader_ copy ];

    if ( secondLoader_ == nil )
        return firstLoader_;

    return ^JFFCancelAsyncOperation( JFFAsyncOperationProgressHandler progressCallback_
                                    , JFFCancelAsyncOperationHandler cancelCallback_
                                    , JFFDidFinishAsyncOperationHandler doneCallback_ )
    {
        __block BOOL loaded_ = NO;

        JFFCancelAsyncOperationBlockHolder* cancelHolder1_ = [ JFFCancelAsyncOperationBlockHolder new ];
        JFFCancelAsyncOperationBlockHolder* cancelHolder2_ = [ JFFCancelAsyncOperationBlockHolder new ];

        cancelCallback_ = [ cancelCallback_ copy ];
        __block JFFCancelAsyncOperationHandler cancelCallbackHolder_ = [ ^( BOOL canceled_ )
        {
            if ( cancelCallback_ )
                cancelCallback_( canceled_ );
        } copy ];// "cancelCallbackHolder_" used as flag for done

        NSMutableArray* complexResult_ = [ @[ [ NSNull null ], [ NSNull null ] ] mutableCopy ];

        doneCallback_ = [ doneCallback_ copy ];
        JFFDidFinishAsyncOperationHandler (^makeResultHandler_)( NSUInteger ) =
            ^JFFDidFinishAsyncOperationHandler( NSUInteger index_ )
        {
            return ^void( id result_, NSError* error_ )
            {
                if ( result_ )
                    complexResult_[ index_ ] = result_;
                BOOL firstError_ = error_ && cancelCallbackHolder_;
                if ( loaded_ || firstError_ )
                {
                    cancelCallbackHolder_ = nil;

                    if ( firstError_ )
                    {
                        cancelHolder1_.onceCancelBlock( YES );
                        cancelHolder2_.onceCancelBlock( YES );
                    }

                    notifyGroupResult( doneCallback_, complexResult_, error_ );
                    return;
                }
                loaded_ = YES;
            };
        };

        JFFCancelAsyncOperationHandler (^makeCancelCallback_)( JFFCancelAsyncOperationBlockHolder* ) =
        ^( JFFCancelAsyncOperationBlockHolder* cancelHolder_ )
        {
            return ^void( BOOL canceled_ )
            {
                if ( cancelCallbackHolder_ )
                {
                    cancelHolder_.onceCancelBlock( canceled_ );
                    if ( cancelCallbackHolder_ )
                    {
                        cancelCallbackHolder_( canceled_ );
                        cancelCallbackHolder_ = nil;
                    }
                }
            };
        };

        JFFCancelAsyncOperation cancel1_ = firstLoader_( progressCallback_
                                                        , makeCancelCallback_( cancelHolder2_ )
                                                        , cancelSafeResultBlock( makeResultHandler_( 0 )
                                                                                , cancelHolder1_ ) );

        cancelHolder1_.cancelBlock = !cancelCallbackHolder_ ? JFFStubCancelAsyncOperationBlock : cancel1_;

        JFFCancelAsyncOperation cancel2_ = cancelCallbackHolder_ == nil
            ? JFFStubCancelAsyncOperationBlock
            : secondLoader_( progressCallback_
                             , makeCancelCallback_( cancelHolder1_ )
                             , cancelSafeResultBlock( makeResultHandler_( 1 )
                                                     , cancelHolder2_ ) );

        cancelHolder2_.cancelBlock = !cancelCallbackHolder_ ? JFFStubCancelAsyncOperationBlock : cancel2_;

        return ^void( BOOL cancel_ )
        {
            if ( cancelCallbackHolder_ )
            {
                JFFCancelAsyncOperationHandler tmpCancelCallback_ = [ cancelCallbackHolder_ copy ];
                cancelCallbackHolder_ = nil;

                cancelHolder1_.onceCancelBlock( cancel_ );
                cancelHolder2_.onceCancelBlock( cancel_ );

                tmpCancelCallback_( cancel_ );
            }
        };
    };
}

JFFAsyncOperation failOnFirstErrorGroupOfAsyncOperations( JFFAsyncOperation firstLoader_
                                                         , ... )
{
    NSMutableArray* loaders_ = [ NSMutableArray new ];

    va_list args;
    va_start( args, firstLoader_ );
    for ( JFFAsyncOperation nextBlock_ = firstLoader_;
         nextBlock_ != nil;
         nextBlock_ = va_arg( args, JFFAsyncOperation ) )
    {
        [ loaders_ addObject: [ nextBlock_ copy ] ];
    }
    va_end( args );

    return failOnFirstErrorGroupOfAsyncOperationsArray( loaders_ );
}

JFFAsyncOperation failOnFirstErrorGroupOfAsyncOperationsArray( NSArray* blocks_ )
{
    return MergeGroupLoaders( failOnFirstErrorGroupOfAsyncOperationsPair, blocks_ );
}

JFFAsyncOperation asyncOperationWithDoneBlock( JFFAsyncOperation loader_
                                              , JFFSimpleBlock doneCallbackHook_ )
{
    loader_ = [ loader_ copy ];
    if ( nil == doneCallbackHook_ )
        return loader_;

    doneCallbackHook_ = [ doneCallbackHook_ copy ];
    return ^JFFCancelAsyncOperation( JFFAsyncOperationProgressHandler progressCallback_
                                    , JFFCancelAsyncOperationHandler cancelCallback_
                                    , JFFDidFinishAsyncOperationHandler doneCallback_ )
    {
        cancelCallback_ = [ cancelCallback_ copy ];
        JFFCancelAsyncOperationHandler wrappedCancelCallback_ = ^void( BOOL canceled_ )
        {
            doneCallbackHook_();

            if ( cancelCallback_ )
                cancelCallback_( canceled_ );
        };

        doneCallback_ = [ doneCallback_ copy ];
        JFFDidFinishAsyncOperationHandler wrappedDoneCallback_ = ^void( id result_, NSError* error_ )
        {
            doneCallbackHook_();

            if ( doneCallback_ )
                doneCallback_( result_, error_ );
        };
        return loader_( progressCallback_, wrappedCancelCallback_, wrappedDoneCallback_ );
    };
}

JFFAsyncOperation repeatAsyncOperation( JFFAsyncOperation nativeLoader_
                                       , JFFResultPredicateBlock predicate_
                                       , NSTimeInterval delay_
                                       , NSInteger maxRepeatCount_ )
{
    assert( nativeLoader_ );// can not be nil
    assert( predicate_    );// can not be nil

    nativeLoader_ = [ nativeLoader_ copy ];
    predicate_    = [ predicate_    copy ];

    return ^JFFCancelAsyncOperation( JFFAsyncOperationProgressHandler progressCallback_
                                    , JFFCancelAsyncOperationHandler cancelCallback_
                                    , JFFDidFinishAsyncOperationHandler doneCallback_ )
    {
        progressCallback_ = [ progressCallback_ copy ];
        cancelCallback_   = [ cancelCallback_   copy ];
        doneCallback_     = [ doneCallback_     copy ];

        __block JFFCancelAsyncOperation cancelBlockHolder_;

        __block JFFDidFinishAsyncOperationHook finishHookHolder_ = nil;

        __block NSInteger currentLeftCount_ = maxRepeatCount_;

        JFFDidFinishAsyncOperationHook finishCallbackHook_ = ^( id result_
                                                                 , NSError* error_
                                                                 , JFFDidFinishAsyncOperationHandler doneCallback_ )
        {
            if ( !predicate_( result_, error_ ) || currentLeftCount_ == 0 )
            {
                finishHookHolder_ = nil;
                if ( doneCallback_ )
                    doneCallback_( result_, error_ );
            }
            else
            {
                currentLeftCount_ = currentLeftCount_ > 0
                    ? currentLeftCount_ - 1
                    : currentLeftCount_;

                JFFAsyncOperation loader_ = asyncOperationWithFinishHookBlock( nativeLoader_
                                                                              , finishHookHolder_ );
                loader_ = asyncOperationAfterDelay( delay_, loader_ );

                cancelBlockHolder_ = loader_( progressCallback_, cancelCallback_, doneCallback_ );
            }
        };

        finishHookHolder_ = [ finishCallbackHook_ copy ];

        JFFAsyncOperation loader_ = asyncOperationWithFinishHookBlock( nativeLoader_
                                                                      , finishHookHolder_ );

        cancelBlockHolder_ = loader_( progressCallback_, cancelCallback_, doneCallback_ );

        return ^( BOOL canceled_ )
        {
            finishHookHolder_ = nil;

            if ( !cancelBlockHolder_ )
                return;
            cancelBlockHolder_( canceled_ );
            cancelBlockHolder_ = nil;
        };
    };
}

JFFAsyncOperation asyncOperationAfterDelay( NSTimeInterval delay_
                                           , JFFAsyncOperation loader_ )
{
    return sequenceOfAsyncOperations( asyncOperationWithDelay( delay_ )
                                     , loader_
                                     , nil );
}
