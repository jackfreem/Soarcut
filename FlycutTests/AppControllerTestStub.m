//
//  AppControllerTestStub.m
//  FlycutTests
//
//  FlycutOperator calls +[AppController isAppSandboxed] when saving clippings to a file.
//  The test bundle doesn't link the real AppController (it would pull in the whole UI), so this
//  stand-in answers for it. Soarcut ships unsandboxed, so NO matches production behavior.
//

#import <Foundation/Foundation.h>

@interface AppController : NSObject
+ (BOOL)isAppSandboxed;
@end

@implementation AppController
+ (BOOL)isAppSandboxed
{
    return NO;
}
@end
