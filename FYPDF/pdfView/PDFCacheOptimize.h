//
//  PDFCacheOptimize.h
//  FYPDF
//
//  Created by wang on 2018/8/23.
//  Copyright © 2018年 wang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//页码从0开始
typedef void(^PdfCacheCompleteBlock)(int page,UIImage *image);

@interface PDFCacheOptimize : NSObject
@property(nonatomic,assign) NSInteger totalPages;
-(instancetype)init:(CGSize)size;
-(instancetype)init:(CGSize)size cacheCount:(int)count ;
-(instancetype)bindDocument:(CGPDFDocumentRef)docRef;
-(instancetype)openDocument:(NSURL *)url;
-(BOOL)loadPage:(int)page complete:(PdfCacheCompleteBlock)complete object:(id)object;
-(void)cancelLoad:(id)object; //取消上一个Block
-(void)setPreloadPage:(int)page; //优先加载的页面,以这个页面为中心
-(void)unInit;
-(int)totalPage;

@end
