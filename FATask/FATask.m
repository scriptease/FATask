/*
 * Copyright 2011 Florian Agsteiner
 */

#import "FATask.h"

#import <Foundation/NSException.h>
#import <Foundation/NSKeyValueObserving.h>

@interface FATask (MTX)

/*[MTX]*/
/**
 * @copybrief _result
 *
 * @copydetails _result
 */
@property(nonatomic, retain, readwrite) id result;

/*[MTX]*/
/**
 * @copybrief _finished
 *
 * @copydetails _finished
 */
@property(nonatomic, assign, readwrite, getter=isFinished) BOOL finished;

/*[MTX]*/
/**
 * @copybrief _error
 *
 * @copydetails _error
 */
@property(nonatomic, retain, readwrite) NSException * error;


@end

@interface FATask ()

- (void) addContinuation:(FATask*) task;
- (void) executeContinuation:(FATask*) task;
- (void) startWithTask: (FATask*) previousTask;

@end

@implementation FATask

- (void) setQueue:(dispatch_queue_t) queue{
    if (queue != NULL) {
        dispatch_retain(queue);
    }
    if (self->_queue != NULL) {
        dispatch_release(self->_queue);
    }
    self->_queue = queue;
}

- (void) setGroup:(dispatch_group_t) group{
    if (group != NULL) {
        dispatch_retain(group);
    }
    if (self->_group != NULL) {
        dispatch_release(self->_group);
    }
    self->_group = group;
}

- (void) setPrivateQueue:(dispatch_queue_t) privateQueue{
    if (privateQueue != NULL) {
        dispatch_retain(privateQueue);
    }
    if (self->_privateQueue != NULL) {
        dispatch_release(self->_privateQueue);
    }
    self->_privateQueue = privateQueue;
}

- (void) setPrivateGroup:(dispatch_group_t) privateGroup{
    if (privateGroup != NULL) {
        dispatch_retain(privateGroup);
    }
    if (self->_privateGroup != NULL) {
        dispatch_release(self->_privateGroup);
    }
    self->_privateGroup = privateGroup;
}

+ (dispatch_queue_t) backgroundQueue{
    return dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
}

static inline void FATaskCustomDealloc(FATask* self) {
    self.privateGroup = NULL;
    self.privateQueue = NULL;
    self.queue = NULL;
    self.group = NULL;
}

- (FATask*) init{
    self = [super init];
    if (self) {
        self->_privateQueue = dispatch_queue_create(NULL, 0);
    }
    return self;
}

- (void) addContinuation:(FATask*) task{
    __block BOOL finished = NO;
    
    dispatch_safe_sync(self->_privateQueue, ^{
        if (self.finished) {
            finished = YES;
        }
        else{
            if (self->_continuations == nil) {
                self->_continuations = [NSMutableArray new];
            }
            
            [self->_continuations addObject:task];
        }
    });
    
    if (finished) {
        [self executeContinuation: task];
    }
}

- (void) executeContinuation:(FATask*) task{
    if (!self->_finished) {
        @throw [NSException exceptionWithName:@"FATaskException" reason: @"Continuation called without being finished, this should never happen!" userInfo:nil];
    }
    
    [task setResult: self.result];
    [task setError: self.error];
    
    [task startWithTask: self];
    
//    self.result = [task get];
}

- (id) executeWithTask: (FATask*) previousTask{
    [self doesNotRecognizeSelector:_cmd];
    return nil;
}

/**
 *  Run a task synchronous and return results, the previous task contains the previous result
 */
- (id) performWithTask: (FATask*) previousTask{
    @try {
        self.result = [self executeWithTask:previousTask];
    }
    @catch (NSException *exception) {
        self.error = exception;
    }
    @finally {
        
        __block NSArray* continuations = nil;
        
        [self willChangeValueForKey:@"finished"];
        
        dispatch_safe_sync(self->_privateQueue, ^{
            self->_finished = YES;

            continuations = [[self->_continuations copy] autorelease];
            [self->_continuations release];
            self->_continuations = nil;
        });
        
        [self didChangeValueForKey:@"finished"];
        
        for (FATask* task in continuations) {
            [self executeContinuation: task];
        }
    }
}

