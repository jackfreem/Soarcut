//
//  FlycutStoreTests.m
//  FlycutTests
//

#import <XCTest/XCTest.h>
#import "FlycutStore.h"

static NSString * const kTextType = @"public.utf8-plain-text";
static NSString * const kRemoveDuplicatesKey = @"removeDuplicates";

#pragma mark - Fake delegates

/// Records every FlycutStoreDelegate callback as a short string, e.g. "insert 0", "move 2->0".
@interface FakeStoreDelegate : NSObject <FlycutStoreDelegate>
@property (nonatomic, strong) NSMutableArray<NSString *> *events;
@end

@implementation FakeStoreDelegate
- (instancetype)init
{
    if ((self = [super init])) {
        _events = [NSMutableArray array];
    }
    return self;
}
- (void)beginUpdates { [self.events addObject:@"begin"]; }
- (void)endUpdates { [self.events addObject:@"end"]; }
- (void)insertClippingAtIndex:(int)index { [self.events addObject:[NSString stringWithFormat:@"insert %d", index]]; }
- (void)deleteClippingAtIndex:(int)index { [self.events addObject:[NSString stringWithFormat:@"delete %d", index]]; }
- (void)reloadClippingAtIndex:(int)index { [self.events addObject:[NSString stringWithFormat:@"reload %d", index]]; }
- (void)moveClippingAtIndex:(int)index toIndex:(int)newIndex
{
    [self.events addObject:[NSString stringWithFormat:@"move %d->%d", index, newIndex]];
}
@end

/// Records the index and the contents of the clipping that is about to be deleted.
@interface FakeDeleteDelegate : NSObject <FlycutStoreDeleteDelegate>
@property (nonatomic, strong) NSMutableArray<NSNumber *> *indexes;
@property (nonatomic, strong) NSMutableArray<NSString *> *contents;
@end

@implementation FakeDeleteDelegate
- (instancetype)init
{
    if ((self = [super init])) {
        _indexes = [NSMutableArray array];
        _contents = [NSMutableArray array];
    }
    return self;
}
- (void)willDeleteClippingFromStore:(id)store AtIndex:(int)index
{
    [self.indexes addObject:@(index)];
    [self.contents addObject:[(FlycutStore *)store clippingContentsAtPosition:index] ?: @"<nil>"];
}
@end

#pragma mark - Tests

@interface FlycutStoreTests : XCTestCase
@property (nonatomic, strong) id savedRemoveDuplicates;
@end

@implementation FlycutStoreTests

- (void)setUp
{
    [super setUp];
    // FlycutStore -removeDuplicates reads this key from NSUserDefaults; save it and start from "off".
    self.savedRemoveDuplicates = [[NSUserDefaults standardUserDefaults] objectForKey:kRemoveDuplicatesKey];
    [self setRemoveDuplicates:NO];
}

- (void)tearDown
{
    if (self.savedRemoveDuplicates) {
        [[NSUserDefaults standardUserDefaults] setObject:self.savedRemoveDuplicates forKey:kRemoveDuplicatesKey];
    } else {
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:kRemoveDuplicatesKey];
    }
    [super tearDown];
}

#pragma mark Helpers

- (void)setRemoveDuplicates:(BOOL)enabled
{
    [[NSUserDefaults standardUserDefaults] setBool:enabled forKey:kRemoveDuplicatesKey];
}

- (FlycutStore *)storeRemembering:(int)remember
{
    return [[FlycutStore alloc] initRemembering:remember displaying:10 withDisplayLength:40];
}

- (BOOL)add:(NSString *)contents to:(FlycutStore *)store
{
    return [store addClipping:contents ofType:kTextType fromAppLocalizedName:@"Tests" fromAppBundleURL:nil atTimestamp:0];
}

- (FlycutStore *)storeWithContents:(NSArray<NSString *> *)oldestFirst remembering:(int)remember
{
    FlycutStore *store = [self storeRemembering:remember];
    for (NSString *contents in oldestFirst) {
        [self add:contents to:store];
    }
    return store;
}

/// All contents, newest first.
- (NSArray<NSString *> *)allContents:(FlycutStore *)store
{
    return [store previousContents:[store jcListCount]];
}

#pragma mark Empty store and construction

