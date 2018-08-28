//
//  PDFCacheOptimize.m
//  FYPDF
//
//  Created by wang on 2018/8/23.
//  Copyright © 2018年 wang. All rights reserved.
//

#import "PDFCacheOptimize.h"

#define kREQUESTPAGE @"page"
#define kREQUESTBLOCK @"block"
#define kREQUESTOBJECT @"object"

typedef void(^TaskBlock)(void);

@interface PDFCacheOptimize (){
    int _openCount;  //打开文档的计数
    NSCache *_cache; //仅仅ui线程使用
    CGPDFDocumentRef _pdfDoc; // 跨线程
    CGSize _imageSize; // 跨线程
    NSString * _documentDirectory; // 跨线程
    NSMutableArray* _pageReading; // 需要读取文件的
    NSMutableArray* _pageDrawing; // 需要画的
    int _preloadPage; //优先加载的页面
    TaskBlock _taskBlock;
    NSMutableArray *_pendingRequests; //加载请求
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
        //创建一个沙盒存储
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        _documentDirectory = [paths objectAtIndex:0];
    }
    return self;
}

#pragma mark:每次打开文档都会打开block,获取沙盒存储中的图片
-(void)onPdfOpened {
    _preloadPage = 0;
    int localCount = ++_openCount;
    typeof(self) __weak weakSelf = self;
    _taskBlock = ^() {
        [weakSelf pdfToImage:localCount];
    };
    // 首次触发任务
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0),_taskBlock);
}
-(instancetype)bindDocument:(CGPDFDocumentRef)docRef {
    [self clearDoc];
    _pdfDoc = CGPDFDocumentRetain(docRef);
    [self onPdfOpened];
    return self;
}
-(instancetype)openDocument:(NSURL *)url{
    [self clearDoc];
    CFURLRef refURL = CFBridgingRetain(url);
    _pdfDoc = CGPDFDocumentCreateWithURL(refURL);
    CFRelease(refURL);
    [self onPdfOpened];
    return self;
}

//把PDF装换成image,后台任务
-(void)pdfToImage:(int)openCount {
    if (openCount!=_openCount) {
        return;
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
        return;
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
        return;
    }
    
    // 绘制
    //真实绘制图片
    UIImage* image = [self.class drawPdf:pdfTempDoc size:imageSize page:index];
    CGPDFDocumentRelease(pdfTempDoc);
    pdfTempDoc = nil;

    // 保存
    [self saveImage:image page:index];
    
    dispatch_block_t blk = nil;
    @synchronized(self) {
        // 移除这个页面 不需要绘制了
        [_pageDrawing removeObject:@(index)];
        blk = _taskBlock;
    }
    // 查看是否需要触发界面更新
    dispatch_async(dispatch_get_main_queue(), ^{
        [self onLoadFinish:image page:index];
    });
    
    // 触发下一次任务
    if (blk) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), blk);
    }
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
    
    UIGraphicsBeginImageContext(size);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context,0.0,size.height);
    CGContextScaleCTM(context,1.0, -1.0);
    CGPDFPageRef  pageRef =CGPDFDocumentGetPage(doc,page + 1);
    CGContextSaveGState(context);//记录当前绘制环境，防止多次绘画
    CGAffineTransform  pdfTransForm =CGPDFPageGetDrawingTransform(pageRef,kCGPDFCropBox,CGRectMake(0, 0, size.width, size.height),0,true);//创建一个仿射变换的参数给函数。
    CGContextConcatCTM(context, pdfTransForm);//把创建的仿射变换参数和上下文环境联系起来
    CGContextDrawPDFPage(context, pageRef);//把得到的指定页的PDF数据绘制到视图上
    CGContextRestoreGState(context);//恢复图形状态
//    CGPDFDocumentRelease(doc);
    image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return image;
}

-(int)totalPage {
    return _pdfDoc ? (int)CGPDFDocumentGetNumberOfPages(_pdfDoc): 0;
}

+(BOOL) isFileExist:(NSString *)dir page:(int)page {
    NSString *path = [NSString stringWithFormat:@"%@/Image%d", dir,page];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager fileExistsAtPath:path];
    return result;
}

//读取
-(UIImage *)readImage:(int)page {
    NSString *path = [NSString stringWithFormat:@"%@/Image%d", _documentDirectory,page]; //
    UIImage *image = [[UIImage alloc] initWithContentsOfFile:path];
    return image;
}

-(void)saveImage:(UIImage *)image page:(int)page {
    NSString *path = [NSString stringWithFormat:@"%@/Image%d", _documentDirectory,page];
    NSData *imageData = UIImageJPEGRepresentation(image, 1.0);
    [imageData writeToFile:path atomically:YES];
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
    // 遍历这些request中的page 移除所有的reading+drawing
    NSMutableArray *arrM = [NSMutableArray array];
    @synchronized(self) {
        for (NSDictionary *dict in _pendingRequests) {
            if ([dict[kREQUESTOBJECT] isEqual:object]) {
                [arrM addObject:dict[kREQUESTPAGE]];
            }
        }
        for (NSString *pageString in arrM) {
            [_pageReading removeObject:pageString];
            [_pageDrawing removeObject:pageString];
        }
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
        if (![self.class isFileExist:dir page:res]) {
            return res; // 这一页不存在
        }
    }
    return -1; // 所有页面都存在
}

//优先加载的页面,以这个页面为中心
-(void)setPreloadPage:(int)page {
    _preloadPage = page;
}

+(CGFloat)screenScale {
    CGFloat scale = ([[UIScreen mainScreen] respondsToSelector:@selector(scale)]) ? [[[UIScreen mainScreen] valueForKey:@"scale"] floatValue] : 1.0f;
    return scale;
}



@end
