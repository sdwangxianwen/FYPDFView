//
//  PdfCache.h
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
//页码从0开始
typedef void(^PdfCacheCompleteBlock)(int page,UIImage *image);
typedef void(^pdfFailureBlock)(void);

@interface PdfCache : NSObject
-(instancetype)init:(CGSize)size;
-(instancetype)init:(CGSize)size cacheCount:(int)count ;
-(instancetype)bindDocument:(CGPDFDocumentRef)docRef;
-(instancetype)openDocument:(NSURL *)url;
-(BOOL)loadPage:(int)page complete:(PdfCacheCompleteBlock)complete ;
-(void)unInit;
-(int)totalPage;
@end
