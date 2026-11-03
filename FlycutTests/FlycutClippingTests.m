//
//  FlycutClippingTests.m
//  FlycutTests
//

#import <XCTest/XCTest.h>
#import "FlycutClipping.h"

static NSString * const kTextType = @"public.utf8-plain-text";

@interface FlycutClippingTests : XCTestCase
@end

@implementation FlycutClippingTests

- (FlycutClipping *)clippingWithContents:(NSString *)contents displayLength:(int)displayLength
{
    return [[FlycutClipping alloc] initWithContents:contents
                                           withType:kTextType
                                  withDisplayLength:displayLength
                               withAppLocalizedName:@"TextEdit"
                                   withAppBundleURL:@"file:///System/Applications/TextEdit.app/"
                                      withTimestamp:1700000000];
}

#pragma mark - Initialization and accessors

- (void)testInitStoresAllProvidedValues
{
    FlycutClipping *clip = [self clippingWithContents:@"hello" displayLength:40];

    XCTAssertEqualObjects(clip.contents, @"hello");
    XCTAssertEqualObjects(clip.type, kTextType);
    XCTAssertEqual(clip.displayLength, 40);
    XCTAssertEqualObjects(clip.appLocalizedName, @"TextEdit");
    XCTAssertEqualObjects(clip.appBundleURL, @"file:///System/Applications/TextEdit.app/");
    XCTAssertEqual(clip.timestamp, (NSInteger)1700000000);
    XCTAssertFalse(clip.hasName);
    XCTAssertEqual([clip clipping], clip);
    XCTAssertTrue([clip.description hasSuffix:@": hello"]);

    [clip setHasName:YES];
    [clip setType:@"other"];
    XCTAssertTrue(clip.hasName);
    XCTAssertEqualObjects(clip.type, @"other");
}

- (void)testPlainInitProducesEmptyClippingWithDisplayLength40
{
    FlycutClipping *clip = [[FlycutClipping alloc] init];

    XCTAssertEqualObjects(clip.contents, @"");
    XCTAssertEqualObjects(clip.displayString, @"");
    XCTAssertEqual(clip.displayLength, 40);
    XCTAssertNil(clip.appBundleURL);
    XCTAssertEqual(clip.timestamp, (NSInteger)0);
}

#pragma mark - Display string

- (void)testDisplayStringNotTruncatedWhenWithinDisplayLength
{
    XCTAssertEqualObjects([self clippingWithContents:@"short" displayLength:10].displayString, @"short");
    // Exactly at the limit is not truncated.
    XCTAssertEqualObjects([self clippingWithContents:@"0123456789" displayLength:10].displayString, @"0123456789");
}

- (void)testDisplayStringTruncatedToDisplayLengthWithEllipsis
{
    FlycutClipping *clip = [self clippingWithContents:@"0123456789A" displayLength:10];
    XCTAssertEqualObjects(clip.displayString, @"0123456789…");
    // The full contents are untouched.
    XCTAssertEqualObjects(clip.contents, @"0123456789A");
}

- (void)testDisplayStringUsesOnlyFirstLine
{
    XCTAssertEqualObjects([self clippingWithContents:@"first\nsecond\nthird" displayLength:40].displayString, @"first");
    XCTAssertEqualObjects([self clippingWithContents:@"first\r\nsecond" displayLength:40].displayString, @"first");
    XCTAssertEqualObjects([self clippingWithContents:@"first\rsecond" displayLength:40].displayString, @"first");
}

- (void)testDisplayStringTrimsSurroundingWhitespaceAndLeadingBlankLines
{
    FlycutClipping *clip = [self clippingWithContents:@"  \n\t\n   indented text  \n\nmore\n  " displayLength:40];
    // Contents are trimmed as a whole first, then the first line is taken. Trailing whitespace
    // on that first line is kept (current behavior) because only the whole string is trimmed.
    XCTAssertEqualObjects(clip.displayString, @"indented text  ");

    XCTAssertEqualObjects([self clippingWithContents:@"   padded   " displayLength:40].displayString, @"padded");

    // Whitespace-only contents give an empty display string but are stored unchanged.
    FlycutClipping *blank = [self clippingWithContents:@" \n\t \n" displayLength:40];
    XCTAssertEqualObjects(blank.displayString, @"");
    XCTAssertEqualObjects(blank.contents, @" \n\t \n");
}

- (void)testTruncationAppliesToFirstLineOfVeryLongMultiLineContents
{
    NSString *longLine = [@"" stringByPaddingToLength:10000 withString:@"abc" startingAtIndex:0];
    NSString *contents = [NSString stringWithFormat:@"%@\nsecond line", longLine];
    FlycutClipping *clip = [self clippingWithContents:contents displayLength:37];

    XCTAssertEqual(clip.displayString.length, (NSUInteger)38); // 37 characters + ellipsis
    XCTAssertEqualObjects(clip.displayString, [[longLine substringToIndex:37] stringByAppendingString:@"…"]);
    XCTAssertEqualObjects(clip.contents, contents);
}

