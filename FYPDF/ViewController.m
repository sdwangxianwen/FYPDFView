//
//  ViewController.m
//  FYPDF
//
//  Created by wang on 2018/8/22.
//  Copyright © 2018年 wang. All rights reserved.
//

#import "ViewController.h"
#import "PDFCollectionViewCell.h"
#import <Foundation/Foundation.h>
#import "PDFView.h"
#import "PdfCache.h"

static NSString * const PDFCollectionViewCellID = @"PDFCollectionViewCellID";


#define PDFURL @"http://s2.51talk.com/textbook/2018/0122/5dj8vyv9b002020008g62b00000080u1.pdf"

@interface ViewController ()<UICollectionViewDelegate,UICollectionViewDataSource> {
    UICollectionView *_collectionView;
    CGPDFDocumentRef _docRef; //需要获取的PDF资源文件
    PdfCache *_cache;
}
@property(nonatomic,assign) NSInteger pages;
@property(nonatomic,strong) UIImage  *image;

@end

@implementation ViewController

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear: animated];
    // 设置屏幕方向
    [[UIDevice currentDevice] setValue:@(UIDeviceOrientationLandscapeLeft) forKey:@"orientation"];
    [UIViewController attemptRotationToDeviceOrientation];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _cache = [[PdfCache alloc] init:CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width)];
    [_cache openDocument:[NSURL URLWithString:PDFURL]];
    self.pages = [_cache totalPage];

    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width);
    layout.minimumLineSpacing = 0;
    layout.minimumInteritemSpacing = 0;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    
    _collectionView = [[UICollectionView alloc]initWithFrame:CGRectMake(0, 0, [UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width) collectionViewLayout:layout];
    [self.view addSubview:_collectionView];
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    [_collectionView registerClass:[PDFCollectionViewCell class] forCellWithReuseIdentifier:PDFCollectionViewCellID];
    _collectionView.pagingEnabled = YES;
    _collectionView.showsVerticalScrollIndicator = NO;
    _collectionView.showsHorizontalScrollIndicator = NO;
    _collectionView.bounces = NO;
    

    
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.pages;
}
-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PDFCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PDFCollectionViewCellID forIndexPath:indexPath];
    cell.backgroundColor = [UIColor whiteColor];
    cell.page = indexPath.row;
    if (![_cache loadPage:indexPath.row complete:^(int page, UIImage *image) {
        if (page == cell.page) {
            cell.imageView.image = image;
        }
    }]){
        cell.imageView.image = [UIImage imageNamed:@"place"];
    }
    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(PDFCollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
  
   
}

@end
