//
//  PDFView.h
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PDFView : UIView
- (instancetype)initWithFrame:(CGRect)frame documentRef:(CGPDFDocumentRef)docRef andPageNum:(int)page;

-(void)setPage:(int) page;
@end
