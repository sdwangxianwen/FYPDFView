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
#import "PDFCacheOptimize.h"
#import <QuickLook/QuickLook.h>
#import "AFNetworking.h"

#import "ZPDFReaderController.h"


static NSString * const PDFCollectionViewCellID = @"PDFCollectionViewCellID";


#define PDFURL @"http://s2.51talk.com/textbook/2018/0122/5dj8vyv9b002020008g62b00000080u1.pdf"

@interface ViewController ()<UICollectionViewDelegate,UICollectionViewDataSource,QLPreviewControllerDataSource> {
    UICollectionView *_collectionView;
    CGPDFDocumentRef _docRef; //需要获取的PDF资源文件
    PdfCache *_cache;
    PDFCacheOptimize *_cacheop;
    QLPreviewController *_previewController;
    UIButton *_rightBtn;
    UIButton *_leftBtn;
    NSInteger index;
}
@property(nonatomic,assign) NSInteger pages;
@property(nonatomic,strong) UIImage  *image;
@property (copy, nonatomic)NSURL *fileURL;
@property(nonatomic,assign) BOOL isTap;
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
    index = 0;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"QLPreviewController" style:(UIBarButtonItemStyleDone) target:self action:@selector(demo2)];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"pageviewcontroller" style:(UIBarButtonItemStyleDone) target:self action:@selector(demo3)];
    [self demo1];
}
//MARK:使用pageVIew,效果有卡顿
-(void)demo3 {
//    [self downLoad];
    ZPDFReaderController *pdfVc = [[ZPDFReaderController alloc] init];
    pdfVc.titleText = @"阿里巴巴java开发手册";
    pdfVc.url = self.fileURL;
    [self.navigationController pushViewController:pdfVc animated:YES];
}

//MARK:使用QLPreviewController直接查看PDF
-(void)demo2 {
    _previewController  = [[QLPreviewController alloc]  init];
    _previewController.dataSource  = self;
    _previewController.navigationItem.rightBarButtonItem=nil;
    [self downLoad];
}

-(void)downLoad {
    NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
    AFURLSessionManager *manager = [[AFURLSessionManager alloc] initWithSessionConfiguration:configuration];
    NSString *urlStr = PDFURL ;
//    NSString *urlStr = @"https://www.tutorialspoint.com/ios/ios_tutorial.pdf";
    NSString *fileName = [urlStr lastPathComponent]; //获取文件名称
    NSURL *URL = [NSURL URLWithString:urlStr];
    NSURLRequest *request = [NSURLRequest requestWithURL:URL];
    
    //判断是否存在
    if([self isFileExist:fileName]) {
        NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
        NSURL *url = [documentsDirectoryURL URLByAppendingPathComponent:fileName];
        self.fileURL = url;
        //        [self presentViewController:_previewController animated:YES completion:nil];
        [self.navigationController pushViewController:_previewController animated:YES];
    }else {
        
        NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:request progress:^(NSProgress *downloadProgress){
            
        } destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            NSURL *documentsDirectoryURL = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:NO error:nil];
            NSURL *url = [documentsDirectoryURL URLByAppendingPathComponent:fileName];
            return url;
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            self.fileURL = filePath;
            [self.navigationController pushViewController:_previewController animated:YES];
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


-(id<QLPreviewItem>)previewController:(QLPreviewController *)controller previewItemAtIndex:(NSInteger)index {
    return self.fileURL;
}

- (NSInteger)numberOfPreviewItemsInPreviewController:(QLPreviewController *)previewController{
    return 1;
}
-(void)scrollViewDidScroll:(UIScrollView *)scrollView {
    index = scrollView.contentOffset.x/self.view.bounds.size.width;
}


//MARK:将pdf转成图片再查看
-(void)demo1 {
    _cache = [[PdfCache alloc] init:CGSizeMake([UIScreen mainScreen].bounds.size.height, [UIScreen mainScreen].bounds.size.width)];
    [_cache openDocument:[NSURL URLWithString:PDFURL]];
    self.pages = [_cache totalPage];
    
    //    _cacheop = [[PDFCacheOptimize alloc] init:CGSizeMake([UIScreen mainScreen].bounds.size.width, [UIScreen mainScreen].bounds.size.height)];
    //    [_cacheop openDocument:[NSURL URLWithString:PDFURL]];
    //    self.pages = [_cacheop totalPage];
    
    
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
    
    _leftBtn = [[UIButton alloc] init];
    [_leftBtn setBackgroundColor:[UIColor brownColor]];
    _leftBtn.frame = CGRectMake(0, _collectionView.frame.size.height/2, 88, 44);
    [_leftBtn setTitle:@"上一个" forState:(UIControlStateNormal)];
    [[UIApplication sharedApplication].keyWindow addSubview:_leftBtn];
    _rightBtn = [[UIButton alloc] init];
    [_rightBtn setBackgroundColor:[UIColor brownColor]];
    [_rightBtn setTitle:@"下一个" forState:(UIControlStateNormal)];
    _rightBtn.frame = CGRectMake(_collectionView.frame.size.width - 88, _collectionView.frame.size.height/2, 88, 44);
    [[UIApplication sharedApplication].keyWindow addSubview:_rightBtn];
    _leftBtn.tag = 1000;
    _rightBtn.tag = 2000;
    [_leftBtn addTarget:self action:@selector(btnClick:) forControlEvents:(UIControlEventTouchUpInside)];
    
    [_rightBtn addTarget:self action:@selector(btnClick:) forControlEvents:(UIControlEventTouchUpInside)];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        _rightBtn.hidden = YES;
        _leftBtn.hidden = YES;

    });
}
-(void)btnClick:(UIButton *)btn {
    
    if (btn.tag == 2000) {
        index++;
        index = MIN(index++, self.pages-1);
    } else {
        index--;
        index = MAX(0, index--);
    }
    NSIndexPath *indexpath = [NSIndexPath indexPathForRow:index inSection:0];
    [_collectionView scrollToItemAtIndexPath:indexpath atScrollPosition:UICollectionViewScrollPositionCenteredHorizontally animated:YES];
}

-(NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section{
    return self.pages;
}
-(UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    PDFCollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:PDFCollectionViewCellID forIndexPath:indexPath];
    cell.backgroundColor = [UIColor whiteColor];
    cell.page = indexPath.row;
    [_cacheop setPreloadPage:(int)indexPath.row];
//    if (![_cacheop loadPage:(int)indexPath.row complete:^(int page, UIImage *image) {
//        if (page == cell.page) {
//            dispatch_async(dispatch_get_main_queue(), ^{
//               cell.imageView.image = image;
//            });
//        }
//    } object:@"22"]) {
//        cell.imageView.image = [UIImage imageNamed:@"place"];
//    }
    if (![_cache loadPage:indexPath.row complete:^(int page, UIImage *image) {
        if (page == cell.page) {
            cell.imageView.image = image;
        }
    }]){
        cell.imageView.image = [UIImage imageNamed:@"happyPracticeHolder"];
    }
    return cell;
}

-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
 
    if (self.isTap) {
        self.isTap = NO;
        [UIView animateWithDuration:0.3 animations:^{
            [self.navigationController setNavigationBarHidden:NO];
            _leftBtn.hidden = NO;
            _rightBtn.hidden = NO;
        }];
    } else {
        self.isTap = YES;
        [UIView animateWithDuration:0.3 animations:^{
            _leftBtn.hidden = YES;
            _rightBtn.hidden = YES;
            [self.navigationController setNavigationBarHidden:YES];
        }];
    }
}
-(void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _leftBtn.hidden = _rightBtn.hidden = YES;
}
@end