- (void)testNewStoreIsEmpty
{
    FlycutStore *store = [self storeRemembering:5];

    XCTAssertEqual([store jcListCount], 0);
    XCTAssertEqual([store rememberNum], 5);
    XCTAssertEqual([store displayLen], 40);
    XCTAssertNil([store clippingAtPosition:0]);
    XCTAssertNil([store clippingContentsAtPosition:0]);
    XCTAssertEqualObjects([store previousContents:10], @[]);
    XCTAssertEqualObjects([store previousDisplayStrings:10], @[]);
    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:@"x"], @[]);
    XCTAssertEqualObjects([store previousIndexes:10 containing:@"x"], @[]);
    XCTAssertEqual([store indexOfClipping:@"x" ofType:kTextType fromAppLocalizedName:nil fromAppBundleURL:nil atTimestamp:0], -1);
    XCTAssertFalse([store modifiedSinceLastSaveStore]);

    // Clearing an empty store is harmless and only brackets an empty update.
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    store.delegate = delegate;
    [store clearList];
    XCTAssertEqual([store jcListCount], 0);
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"end"]));
}

- (void)testNonPositiveRememberNumFallsBackTo40AndLaterNonPositiveValuesAreIgnored
{
    FlycutStore *store = [self storeRemembering:0];
    XCTAssertEqual([store rememberNum], 40);

    [store setRememberNum:-3];
    XCTAssertEqual([store rememberNum], 40);
}

#pragma mark Adding

- (void)testAddingClippingsKeepsNewestFirst
{
    FlycutStore *store = [self storeWithContents:@[@"one", @"two", @"three"] remembering:10];

    XCTAssertEqual([store jcListCount], 3);
    XCTAssertEqualObjects([self allContents:store], (@[@"three", @"two", @"one"]));
    XCTAssertEqualObjects([store clippingContentsAtPosition:0], @"three");
    XCTAssertEqualObjects([store clippingTypeAtPosition:0], kTextType);
    XCTAssertEqualObjects([store clippingAtPosition:2].contents, @"one");
    XCTAssertTrue([store modifiedSinceLastSaveStore]);

    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    store.delegate = delegate;
    [self add:@"four" to:store];
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"insert 0", @"end"]));
    XCTAssertEqualObjects([store clippingContentsAtPosition:0], @"four");
}

- (void)testAddingEmptyStringIsRejected
{
    FlycutStore *store = [self storeRemembering:10];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    store.delegate = delegate;

    XCTAssertFalse([self add:@"" to:store]);
    XCTAssertEqual([store jcListCount], 0);
    XCTAssertEqualObjects(delegate.events, @[]);
    XCTAssertFalse([store modifiedSinceLastSaveStore]);
}

- (void)testAddingVeryLongMultiLineAndNonASCIIContentsPreservesThemExactly
{
    NSString *longText = [@"" stringByPaddingToLength:100000 withString:@"lorem ipsum\n" startingAtIndex:0];
    NSString *unicode = @"Grüße 👋 世界\nzweite Zeile";
    FlycutStore *store = [self storeWithContents:@[longText, unicode] remembering:10];

    XCTAssertEqualObjects([store clippingContentsAtPosition:0], unicode);
    XCTAssertEqualObjects([store clippingContentsAtPosition:1], longText);
    XCTAssertEqualObjects([store clippingDisplayStringAtPosition:0], @"Grüße 👋 世界");
    XCTAssertEqualObjects([store clippingDisplayStringAtPosition:1], @"lorem ipsum");
}

- (void)testInsertClippingAtIndexBeyondCountAppendsAtEnd
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b"] remembering:10];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    store.delegate = delegate;

    FlycutClipping *clip = [[FlycutClipping alloc] initWithContents:@"z" withType:kTextType withDisplayLength:40
                                               withAppLocalizedName:nil withAppBundleURL:nil withTimestamp:0];
    [store insertClipping:clip atIndex:99];

    XCTAssertEqualObjects([self allContents:store], (@[@"b", @"a", @"z"]));
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"insert 2", @"end"]));
}

#pragma mark Remember limit

- (void)testAddingBeyondRememberLimitDropsOldest
{
    FlycutStore *store = [self storeWithContents:@[@"A", @"B", @"C"] remembering:3];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.delegate = delegate;
    store.deleteDelegate = deleteDelegate;

    [self add:@"D" to:store];

    XCTAssertEqual([store jcListCount], 3);
    XCTAssertEqualObjects([self allContents:store], (@[@"D", @"C", @"B"]));
    // deleteDelegate is told before removal, with the dropped clipping still reachable at that index.
    XCTAssertEqualObjects(deleteDelegate.indexes, @[@3]);
    XCTAssertEqualObjects(deleteDelegate.contents, @[@"A"]);
    // The table delegate gets the delete in pre-insert indexing (A was row 2 before D was added).
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"insert 0", @"delete 2", @"end"]));
    XCTAssertEqualObjects([[store deletionJournal] valueForKey:@"contents"], @[@"A"]);
}

