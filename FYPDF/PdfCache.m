//
//  PdfCache.m
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import "PdfCache.h"

@interface PdfCache () {
    NSCache *_cache;
    CGPDFDocumentRef _pdfDoc;
    CGSize _imageSize;
    NSString * _documentDirectory;
}

@end

@implementation PdfCache

-(instancetype)init:(CGSize)size {
    return [self init:size cacheCount:5];
}
-(instancetype)init:(CGSize)size cacheCount:(int)count {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = count;
        _imageSize = size;
        //创建一个沙盒存储
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _documentDirectory = [paths objectAtIndex:0];
    }
    return self;
}
-(instancetype)bindDocument:(CGPDFDocumentRef)docRef {
    [self clearDoc];
    _pdfDoc = CGPDFDocumentRetain(docRef);
    return self;
}
-(instancetype)openDocument:(NSURL *)url{
    [self clearDoc];
    CFURLRef refURL = CFBridgingRetain(url);
    _pdfDoc = CGPDFDocumentCreateWithURL(refURL);
    CFRelease(refURL);
    return self;
}

-(instancetype)initWithDocument:(CGPDFDocumentRef)docRef imageSize:(CGSize)size {
    return [self initWithDocument:docRef imageSize:size cacheCount:5];
}

-(instancetype)initWithDocument:(CGPDFDocumentRef)docRef imageSize:(CGSize)size cacheCount:(int)count {
    self = [super init];
    if (self) {
        _cache = [[NSCache alloc] init];
        _cache.countLimit = count;
        _imageSize = size;
        _pdfDoc = CGPDFDocumentRetain(docRef);
    }
    return self;
}
-(int)totalPage {
    return _pdfDoc ? (int)CGPDFDocumentGetNumberOfPages(_pdfDoc): 0;
}

-(UIImage *)drawPage:(int)page {
    CGPDFDocumentRef pdfTempDoc;
    CGSize imageSize;
    @synchronized(self) {
        pdfTempDoc = CGPDFDocumentRetain(_pdfDoc);
        imageSize = _imageSize;
    }
    if (!pdfTempDoc) {
        return nil;
    }
    UIImage *image;
    UIGraphicsBeginImageContext(imageSize);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context,0.0,imageSize.height);
    CGContextScaleCTM(context,1.0, -1.0);
    CGPDFPageRef  pageRef =CGPDFDocumentGetPage(pdfTempDoc,page + 1);
    CGContextSaveGState(context);//记录当前绘制环境，防止多次绘画
    CGAffineTransform  pdfTransForm =CGPDFPageGetDrawingTransform(pageRef,kCGPDFCropBox,CGRectMake(0, 0, imageSize.width, imageSize.height),0,true);//创建一个仿射变换的参数给函数。
    CGContextConcatCTM(context, pdfTransForm);//把创建的仿射变换参数和上下文环境联系起来
    CGContextDrawPDFPage(context, pageRef);//把得到的指定页的PDF数据绘制到视图上
    CGContextRestoreGState(context);//恢复图形状态
    CGPDFDocumentRelease(pdfTempDoc);
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //将image存储到临时文件下
    [self saveImage:image page:page];
    @synchronized(self) {
        if (!_cache) {
            image = nil;
        }
    }
    return image;
}

//读取
-(UIImage *)readImage:(int)page {
    NSString *path = [NSString stringWithFormat:@"%@/Image%d", _documentDirectory,page];
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    return image;
}

-(void)saveImage:(UIImage *)image page:(int)page {
   
    NSString *path = [NSString stringWithFormat:@"%@/Image%d", _documentDirectory,page];
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    [imageData writeToFile:path atomically:YES];
}

-(BOOL)loadPage:(int)page complete:(PdfCacheCompleteBlock)complete {
    if (!_cache) {
        return NO;
    }
    UIImage *image = [_cache objectForKey:@(page)];
    if (image) {
        complete(page,image);
        return YES;
    } else {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            UIImage *imageNew = [self readImage:page];
            if (imageNew) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onLoadFinish:imageNew page:page complete:complete];
                });
            } else {
                imageNew = [self drawPage:page];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onLoadFinish:imageNew page:page complete:complete];
                });
            }
        });
        
        return NO;
    }
}
-(void)onLoadFinish:(UIImage *)image page:(int)page complete:(PdfCacheCompleteBlock)complete {
    if (!_cache) {
        return;
    }
    [_cache setObject:image forKey:@(page)];
    complete(page,image);
}

-(void)clearDoc {
     @synchronized(self) {
         if (_pdfDoc) {
             CGPDFDocumentRelease(_pdfDoc);
             _pdfDoc = nil;
             if (_cache) {
                 [_cache removeAllObjects];
             }
         }
     }
}

-(void)unInit {
    @synchronized(self) {
        if (_pdfDoc) {
            CGPDFDocumentRelease(_pdfDoc);
            _pdfDoc = nil;
        }
        if (_cache) {
            [_cache removeAllObjects];
            _cache = nil;
        }
    }
}

@end
