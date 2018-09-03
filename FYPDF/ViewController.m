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
#import "PdfCache.h"
#import "PDFCacheOptimize.h"
#import <QuickLook/QuickLook.h>
#import "AFNetworking.h"
#import "PDFCacheOptimize.h"

#import "ZPDFReaderController.h"


static NSString * const PDFCollectionViewCellID = @"PDFCollectionViewCellID";


#define PDFURL @"http://s2.51talk.com/textbook/2018/0123/5djlmq9fx002020008g62b0000005cu1.pdf"

@interface ViewController ()<UICollectionViewDelegate,UICollectionViewDataSource> {
    UICollectionView *_collectionView;
    PDFCacheOptimize *_cacheop;
}
@property(nonatomic,assign) NSInteger pages;
@property(nonatomic,strong) UIImage  *image;
@property (copy, nonatomic)NSURL *fileURL;

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
    [self downLoad];
}

-(void)downLoad {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    
    NSString *urlStr = PDFURL ;
    NSString *fileName = [urlStr lastPathComponent]; //获取文件名称
    NSURL *URL = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    //判断是否存在
    if([self isFileExist:fileName]) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSURL *url = [documentsDirectoryURL URLByAppendingPathComponent:fileName];
       
        self.fileURL = url;
        [self demo1];
    }else {
        NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress *downloadProgress){
            
        } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
            NSURL *url = [documentsDirectoryURL URLByAppendingPathComponent:fileName];
            return url;
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            self.fileURL = filePath;
            [self demo1];
        }];
        [downloadTask resume];
    }
}

//判断文件是否已经在沙盒中存在
-(BOOL) isFileExist:(NSString *)fileName {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *path = [paths objectAtIndex:0];
    NSString *filePath = [path stringByAppendingPathComponent:fileName];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL result = [fileManager fileExistsAtPath:filePath];
    return result;
}

//MARK:将pdf转成图片再查看
-(void)demo1 {
    _cacheop = [[PDFCacheOptimize alloc] init:self.view.frame.size];
    [_cacheop openDocument:self.fileURL];
    self.pages = [_cacheop totalPage];
    
    UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
    layout.itemSize = self.view.frame.size;
    layout.minimumLineSpacing = 0;
    layout.minimumInteritemSpacing = 0;
    layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
    _collectionView = [[UICollectionView alloc]initWithFrame:self.view.frame collectionViewLayout:layout];
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
    [_cacheop setPreloadPage:(int)indexPath.row];
    if (![_cacheop loadPage:(int)indexPath.row complete:^(int page, UIImage *image) {
        if (page == cell.page) {
               cell.imageView.image = image;
        }
    } object:cell]) {
        cell.imageView.image = [UIImage imageNamed:@"place"];
    }
    return cell;
}

@end
