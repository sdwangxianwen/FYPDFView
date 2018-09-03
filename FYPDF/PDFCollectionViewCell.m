//
//  PDFCollectionViewCell.m
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import "PDFCollectionViewCell.h"
#import "PdfCache.h"

@interface PDFCollectionViewCell ()
@end
@implementation PDFCollectionViewCell
- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        [self.contentView addSubview:_imageView];
        _imageView.contentMode = UIViewContentModeScaleAspectFit;
        UIButton *btn = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [btn setTitle:@"清除缓存" forState:(UIControlStateNormal)];
//        [btn setBackgroundColor:[UIColor brownColor]];
        [self.contentView addSubview:btn];
        [btn addTarget:self action:@selector(clean) forControlEvents:(UIControlEventTouchUpInside)];
    }
    return self;
}
-(void)clean {
     NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString * cachPath = [paths objectAtIndex:0];
    NSArray * files = [[NSFileManager defaultManager ] subpathsAtPath :cachPath];
    for (NSString *p in files) {
        NSString * path = [cachPath stringByAppendingPathComponent:p];
        if ([[NSFileManager defaultManager ] fileExistsAtPath :path]) {
            [[NSFileManager defaultManager ] removeItemAtPath:path error:nil];
        }
    }
}

@end
