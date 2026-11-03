//
//  StarPrompt.h
//  Soarcut
//
//  Asks people who use Soarcut regularly for a GitHub star, modeled on T3 Code's
//  star toast (pingdotgg/t3code#27832): only after real use, at most once per
//  launch, and never again once it is closed.
//

#import <Cocoa/Cocoa.h>

@interface StarPrompt : NSObject

// Opens the repository and stops the prompt from ever showing again.
+ (void)openRepository;

// Counts a clipping the user chose from the bezel or the menu. Past the threshold,
// shows the prompt under `statusItem` once per launch until it is closed.
+ (void)recordPasteNearStatusItem:(NSStatusItem *)statusItem;

@end
