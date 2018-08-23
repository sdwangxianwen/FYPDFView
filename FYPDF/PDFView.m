//
//  PDFView.m
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import "PDFView.h"

@implementation PDFView {
    CGPDFDocumentRef  documentRef;//用它来记录传递进来的PDF资源数据
    int  pageNum;//记录需要显示页码
}

- (instancetype)initWithFrame:(CGRect)frame documentRef:(CGPDFDocumentRef)docRef andPageNum:(int)page {
    self= [super initWithFrame:frame];
    documentRef= docRef;
    pageNum= page;
    self.backgroundColor= [UIColor whiteColor];
    return self;
    
}


-(void)setPage:(int) page {
    pageNum = page;
    [self setNeedsDisplay];
}


//重写- (void)drawRect:(CGRect)rect方法

- (void)drawRect:(CGRect)rect {
    [self drawPDFIncontext:UIGraphicsGetCurrentContext()];//将当前的上下文环境传递到方法中，用于绘图
}
//- (void)drawRect:(CGRect)rect具体的内容
- (void)drawPDFIncontext:(CGContextRef)context {
    CGContextTranslateCTM(context,0.0,self.frame.size.height);
    CGContextScaleCTM(context,1.0, -1.0);
    CGPDFPageRef  pageRef =CGPDFDocumentGetPage(documentRef,pageNum);
    CGContextSaveGState(context);//记录当前绘制环境，防止多次绘画
    CGAffineTransform  pdfTransForm =CGPDFPageGetDrawingTransform(pageRef,kCGPDFCropBox,self.bounds,0,true);//创建一个仿射变换的参数给函数。
    CGContextConcatCTM(context, pdfTransForm);//把创建的仿射变换参数和上下文环境联系起来
    CGContextDrawPDFPage(context, pageRef);//把得到的指定页的PDF数据绘制到视图上
    CGContextRestoreGState(context);//恢复图形状态
}

@end
