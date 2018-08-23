//
//  PDFCollectionViewCell.h
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PDFCollectionViewCell : UICollectionViewCell
@property(nonatomic,strong) UIImageView  *imageView;
@property(nonatomic,assign) NSInteger page;
@end
