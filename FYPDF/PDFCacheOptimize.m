//
//  PDFCacheOptimize.m
//  FYPDF
//
//  Created by wang on 2018/8/23.
//  Copyright © 2018年 wang. All rights reserved.
//

#import "PDFCacheOptimize.h"
#import "NSString+MD5.h"

#define kREQUESTPAGE @"page"
#define kREQUESTBLOCK @"block"
#define kREQUESTOBJECT @"object"

@interface PDFCacheOptimize (){
    int _openCount;  //打开文档的计数
    NSCache *_cache; //仅仅ui线程使用
    CGPDFDocumentRef _pdfDoc; // 跨线程
    CGSize _imageSize; // 跨线程
    NSString * _documentDirectory; // 跨线程
    NSMutableArray* _pageReading; // 需要读取文件的
    NSMutableArray* _pageDrawing; // 需要画的
    int _preloadPage; //优先加载的页面
    dispatch_block_t _taskBlock;
    NSMutableArray *_pendingRequests; //加载请求
    NSURL *_url;  //pdf的URL
}
@end

@implementation PDFCacheOptimize

-(instancetype)init:(CGSize)size {
    return [self init:size cacheCount:5];
}
-(instancetype)init:(CGSize)size cacheCount:(int)count {
    self = [super init];
    if (self) {
        _openCount = 1;
        _cache = [[NSCache alloc] init];
        _cache.countLimit = count;
        _imageSize = size;
        _pendingRequests = [NSMutableArray array];
        _pageReading = [NSMutableArray array];
        _pageDrawing = [NSMutableArray array];
    }
    return self;
}

#pragma mark:每次打开文档都会打开block,获取沙盒存储中的图片
-(void)onPdfOpened {
    _preloadPage = 0;
    self.totalPages = [self totalPage];
    int localCount = ++_openCount;
    typeof(self) __weak weakSelf = self;
    __block dispatch_block_t tempBlock;
    _taskBlock = ^() {
        //强引用一下
        __strong typeof(weakSelf) strongSelf = weakSelf;
        tempBlock = _taskBlock;
        if (!strongSelf) {
            return;
        }
        if ([strongSelf pdfToImage:localCount]) {
            //图片转换完成,关闭_doc
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf releasePdfDoc];
            });
        } else {
            if (localCount == _openCount) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), tempBlock);
            }
        }
    };
    // 首次触发任务
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),_taskBlock);
}

//关闭_doc,图片转换完成后,不需要一直打开
-(void)releasePdfDoc {
    CGPDFDocumentRelease(_pdfDoc);
}