- (void)testAddingManyBeyondRememberLimitKeepsOnlyNewest
{
    FlycutStore *store = [self storeRemembering:2];
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.deleteDelegate = deleteDelegate;

    for (int i = 0; i < 10; i++) {
        [self add:[NSString stringWithFormat:@"%d", i] to:store];
    }

    XCTAssertEqualObjects([self allContents:store], (@[@"9", @"8"]));
    XCTAssertEqualObjects(deleteDelegate.contents, (@[@"0", @"1", @"2", @"3", @"4", @"5", @"6", @"7"]));
}

- (void)testLoweringRememberNumTrimsOldest
{
    FlycutStore *store = [self storeWithContents:@[@"A", @"B", @"C", @"D"] remembering:10];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.delegate = delegate;
    store.deleteDelegate = deleteDelegate;

    [store setRememberNum:2];

    XCTAssertEqual([store rememberNum], 2);
    XCTAssertEqualObjects([self allContents:store], (@[@"D", @"C"]));
    XCTAssertEqualObjects(deleteDelegate.contents, (@[@"B", @"A"]));
    // Current behavior: each delete is reported at the live (post-previous-removal) index, so trimming
    // two clippings reports row 2 twice. (Contrast with add-time trimming, which uses pre-insert indexing.)
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"delete 2", @"delete 2", @"end"]));
}

#pragma mark Duplicates

- (void)testDuplicatesAreKeptWhenRemoveDuplicatesIsOff
{
    [self setRemoveDuplicates:NO];
    FlycutStore *store = [self storeWithContents:@[@"x", @"y", @"x"] remembering:10];

    XCTAssertFalse([store removeDuplicates]);
    XCTAssertEqualObjects([self allContents:store], (@[@"x", @"y", @"x"]));
    // indexOfClipping finds the newest match.
    XCTAssertEqual([store indexOfClipping:@"x" ofType:kTextType fromAppLocalizedName:nil fromAppBundleURL:nil atTimestamp:0], 0);
    XCTAssertEqual([store indexOfClipping:@"y" ofType:kTextType fromAppLocalizedName:nil fromAppBundleURL:nil atTimestamp:0], 1);
}

- (void)testDuplicateMovesToTopWhenRemoveDuplicatesIsOn
{
    [self setRemoveDuplicates:YES];
    FlycutStore *store = [self storeWithContents:@[@"x", @"y", @"z"] remembering:3];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.delegate = delegate;
    store.deleteDelegate = deleteDelegate;

    [self add:@"x" to:store];

    XCTAssertTrue([store removeDuplicates]);
    XCTAssertEqualObjects([self allContents:store], (@[@"x", @"z", @"y"]));
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"move 2->0", @"end"]));
    XCTAssertEqualObjects(deleteDelegate.indexes, @[], @"a duplicate must not push anything out at the remember limit");
}

#pragma mark Clear all

- (void)testClearListEmptiesStoreAndNotifiesDelegates
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b", @"c"] remembering:10];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.delegate = delegate;
    store.deleteDelegate = deleteDelegate;

    [store clearList];

    XCTAssertEqual([store jcListCount], 0);
    XCTAssertNil([store clippingAtPosition:0]);
    XCTAssertEqualObjects(deleteDelegate.contents, (@[@"a", @"b", @"c"])); // bottom-up
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"delete 2", @"delete 1", @"delete 0", @"end"]));
}

- (void)testAddingAfterClearListStartsFreshHistory
{
    [self setRemoveDuplicates:YES];
    FlycutStore *store = [self storeWithContents:@[@"old1", @"old2", @"old3"] remembering:3];
    [store clearList];

    [self add:@"new1" to:store];
    [self add:@"old2" to:store]; // previously-seen contents are added as new, not "moved"
    [self add:@"new2" to:store];

    XCTAssertEqualObjects([self allContents:store], (@[@"new2", @"old2", @"new1"]));
    XCTAssertEqualObjects([store previousDisplayStrings:10], (@[@"new2", @"old2", @"new1"]));

    // The remember limit still applies after a clear.
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.deleteDelegate = deleteDelegate;
    [self add:@"new3" to:store];
    XCTAssertEqualObjects([self allContents:store], (@[@"new3", @"new2", @"old2"]));
    XCTAssertEqualObjects(deleteDelegate.contents, @[@"new1"]);
}

#pragma mark Display strings