/**
 *  Run a task asynchronous and store result, the previous task contains the previous result
 */
- (void) startWithTask: (FATask*) previousTask{
    if (self->_privateGroup != nil) {
        @throw [NSException exceptionWithName:@"FATaskException" reason: @"start can not be called twice" userInfo:nil];
    }
    
    self->_privateGroup = dispatch_group_create();
    
    if (self->_group) {
        dispatch_group_enter(self->_group);
    }
    
    if (self->_queue == NULL) {
        [self performWithTask:previousTask];
    }
    else{
        dispatch_safe_group(self->_privateGroup, self->_queue, ^{
            @try {
                [self performWithTask:previousTask];
            }
            @finally {
                
                if (self->_group) {
                    dispatch_group_leave(self->_group);
                }
            }
        });
    }
}


- (void) startWithDispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group{
    self.queue = queue;
    self.group = group;
    
    [self startWithTask: self];
}

- (void) startWithDispatchQueue: (dispatch_queue_t) queue{
    self.queue = queue;

    [self startWithTask: self];
}

- (void) start{
    self.queue = [FATask backgroundQueue];

    [self startWithTask: self];
}

- (id) get{
    __block BOOL finished = NO;
    
    dispatch_safe_sync(self->_privateQueue, ^{
        if (self.finished) {
            finished = YES;
        }
    });
    
    if (!finished) {
        if (self->_privateGroup == nil) {
            [self start];
        }
        dispatch_group_wait(self->_privateGroup, DISPATCH_TIME_FOREVER);
    }

    
    if (self.error != nil) {
        @throw self.error;
    }
    
    return self.result;
}

- (void) get: (void*) buf{
    id result = [self get];
    *(id*) buf = [[result retain] autorelease];
}