-(instancetype)bindDocument:(CGPDFDocumentRef)docRef {
    [self clearDoc];
    _pdfDoc = CGPDFDocumentRetain(docRef);
    [self onPdfOpened];
    return self;
}
-(instancetype)openDocument:(NSURL *)url{
    _url = url;
    //创建一个沙盒存储
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    // 在Documents文件夹中创建文件夹
    NSFileManager *fileManager = [NSFileManager defaultManager];
    _documentDirectory = [NSString stringWithFormat:@"%@/SkipICloud/pdfs/%@",[paths objectAtIndex:0],[url.absoluteString MD5]];
    [fileManager createDirectoryAtPath:_documentDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    [self clearDoc];
    CFURLRef refURL = CFBridgingRetain(url);
    _pdfDoc = CGPDFDocumentCreateWithURL(refURL);
    CFRelease(refURL);
    [self onPdfOpened];
    return self;
}

//把PDF装换成image,后台任务
-(BOOL)pdfToImage:(int)openCount {
    if (openCount!=_openCount) {
        return YES;
    }
    int index = -1;
    CGPDFDocumentRef pdfTempDoc;
    CGSize imageSize = CGSizeZero;
    //先判断有没有请求
    @synchronized(self) {
        pdfTempDoc = CGPDFDocumentRetain(_pdfDoc);
        if (pdfTempDoc) {
            if (_pageDrawing.count >0) {
                index = [_pageDrawing.firstObject intValue];
            }
            imageSize = _imageSize;
        }
    }
    
    if (!pdfTempDoc) {
        return YES;
    }
    
    int totalPages = (int)CGPDFDocumentGetNumberOfPages(_pdfDoc);
    // 没有请求
    if (index == -1) {
        // 找需要优先处理的页面
        index = [self.class findNextPage:_preloadPage maxIndex:totalPages inDir:_documentDirectory];
    }
    
    NSLog(@"pdf2image:%d\n",index);
    // index不合法
    if (index<0||index>=totalPages) {
        CGPDFDocumentRelease(pdfTempDoc);
        pdfTempDoc = nil;
        return YES;
    }
    // 绘制
    //真实绘制图片
    UIImage* image = [self.class drawPdf:pdfTempDoc size:imageSize page:index];
    CGPDFDocumentRelease(pdfTempDoc);
    pdfTempDoc = nil;
    // 保存
    [self saveImage:image page:index];
    @synchronized(self) {
        // 移除这个页面 不需要绘制了
        [_pageDrawing removeObject:@(index)];
    }
    // 查看是否需要触发界面更新
    dispatch_async(dispatch_get_main_queue(), ^{
        [self onLoadFinish:image page:index];
    });
    
    // 触发下一次任务
    return NO;
}

-(void)onLoadFinish:(UIImage *)image page:(int)page {
    if (!_cache) {
        return;
    }
    @synchronized(self) {
        // 移除这个页面 不需要读了
        [_pageReading removeObject:@(page)];
    }
    if (_pendingRequests.count == 0) {
        return;
    }
    NSMutableArray * cbs = [NSMutableArray array];
    for (NSDictionary *dic in _pendingRequests) {
        if ([[dic objectForKey:kREQUESTPAGE] intValue]==page) {
            [cbs addObject: dic];
        }
    }
    if (cbs.count>0) {
        [_cache setObject:image forKey:@(page)];
    }
    for (NSDictionary *dic in cbs) {
        [_pendingRequests removeObject:dic];
        PdfCacheCompleteBlock complete = [dic objectForKey:kREQUESTBLOCK];
        complete(page,image);
    }
}

+(UIImage *)drawPdf:(CGPDFDocumentRef) doc size:(CGSize)size page:(int)page {
    UIImage *image;
    CGPDFPageRef pageRef = CGPDFDocumentGetPage(doc,page + 1);
    CGRect pdfFrame = CGPDFPageGetBoxRect(pageRef, kCGPDFMediaBox);
    CGFloat pdfWidth = pdfFrame.size.width; //获取宽度
    CGFloat pdfHeight = pdfFrame.size.height; //获取高度
    CGFloat scaleW = size.width /pdfWidth;
    CGFloat scaleH = size.height/pdfHeight;
    CGFloat scale = 1.0;
    if (pdfWidth > size.width || pdfHeight > size.height) {
        scale = scaleW < scaleH ? scaleW : scaleH;
    }
    pdfFrame.size = CGSizeMake(pdfWidth *scale, pdfHeight *scale);
    
    UIGraphicsBeginImageContext(pdfFrame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context,0.0,pdfFrame.size.height);
    CGContextScaleCTM(context,1.0, -1.0);
    
    CGContextSaveGState(context);//记录当前绘制环境，防止多次绘画
    CGAffineTransform  pdfTransForm =CGPDFPageGetDrawingTransform(pageRef,kCGPDFCropBox,CGRectMake(pdfFrame.origin.x, pdfFrame.origin.y, pdfWidth*scale, pdfHeight*scale),0,true);//创建一个仿射变换的参数给函数。
    CGContextConcatCTM(context, pdfTransForm);//把创建的仿射变换参数和上下文环境联系起来
    CGContextDrawPDFPage(context, pageRef);//把得到的指定页的PDF数据绘制到视图上
    CGContextRestoreGState(context);//恢复图形状态
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

-(int)totalPage {
    return _pdfDoc ? (int)CGPDFDocumentGetNumberOfPages(_pdfDoc): 0;
}

+(BOOL) isFileExist:(NSString *)dir {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager fileExistsAtPath:dir];
    return result;
}

//读取
-(UIImage *)readImage:(int)page {
    NSString *path = [NSString stringWithFormat:@"%@/Image%d", _documentDirectory, page]; //
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    return image;
}

-(void)saveImage:(UIImage *)image page:(int)page {
    NSString *path = [NSString stringWithFormat:@"%@/Image%d.png", _documentDirectory, page]; //
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    [[NSFileManager defaultManager] createFileAtPath:path contents:imageData attributes:nil];
}

-(BOOL)loadPage:(int)page complete:(PdfCacheCompleteBlock)complete object:(id)object {
    if (!_cache) {
        return NO;
    }
    [self cancelLoad:object];
    
    UIImage *image = [_cache objectForKey:@(page)];
    if (image) {
        complete(page,image);
        return YES;
    } else {
        NSDictionary* req = @{ kREQUESTPAGE:@(page), kREQUESTBLOCK:complete, kREQUESTOBJECT:object};
        @synchronized(self) {
            [_pendingRequests addObject: req];
            if ([_pageReading containsObject:@(page)]) {
                return NO;
            }
            [_pageReading addObject:@(page)];
        }
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            UIImage *imageNew = [self readImage:page];
            if (imageNew) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self onLoadFinish:imageNew page:page];
                });
            } else {
                @synchronized(self) {
                    [self->_pageDrawing addObject:@(page)];
                }
            }
        });
        return NO;
    }
}

-(void)clearDoc {
    @synchronized(self) {
        if (_pdfDoc) {
            CGPDFDocumentRelease(_pdfDoc);
            _taskBlock = nil;
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
            _taskBlock = nil;
        }
        if (_cache) {
            [_cache removeAllObjects];
            _cache = nil;
        }
    }
}
//取消上一个Block
-(void)cancelLoad:(id)object {
    // 找到==object的所有request
    // 将他们移除
    NSMutableArray *arrM = [NSMutableArray array];
    @synchronized(self) {
        for (NSDictionary *dict in _pendingRequests) {
            if ([dict[kREQUESTOBJECT] isEqual:object]) {
                [arrM addObject:dict];
            }
        }
        [arrM removeAllObjects];
    }
}

// 查找下一个需要处理的页面 检查文件是否存在 0 +1 -1 +2 -2 ...
// 如果都存在 返回-1
+(int)findNextPage:(int)index maxIndex:(int)maxIndex inDir:(NSString*)dir {
    BOOL begin = YES;
    BOOL end = YES;
    if (index >= maxIndex) {
        index = maxIndex;
        end = NO; // 超过了终点
    }
    if (index < 0) {
        index = 0;
        begin = NO; // 超过了起点
    }
    
    int res = -1;
    int offset = 0;
    while (begin||end) {
        res = index + offset;
        offset = (offset<=0)?(-offset+1):(-offset);
        if (res<0) {
            begin = NO; // 超过起点了
            continue;
        } else if (res>=maxIndex) {
            end = NO; // 超过终点了
            continue;
        }
        NSString *path = [NSString stringWithFormat:@"%@/Image%d.png", dir, res];
        if (![self.class isFileExist:path]) {
            return res; // 这一页不存在
        }
    }
    return -1; // 所有页面都存在
}

//优先加载的页面,以这个页面为中心
-(void)setPreloadPage:(int)page {
    _preloadPage = page;
}
-(void)dealloc {
    [self unInit];
}
@end