- (void)testDisplayStringHandlesNonASCIIText
{
    XCTAssertEqualObjects([self clippingWithContents:@"Crème brûlée\nrecipe" displayLength:40].displayString, @"Crème brûlée");
    XCTAssertEqualObjects([self clippingWithContents:@"日本語のテキストです" displayLength:4].displayString, @"日本語の…");
}

- (void)testTruncationDoesNotSplitEmoji
{
    // The display length counts UTF-16 units; truncation backs off to the start of any
    // character that straddles the limit instead of leaving half of it behind.
    FlycutClipping *clip = [self clippingWithContents:@"😀😀😀" displayLength:1];
    XCTAssertNotNil([clip.displayString dataUsingEncoding:NSUTF8StringEncoding],
                    @"display string should remain valid Unicode after truncation");
    XCTAssertEqualObjects(clip.displayString, @"…");

    XCTAssertEqualObjects([self clippingWithContents:@"😀😀😀" displayLength:2].displayString, @"😀…");
    XCTAssertEqualObjects([self clippingWithContents:@"ab😀cd" displayLength:3].displayString, @"ab…");
    XCTAssertEqualObjects([self clippingWithContents:@"🇯🇵🇺🇸" displayLength:2].displayString, @"…", @"a flag is one character");
    XCTAssertEqualObjects([self clippingWithContents:@"🇯🇵🇺🇸" displayLength:4].displayString, @"🇯🇵…");
    XCTAssertEqualObjects([self clippingWithContents:@"👨‍👩‍👧 family" displayLength:5].displayString, @"…",
                          @"a ZWJ sequence is one character");
}

- (void)testSetContentsRecomputesDisplayString
{
    FlycutClipping *clip = [self clippingWithContents:@"old" displayLength:5];
    [clip setContents:@"brand new\ntext"];
    XCTAssertEqualObjects(clip.contents, @"brand new\ntext");
    XCTAssertEqualObjects(clip.displayString, @"brand…");

    [clip setContents:@"abcdefgh" setDisplayLength:3];
    XCTAssertEqual(clip.displayLength, 3);
    XCTAssertEqualObjects(clip.displayString, @"abc…");
}

- (void)testSetDisplayLengthRecomputesDisplayStringAndIgnoresNonPositive
{
    FlycutClipping *clip = [self clippingWithContents:@"abcdefghij" displayLength:20];
    XCTAssertEqualObjects(clip.displayString, @"abcdefghij");

    [clip setDisplayLength:4];
    XCTAssertEqual(clip.displayLength, 4);
    XCTAssertEqualObjects(clip.displayString, @"abcd…");

    [clip setDisplayLength:0];
    [clip setDisplayLength:-5];
    XCTAssertEqual(clip.displayLength, 4);
    XCTAssertEqualObjects(clip.displayString, @"abcd…");
}

- (void)testZeroDisplayLengthAtInitYieldsOnlyEllipsis
{
    // Current behavior: a non-positive initial display length is ignored, leaving the length at 0,
    // so any non-empty first line is "truncated" to just the ellipsis.
    FlycutClipping *clip = [self clippingWithContents:@"text" displayLength:0];
    XCTAssertEqual(clip.displayLength, 0);
    XCTAssertEqualObjects(clip.displayString, @"…");
}

#pragma mark - Equality

- (void)testEqualityIsBasedOnContentsOnly
{
    FlycutClipping *a = [self clippingWithContents:@"same" displayLength:40];
    FlycutClipping *b = [[FlycutClipping alloc] initWithContents:@"same"
                                                        withType:@"different.type"
                                               withDisplayLength:3
                                            withAppLocalizedName:@"Other"
                                                withAppBundleURL:nil
                                                   withTimestamp:42];
    FlycutClipping *c = [self clippingWithContents:@"Same" displayLength:40];

    XCTAssertEqualObjects(a, b);
    XCTAssertNotEqualObjects(a, c, @"equality is case-sensitive");
    XCTAssertFalse([a isEqual:@"same"], @"a clipping is never equal to a plain string");
    XCTAssertFalse([a isEqual:nil]);
}

- (void)testEqualClippingsHaveEqualHashes
{
    FlycutClipping *a = [self clippingWithContents:@"same" displayLength:40];
    FlycutClipping *b = [self clippingWithContents:@"same" displayLength:40];
    XCTAssertEqualObjects(a, b);

    XCTAssertEqual(a.hash, b.hash);
    XCTAssertEqual(([NSSet setWithObjects:a, b, nil].count), (NSUInteger)1);
}

@end