+ (FATask*) startTaskWithBlock: (id (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group{
    FATask* task = [FABlockTask taskWithBlock:block];
    task.queue = queue;
    task.group = group;
    
    [task start];
    return task;
}

+ (FATask*) startTaskWithBlock: (id (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue{
    return [FATask startTaskWithBlock:block dispatchQueue:queue group:NULL];
}

+ (FATask*) startBackgroundTaskWithBlock:(id (^)(FATask* task)) block{
    return [FATask startTaskWithBlock:block dispatchQueue:[FATask backgroundQueue]];
}

+ (FATask*) startMainThreadTaskWithBlock:(id (^)(FATask* task)) block{
    return [FATask startTaskWithBlock:block dispatchQueue:dispatch_get_main_queue()];
}

- (FATask*) continueWithTask:(FATask*) nextTask dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group{
    FATask* continuation = [FABlockTask taskWithBlock:^id(FATask* task) {
        [nextTask performWithTask:task];
        task.error = nextTask.error; // keep error
        return nextTask.result;
    }]; 
    continuation.queue = queue;
    continuation.group = group;
    
    [self addContinuation: continuation];
    return self;
}

- (FATask*) continueWithTask:(FATask*) task dispatchQueue: (dispatch_queue_t) queue{
    return [self continueWithTask:task dispatchQueue:queue group:NULL];
}

- (FATask*) continueWithTask:(FATask*) task{
    return [self continueWithTask:task dispatchQueue:self->_queue group:NULL];
}

- (FATask*) continueWithBackgroundTask:(FATask*) task{
    return [self continueWithTask:task dispatchQueue:[FATask backgroundQueue]];
}

- (FATask*) continueWithMainThreadTask:(FATask*) task{
    return [self continueWithTask:task dispatchQueue:dispatch_get_main_queue()];
}

- (FATask*) continueWithBlock: (void (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue group: (dispatch_group_t) group{
    FATask* continuation = [FABlockTask taskWithBlock:^id(FATask *task) {
        block(task);
        return task.result;
    }]; 
    continuation.queue = queue;
    continuation.group = group;
    
    [self addContinuation: continuation];
    return self;
} 

- (FATask*) continueWithBlock: (void (^)(FATask* task)) block dispatchQueue: (dispatch_queue_t) queue{
    return [self continueWithBlock:block dispatchQueue:queue group:NULL];
} 

- (FATask*) continueWithBlock: (void (^)(FATask* task)) block{
    return [self continueWithBlock:block dispatchQueue:self->_queue];
} 

- (FATask*) continueWithBackgroundBlock:(void (^)(FATask* task)) block{
    return [self continueWithBlock:block dispatchQueue:[FATask backgroundQueue]];
}

- (FATask*) continueWithMainThreadBlock:(void (^)(FATask* task)) block{
    return [self continueWithBlock:block dispatchQueue:dispatch_get_main_queue()];
}

+ (void) performInBackground: (id (^)()) backgroundBlock continuation: (void (^)(id result, NSException* error)) continuation group: (dispatch_group_t) group{    
    if (backgroundBlock == nil) {
        @throw [NSException exceptionWithName:@"FATaskException" reason: @"backgroundBlock should not be nil" userInfo:nil];
    }
    
    if (continuation == nil) {
        @throw [NSException exceptionWithName:@"FATaskException" reason: @"continuation should not be nil" userInfo:nil];
    }
    
    [[FATask startTaskWithBlock:^id(FATask* task) {
        return backgroundBlock();
    } dispatchQueue:[FATask backgroundQueue] group:group]
     continueWithBlock:^(FATask* task) {
         continuation([task result], [task error]);
     } dispatchQueue:[FATask backgroundQueue] group:group];
}

+ (void) performInBackground: (id (^)()) backgroundBlock continuation: (void (^)(id result, NSException* error)) continuation{
    [FATask performInBackground:backgroundBlock mainThreadContinuation:continuation group:NULL];
}

+ (void) performInBackground: (id (^)()) backgroundBlock mainThreadContinuation: (void (^)(id result, NSException* error)) continuation group: (dispatch_group_t) group{
    if (backgroundBlock == nil) {
        @throw [NSException exceptionWithName:@"FATaskException" reason: @"backgroundBlock should not be nil" userInfo:nil];
    }
    
    if (continuation == nil) {
        @throw [NSException exceptionWithName:@"FATaskException" reason: @"continuation should not be nil" userInfo:nil];
    }
    
    [[FATask startTaskWithBlock:^id(FATask* task) {
        return backgroundBlock();
    } dispatchQueue:[FATask backgroundQueue] group:group]
     continueWithBlock:^(FATask* task) {
        continuation([task result],[task error]);
     } dispatchQueue:dispatch_get_main_queue() group:group];
}

+ (void) performInBackground: (id (^)()) backgroundBlock mainThreadContinuation:(void (^)(id result, NSException* error)) continuation{
    [FATask performInBackground:backgroundBlock mainThreadContinuation:continuation group:NULL];
}

+ (id) task {
    FATask* newObject = [(FATask*)[self alloc] init];
    return [newObject autorelease];
}

- (void) dealloc {
    [self->_continuations release]; self->_continuations = nil;
    [self->_error release]; self->_error = nil;
    [self->_result release]; self->_result = nil;

    [super dealloc];
}

- (id ) result {
    id result;
    result = self->_result;
    return result;
}

- (void) setResult: (id ) result {
    if(result != self->_result) {
        [self->_result release];
        self->_result = [result retain];
    }
}

- (BOOL ) isFinished {
    BOOL result;
    result = self->_finished;
    return result;
}

- (void) setFinished: (BOOL ) finished {
    if(finished != self->_finished) {
        self->_finished = finished;
    }
}

- (NSException * ) error {
    NSException * result;
    result = self->_error;
    return result;
}

- (void) setError: (NSException * ) error {
    if(error != self->_error) {
        [self->_error release];
        self->_error = [error retain];
    }
}

@end

@implementation FABlockTask

- (FATask*) initWithBlock: (id (^)(FATask* task)) block{
    self = [super init];
    if (self) {
        self->_block = [block copy];
    }
    return self;
}

- (id) executeWithTask: (FATask*) previousTask{
    return self.block(previousTask);
}

+ (id) taskWithBlock: (id (^)(FATask* task)) block {
    FABlockTask* newObject = [(FABlockTask*)[self alloc] initWithBlock: block];
    return [newObject autorelease];
}

- (void) dealloc {
    [self->_block release]; self->_block = nil;
    
    [super dealloc];
}

- (id (^ )(FATask* task)) block {
    id (^ result )(FATask* task);
    result = self->_block;
    return result;
}

@end