- (void)testDisplayStringsAreFirstLineTrimmedAndTruncated
{
    FlycutStore *store = [[FlycutStore alloc] initRemembering:10 displaying:10 withDisplayLength:5];
    [self add:@"  \nhello world\nsecond" to:store];
    [self add:@"\tabc\t" to:store];

    XCTAssertEqualObjects([store clippingDisplayStringAtPosition:0], @"abc");
    XCTAssertEqualObjects([store clippingDisplayStringAtPosition:1], @"hello…");
    XCTAssertEqualObjects([store previousDisplayStrings:10], (@[@"abc", @"hello…"]));
    XCTAssertEqualObjects([store clippingContentsAtPosition:1], @"  \nhello world\nsecond");
}

- (void)testSetDisplayLenUpdatesExistingClippings
{
    FlycutStore *store = [self storeWithContents:@[@"abcdefghij"] remembering:10];
    XCTAssertEqualObjects([store clippingDisplayStringAtPosition:0], @"abcdefghij");

    [store setDisplayLen:3];
    XCTAssertEqual([store displayLen], 3);
    XCTAssertEqualObjects([store clippingDisplayStringAtPosition:0], @"abc…");

    [store setDisplayLen:0]; // ignored
    XCTAssertEqual([store displayLen], 3);
}

- (void)testPreviousContentsAndDisplayStringsAreLimitedToHowMany
{
    FlycutStore *store = [self storeWithContents:@[@"1", @"2", @"3", @"4"] remembering:10];

    XCTAssertEqualObjects([store previousContents:2], (@[@"4", @"3"]));
    XCTAssertEqualObjects([store previousDisplayStrings:2], (@[@"4", @"3"]));
    XCTAssertEqualObjects([store previousDisplayStrings:0], @[]);
    XCTAssertEqualObjects([store previousDisplayStrings:99], (@[@"4", @"3", @"2", @"1"]));
}

#pragma mark Search

- (void)testSearchIsCaseInsensitiveAndNewestFirst
{
    FlycutStore *store = [self storeWithContents:@[@"Apple pie", @"banana", @"PINEAPPLE", @"cherry"] remembering:10];

    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:@"apple"], (@[@"PINEAPPLE", @"Apple pie"]));
    XCTAssertEqualObjects([store previousIndexes:10 containing:@"apple"], (@[@1, @3]));
}

- (void)testSearchRespectsHowManyAndReturnsMostRecentMatches
{
    FlycutStore *store = [self storeWithContents:@[@"match 1", @"other", @"match 2", @"match 3"] remembering:10];

    XCTAssertEqualObjects([store previousDisplayStrings:2 containing:@"match"], (@[@"match 3", @"match 2"]));
    XCTAssertEqualObjects([store previousIndexes:2 containing:@"match"], (@[@0, @1]));
}

- (void)testSearchMatchesFullContentsNotJustDisplayString
{
    FlycutStore *store = [[FlycutStore alloc] initRemembering:10 displaying:10 withDisplayLength:5];
    [self add:@"title line\nthe needle is on line two" to:store];
    [self add:@"nothing here" to:store];
    [self add:@"0123456789needle" to:store]; // beyond the truncated display string

    XCTAssertEqualObjects([store previousIndexes:10 containing:@"NEEDLE"], (@[@0, @2]));
    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:@"needle"], (@[@"01234…", @"title…"]));
}

- (void)testSearchWithNonASCIIQuery
{
    FlycutStore *store = [self storeWithContents:@[@"Ünïcödé text", @"plain", @"東京タワー"] remembering:10];

    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:@"東京"], @[@"東京タワー"]);
    XCTAssertEqualObjects([store previousIndexes:10 containing:@"ünïcödé"], @[@2]);
}

- (void)testSearchWithNoMatchesReturnsEmpty
{
    FlycutStore *store = [self storeWithContents:@[@"alpha", @"beta"] remembering:10];

    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:@"zzz"], @[]);
    XCTAssertEqualObjects([store previousIndexes:10 containing:@"zzz"], @[]);
}

- (void)testEmptyOrNilSearchFallsBackToUnfilteredResults
{
    FlycutStore *store = [self storeWithContents:@[@"alpha", @"beta"] remembering:10];

    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:@""], (@[@"beta", @"alpha"]));
    XCTAssertEqualObjects([store previousDisplayStrings:10 containing:nil], (@[@"beta", @"alpha"]));
    // Current behavior: without a search, previousIndexes returns 0..howMany-1 regardless of how
    // many clippings exist, so it can return indexes past the end of the store.
    XCTAssertEqualObjects([store previousIndexes:4 containing:nil], (@[@0, @1, @2, @3]));
}

#pragma mark Deleting

- (void)testClearItemRemovesClippingAndNotifiesDelegates
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b", @"c"] remembering:10];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    FakeDeleteDelegate *deleteDelegate = [FakeDeleteDelegate new];
    store.delegate = delegate;
    store.deleteDelegate = deleteDelegate;

    [store clearItem:1];

    XCTAssertEqualObjects([self allContents:store], (@[@"c", @"a"]));
    XCTAssertEqualObjects(deleteDelegate.indexes, @[@1]);
    XCTAssertEqualObjects(deleteDelegate.contents, @[@"b"]);
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"delete 1", @"end"]));
    XCTAssertEqualObjects([[store deletionJournal] valueForKey:@"contents"], @[@"b"]);
}

#pragma mark Out-of-range indexes (current behavior)

- (void)testOutOfRangeAccessorsReturnNilOrThrow
{
    FlycutStore *store = [self storeWithContents:@[@"only"] remembering:10];

    // These two bounds-check and return nil (negative indexes compare as huge unsigned values).
    XCTAssertNil([store clippingAtPosition:1]);
    XCTAssertNil([store clippingAtPosition:-1]);
    XCTAssertNil([store clippingContentsAtPosition:5]);
    XCTAssertNil([store clippingContentsAtPosition:-1]);

    // These do not bounds-check and raise NSRangeException.
    XCTAssertThrowsSpecificNamed([store clippingDisplayStringAtPosition:1], NSException, NSRangeException);
    XCTAssertThrowsSpecificNamed([store clippingTypeAtPosition:1], NSException, NSRangeException);
}

- (void)testClearItemOutOfRangeThrowsAndLeavesStoreIntact
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b"] remembering:10];

    XCTAssertThrowsSpecificNamed([store clearItem:2], NSException, NSRangeException);
    XCTAssertThrowsSpecificNamed([store clearItem:-1], NSException, NSRangeException);
    XCTAssertEqualObjects([self allContents:store], (@[@"b", @"a"]));
}

#pragma mark Moving

- (void)testMoveToTopBringsClippingToFront
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b", @"c", @"d"] remembering:10];
    FakeStoreDelegate *delegate = [FakeStoreDelegate new];
    store.delegate = delegate;

    [store clippingMoveToTop:3];

    XCTAssertEqualObjects([self allContents:store], (@[@"a", @"d", @"c", @"b"]));
    XCTAssertEqualObjects(delegate.events, (@[@"begin", @"move 3->0", @"end"]));
}

- (void)testMoveUpwardToMiddlePosition
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b", @"c", @"d"] remembering:10]; // d c b a
    [store clippingMoveFrom:3 To:1];
    XCTAssertEqualObjects([self allContents:store], (@[@"d", @"a", @"c", @"b"]));

    [store clippingMoveFrom:2 To:2]; // no-op move
    XCTAssertEqualObjects([self allContents:store], (@[@"d", @"a", @"c", @"b"]));
}

- (void)testMoveDownwardPreservesAllClippings
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b", @"c"] remembering:10]; // c b a
    [store clippingMoveFrom:0 To:2];

    XCTExpectFailure(@"FlycutStore -clippingMoveFrom:To: always removes index+1, so moving toward the end "
                     @"duplicates the moved clipping and drops a neighbour");
    XCTAssertEqualObjects([self allContents:store], (@[@"b", @"a", @"c"]));
}

#pragma mark Journals

- (void)testInsertionJournalRecordsNewestFirstAndIsCappedAtRememberNum
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b", @"c", @"d"] remembering:3];

    XCTAssertEqualObjects([[store insertionJournal] valueForKey:@"contents"], (@[@"d", @"c", @"b"]));
    XCTAssertEqualObjects([[store deletionJournal] valueForKey:@"contents"], @[@"a"]);
}

- (void)testClearModifiedAndPruneJournalsDropsEntriesRecordedBeforeSave
{
    FlycutStore *store = [self storeWithContents:@[@"a", @"b"] remembering:10];
    XCTAssertTrue([store modifiedSinceLastSaveStore]);

    [store clearModifiedSinceLastSaveStore];
    XCTAssertFalse([store modifiedSinceLastSaveStore]);

    [self add:@"c" to:store];
    XCTAssertTrue([store modifiedSinceLastSaveStore]);

    // Journals are newest-first; pruning removes the entries that existed at save time (the tail).
    [store pruneJournals];
    XCTAssertEqualObjects([[store insertionJournal] valueForKey:@"contents"], @[@"c"]);
    XCTAssertEqualObjects([store deletionJournal], @[]);
}

@end
