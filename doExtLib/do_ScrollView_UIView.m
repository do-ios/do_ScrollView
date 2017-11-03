//
//  TYPEID_View.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_ScrollView_UIView.h"

#import "doInvokeResult.h"
#import "doIPage.h"
#import "doIScriptEngine.h"
#import "doUIModuleHelper.h"
#import "doScriptEngineHelper.h"
#import "doUIContainer.h"
#import "doISourceFS.h"
#import "doEGORefreshTableHeaderView.h"
#import "doServiceContainer.h"
#import "doILogEngine.h"
#import "doJsonHelper.h"
#import "doIOHelper.h"
#import "doIDataFS.h"

static NSString *didBeginEdit = @"DODidBeginEditNotification";
static NSString *keyboardShow = @"DOKeyboardShowNotification";

@interface do_ScrollView_UIView()<doEGORefreshTableDelegate>
@property(nonatomic,strong) doEGORefreshTableHeaderView *doEGOHeaderView;
@property (nonatomic,strong) UIView *footerView;
@property (nonatomic,strong) UIActivityIndicatorView *activityView;
@property (nonatomic, assign) float currentFooterViewMoveUpOffset; // 当前footerView上拉距离
@property (nonatomic, assign) float currentHeadViewMoveDownOffset; // 当前headview下来距离
@property (nonatomic, assign) BOOL endDrag;
@property (nonatomic, strong) UIView * screenShotView;
@end
@implementation do_ScrollView_UIView
{
    BOOL _direction;
    
    id<doIUIModuleView> _childView;
    doUIModule *_headViewModel;
    doUIModule *_footerViewModel;
    id<doIUIModuleView> _headView;
    id<doIUIModuleView> _footView;
    BOOL _isHeaderVisible;
    BOOL _isFooterVisible;
    BOOL _firstLoad;//标示UIRefreshControl第一次添加
    BOOL _isRefreshing;
    
    doUIContainer *_headerContainer;
    doUIContainer *_footerContainer;

    doInvokeResult *_invokeResult1;
    NSMutableDictionary *_node;
    
    doInvokeResult *_scrollEventResult;
    
    CGFloat _oldLeft,_oldTop;

    BOOL _isPosition;
    BOOL _pushStatus;
    BOOL _pullStatus;
    
    UIView *_firstResponse;
    CGRect _keyBoardFrame;
    CGSize originContentSize;
}

- (instancetype)init
{
    if(self = [super init])
        self.delegate = self;
    return self;
}

#pragma mark - doIUIModuleView协议方法（必须）
//引用Model对象
- (void) LoadView: (doUIModule *) _doUIModule
{
    _model = (typeof(_model)) _doUIModule;
    NSInteger childCount = _model.ChildUIModules.count;
    
    @try {
        if(childCount > 1)
            [NSException raise:@"doScrollView" format:@"只允许加入一个子视图",nil];
        else if(childCount == 1)
        {
            doUIModule *childViewModel = [_model.ChildUIModules objectAtIndex:0];
            _childView = childViewModel.CurrentUIModuleView;
            [self addSubview:(UIView *) _childView];
        }
        else
            [NSException raise:@"doScrollView" format:@"没有子视图",nil];
        
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
        
    }
    [self change_isShowbar:@"false"];
    _firstLoad = YES;
    _isHeaderVisible = NO;
    _isFooterVisible = NO;

    _isPosition = YES;
    _pushStatus = NO;
    _pullStatus = NO;
    _isRefreshing = NO;
    //键盘处理
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardShow:) name:keyboardShow object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didBeginEdit:) name:didBeginEdit object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardDidHid:) name:UIKeyboardWillHideNotification object:nil];
    _endDrag = false;
}

- (void)loadModuleJS
{
    if (_headerContainer) {
        NSString *header = [_model GetPropertyValue:@"headerView"];
        [_headerContainer LoadDefalutScriptFile:header];
    }
    if (_footerContainer) {
        NSString *header = [_model GetPropertyValue:@"footerView"];
        [_footerContainer LoadDefalutScriptFile:header];
    }
}
//销毁所有的全局对象
- (void) OnDispose
{
    //自定义的全局属性
    //销毁model后，自动销毁view
    if(_headView)
    {
        [((UIView *)_headView) removeFromSuperview];
        [[_headView GetModel] Dispose];
        _headView = nil;
    }
    if(_footView)
    {
        [((UIView *)_footView) removeFromSuperview];
        [[_footView GetModel] Dispose];
        _footView = nil;
    }
    [_headerContainer Dispose];
    _headerContainer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
//实现布局
- (void) OnRedraw
{
    //重新调整视图的x,y,w,h
    [doUIModuleHelper OnRedraw:_model];
    if(_childView)  [_childView OnRedraw];
    if(_headView)  [_headView OnRedraw];
    if(_footView)  [_footView OnRedraw];

    [self setContent];
    BOOL isAutoHeight = [[_model GetPropertyValue:@"height"] isEqualToString:@"-1"];
    BOOL isAutoWidth = [[_model GetPropertyValue:@"width"] isEqualToString:@"-1"];
    if(isAutoHeight||isAutoWidth)
    {
        [self onResetFrame];
    }
    
    _oldLeft = self.contentOffset.x / _model.XZoom;
    _oldTop = self.contentOffset.y / _model.YZoom;
    
    originContentSize = self.contentSize;
    
    if (!_isHeaderVisible) {
        if (_headView) {
            [((UIView *)_headView) removeFromSuperview];
        }
    }
    if (!_isFooterVisible) {
        if (self.footerView) {
            [self.footerView removeFromSuperview];
        }
    }
}
- (void) onResetFrame
{
    CGFloat _x = _model.RealX;
    CGFloat _y = _model.RealY;
    CGFloat _w = _model.RealWidth;
    CGFloat _h = _model.RealHeight;
    CGFloat parentHeight = [self getParentViewSize].height-_y;
    CGFloat parentWidth = [self getParentViewSize].width-_x;
    BOOL isAutoWidth = [[_model GetPropertyValue:@"width"] isEqualToString:@"-1"];
    BOOL isAutoHeight = [[_model GetPropertyValue:@"height"] isEqualToString:@"-1"];
    float top = 0;
    float left = 0;
    if(!_direction)
    {
        for (int i = 0;i<(int)_model.ChildUIModules.count; i++)
        {
            doUIModule* _childUI = _model.ChildUIModules[i];
            NSString *value = [_childUI GetPropertyValue:@"visible"];
            BOOL isVisible ;
            if (!value || [value isEqualToString:@""]) {
                isVisible = YES;
            }else
                isVisible = [value boolValue];
            if (!isVisible) {
                continue;
            }
            UIView* _view = (UIView*)_childUI.CurrentUIModuleView;
            if (_view == nil) continue;
            [self bringSubviewToFront:_view];
            float _childX =_childUI.Margins.l;
            [_childUI SetPropertyValue:@"x" :[@(_childX) stringValue]];
            float _childY =top+_childUI.Margins.t;
            [_childUI SetPropertyValue:@"y" :[@(_childY) stringValue]];
            
            //真实frame
            [_view setFrame:CGRectMake(_childUI.RealX, _childUI.RealY,CGRectGetWidth(_view.frame),CGRectGetHeight(_view.frame))];
            
            //设计坐标
            top = _childY + (CGRectGetHeight(_view.frame)/_childUI.YZoom)+_childUI.Margins.b;
            
            CGFloat tmpleft = _childX + CGRectGetWidth(_view.frame)/_childUI.XZoom+_childUI.Margins.r;
            if (tmpleft>left) {
                left = tmpleft;
            }
        }
    }else{
        for (int i = 0;i<(int)_model.ChildUIModules.count; i++)
        {
            doUIModule* _childUI = _model.ChildUIModules[i];
            NSString *value = [_childUI GetPropertyValue:@"visible"];
            BOOL isVisible ;
            if (!value || [value isEqualToString:@""]) {
                isVisible = YES;
            }else
                isVisible = [value boolValue];
            if (!isVisible) {
                continue;
            }
            UIView* _view = (UIView*)_childUI.CurrentUIModuleView;
            if (_view == nil) continue;
            [self bringSubviewToFront:_view];
            float _childX =left+_childUI.Margins.l;
            [_childUI SetPropertyValue:@"x" :[@(_childX) stringValue]];
            float _childY =_childUI.Margins.t;
            [_childUI SetPropertyValue:@"y" :[@(_childY) stringValue]];
            [_view setFrame:CGRectMake(_childUI.RealX, _childUI.RealY,CGRectGetWidth(_view.frame),CGRectGetHeight(_view.frame))];
            
            left = _childX + (CGRectGetWidth(_view.frame)/_childUI.XZoom)+_childUI.Margins.r;
            
            CGFloat tmpTop = _childY + (CGRectGetHeight(_view.frame)/_childUI.YZoom)+_childUI.Margins.b;
            if (tmpTop>top) {
                top = tmpTop;
            }
        }
    }
    if(isAutoHeight)
        _h = top*_model.YZoom;
    if(isAutoWidth)
        _w = left*_model.XZoom;
    [self setFrame:CGRectMake(_x, _y, MIN(_w, parentWidth), MIN(_h, parentHeight))];
}
- (void)AdjustContentSize
{
    CGRect r = [self getContentSize];
    self.contentSize = r.size;
    originContentSize = self.contentSize;
    [self onResetFrame];
}
- (CGRect)getContentSize
{
    int count = self.subviews.count;
    UIView *v = [UIView new];
    for (int i = 0;i<count;i++) {
        v = (UIView *)[self.subviews objectAtIndex:i];
        if ([v respondsToSelector:@selector(GetModel)]) {
            break;
        }
    }
    return v.frame;
}
- (CGSize)getParentViewSize
{
    doUIModule *parentModule = _model.ParentUICollection;
    if (!parentModule) {
        parentModule = _model.UIContainer.RootView;
    }
    UIView *parentView = (UIView *)parentModule.CurrentUIModuleView;
    if (parentView) {
        return parentView.frame.size;
    }
    else
    {
        return CGSizeZero;
    }
}
#pragma mark - TYPEID_IView协议方法（必须）
#pragma mark - Changed_属性
/*
 如果在Model及父类中注册过 "属性"，可用这种方法获取
 NSString *属性名 = [(doUIModule *)_model GetPropertyValue:@"属性名"];
 
 获取属性最初的默认值
 NSString *属性名 = [(doUIModule *)_model GetProperty:@"属性名"].DefaultValue;
 */
#pragma mark - Changed

- (void)change_canScrollToTop:(NSString *)newValue
{
    //自己的代码实现
    BOOL isScroll = [newValue boolValue];
    self.scrollsToTop = isScroll;
}

- (void)change_isShowbar:(NSString *)isShowbar
{
    BOOL isShow = (!isShowbar||[isShowbar isEqualToString:@""])?NO:[isShowbar boolValue];
    self.showsHorizontalScrollIndicator = isShow;
    self.showsVerticalScrollIndicator = isShow;
}

- (void)change_direction:(NSString *)direction
{
    if([direction isEqualToString:@"horizontal"])
    {
        _direction = YES;
    }
    else if ([direction isEqualToString:@"vertical"])
    {
        _direction = NO;
    }
    [self setContent];
}
- (void)change_headerView:(NSString *)herderView
{
    id<doIPage> pageModel = _model.CurrentPage;
    doSourceFile *fileName = [pageModel.CurrentApp.SourceFS GetSourceByFileName:herderView];
    @try {
        if(!fileName)
        {
            [NSException raise:@"scrollView" format:@"无效的headView路径:%@",herderView,nil];
        }
        _headerContainer = [[doUIContainer alloc] init:pageModel];
        [_headerContainer LoadFromFile:fileName:nil:nil];
        doUIModule *headViewModel = _headerContainer.RootView;
        if (headViewModel == nil)
        {
            [NSException raise:@"scrollView" format:@"创建viewModel失败",nil];
        }
        UIView *insertView = (UIView*)headViewModel.CurrentUIModuleView;
        _headView = headViewModel.CurrentUIModuleView;
        if (insertView == nil)
        {
            [NSException raise:@"scrollView" format:@"创建view失败"];
        }
        _firstLoad = NO;
        if (insertView) {
            if (!_direction) {
                [self addSubview:insertView];
            }
        }
        if (pageModel.ScriptEngine) {
            [_headerContainer LoadDefalutScriptFile:herderView];
        }

    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
}
- (void)change_footerView:(NSString *)newValue
{
    id<doIPage> pageModel = _model.CurrentPage;
    doSourceFile *fileName = [pageModel.CurrentApp.SourceFS GetSourceByFileName:newValue];
    @try {
        if(!fileName)
        {
            [NSException raise:@"scrollview" format:@"无效的footView:%@",newValue,nil];
            return;
        }
        _footerContainer = [[doUIContainer alloc] init:pageModel];
        [_footerContainer LoadFromFile:fileName:nil:nil];
        _footerViewModel = _footerContainer.RootView;
        if (_footerViewModel == nil)
        {
            [NSException raise:@"scrollview" format:@"创建view失败",nil];
            return;
        }
        UIView *insertView = (UIView*)_footerViewModel.CurrentUIModuleView;
        _footView = _footerViewModel.CurrentUIModuleView;
        if (insertView == nil)
        {
            [NSException raise:@"scrollview" format:@"创建view失败"];
            return;
        }
        if (insertView) {
            self.footerView = insertView;
            if (!_direction) {
                [self addSubview:insertView];
            }
        }
        if (pageModel.ScriptEngine) {
            [_footerContainer LoadDefalutScriptFile:newValue];
        }
        
    }
    @catch (NSException *exception) {
        [[doServiceContainer Instance].LogEngine WriteError:exception :exception.description];
        doInvokeResult* _result = [[doInvokeResult alloc]init];
        [_result SetException:exception];
    }
}
- (UIView *)getFooterView
{
    CGRect frame;
    frame =  CGRectMake(0, self.contentSize.height, _model.RealWidth , _footerView.frame.size.height);

    if (self.footerView) {
        //        self.footerView.frame = frame;
        return self.footerView;
    }
    UIView *footerView = [[UIView alloc]init];
    footerView.backgroundColor = self.backgroundColor;
    frame = CGRectMake(0, frame.origin.y, frame.size.width, 80);
    footerView.frame = frame;
    //1.创建lab
    UILabel *lab = [[UILabel alloc]init];
    lab.frame = CGRectMake(0, 0, 100, 80);
    lab.text = @"加载更多";
    lab.font = [UIFont systemFontOfSize:17];
    lab.center = CGPointMake(CGRectGetWidth(footerView.bounds)/2, CGRectGetHeight(footerView.bounds)/2);
    lab.textColor = [UIColor lightGrayColor];
    lab.textAlignment = NSTextAlignmentCenter;
    [footerView addSubview:lab];
    
    //创建progressbar
    UIActivityIndicatorView *progress = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    progress.hidesWhenStopped = YES;
    progress.frame = CGRectMake(0, 20,  footerView.frame.size.width, 80);
    progress.center = CGPointMake(CGRectGetWidth(footerView.bounds)/2-CGRectGetWidth(lab.bounds)/2-20, CGRectGetHeight(footerView.bounds)/2);
    
    self.activityView = progress;
    [footerView addSubview:progress];
    [self.footerView removeFromSuperview];
    self.footerView = footerView;
    return footerView;
}

- (void)change_isHeaderVisible:(NSString *)newValue
{
    _isHeaderVisible = [newValue boolValue];
}
- (void)change_isFooterVisible:(NSString *)newValue
{
    _isFooterVisible = [newValue boolValue];
}

#pragma mark -
#pragma mark - 同步异步方法的实现
/*
 1.参数节点
 doJsonNode *_dictParas = [parms objectAtIndex:0];
 在节点中，获取对应的参数
 NSString *title = [_dictParas GetOneText:@"title" :@"" ];
 说明：第一个参数为对象名，第二为默认值
 
 2.脚本运行时的引擎
 id<doIScriptEngine> _scritEngine = [parms objectAtIndex:1];
 
 同步：
 3.同步回调对象(有回调需要添加如下代码)
 doInvokeResult *_invokeResult = [parms objectAtIndex:2];
 回调信息
 如：（回调一个字符串信息）
 [_invokeResult SetResultText:((doUIModule *)_model).UniqueKey];
 异步：
 3.获取回调函数名(异步方法都有回调)
 NSString *_callbackName = [parms objectAtIndex:2];
 在合适的地方进行下面的代码，完成回调
 新建一个回调对象
 doInvokeResult *_invokeResult = [[doInvokeResult alloc] init];
 填入对应的信息
 如：（回调一个字符串）
 [_invokeResult SetResultText: @"异步方法完成"];
 [_scritEngine Callback:_callbackName :_invokeResult];
 */
//同步
-(void)toBegin:(NSArray *)parms
{
    CGPoint p = CGPointZero;
    if(_direction)
        p = CGPointMake(.1, self.contentOffset.y);
    else
        p = CGPointMake(self.contentOffset.x, .1);

    [self setContentOffset:p animated:YES];
    //同步方法会主动传一个回调对象过来，不需要新建
    doInvokeResult * invokeResult = [parms objectAtIndex:2];
    //_invokeResult只需要填入数据即可，前端有他的引用，可以获取返回的内容
    [invokeResult SetResultText:_model.UniqueKey];
}
- (void)toEnd:(NSArray *)parms
{
    CGPoint p = CGPointZero;
    if(_direction)
        p = CGPointMake(self.contentSize.width-CGRectGetWidth(self.frame), self.contentOffset.y);
    else
        p = CGPointMake(self.contentOffset.x, self.contentSize.height-CGRectGetHeight(self.frame));
    [self setContentOffset:p animated:YES];
}
- (void)getOffsetX:(NSArray *)_parms
{
    doInvokeResult *invokeResult = [_parms objectAtIndex:2];
    NSString *offsetX = [NSString stringWithFormat:@"%f",self.contentOffset.x];
    [invokeResult SetResultText:offsetX];
}
- (void)getOffsetY :(NSArray *)_parms
{
    doInvokeResult *invokeResult = [_parms objectAtIndex:2];
    NSString *offsetY = [NSString stringWithFormat:@"%f",self.contentOffset.y];
    [invokeResult SetResultText:offsetY];
}
- (void)rebound:(NSArray *)parms
{
    _isRefreshing = NO;
    _pushStatus = NO;
    _pullStatus = NO;
    _currentHeadViewMoveDownOffset = 0.0;
    _currentFooterViewMoveUpOffset = 0.0;
    _endDrag = false;
    if (!_headView) {
        [self.doEGOHeaderView egoRefreshScrollViewDataSourceDidFinishedLoading:self];
    }
    [UIView animateWithDuration:0.2 animations:^{
        self.contentInset = UIEdgeInsetsMake(0, 0, 0, 0);
    }];
    
    [_activityView stopAnimating];

}
- (void)scrollTo:(NSArray *)parms
{
    self.scrollEnabled = NO;
    NSDictionary * _dictParas = [parms objectAtIndex:0];
    float position = [doJsonHelper GetOneFloat:_dictParas :@"offset" :-1];
    if (position<=0) {
        position = 0;
    }

    CGPoint p = self.contentOffset;
    if (_direction) {
        if (position) {
            position *= _model.XZoom;
            CGFloat maxValue = self.contentSize.width-CGRectGetWidth(self.frame);
            if (position>maxValue) {
                position = maxValue;
            }
            p.x = position;
        }
    }else
        if (position) {
            position *= _model.YZoom;
            CGFloat maxValue = self.contentSize.height-CGRectGetHeight(self.frame);
            if (position>maxValue) {
                position = maxValue;
            }
            p.y = position;
        }

    [self setContentOffset:p animated:YES];

    self.scrollEnabled = YES;
}
- (void)egoRefreshTableDidTriggerRefresh:(EGORefreshPos)aRefreshPos
{
    _isRefreshing = NO;
}
-(BOOL)egoRefreshTableDataSourceIsLoading:(UIView *)view
{
    return _isRefreshing;
}
-(NSDate *)egoRefreshTableDataSourceLastUpdated:(UIView *)view
{
    return [NSDate date];
}
#pragma mark - scroll delegate
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    _endDrag = false;
    _isPosition = YES;
    if (_firstLoad && _isHeaderVisible) {
        if (!_direction) {
            [self addSubview:self.doEGOHeaderView];
        }
    }
    if (_isFooterVisible && !_footerView) {
        UIView *v = [self getFooterView];
        v.tag = 9911;
        if (!_direction) {
            [self addSubview:v];
        }
    }
}

- (void)scrollViewWillEndDragging:(UIScrollView *)scrollView withVelocity:(CGPoint)velocity targetContentOffset:(inout CGPoint *)targetContentOffset {
    _endDrag = true;
}

- (void)headViewDidScroll:(UIScrollView *) scrollView
{
    if (_isHeaderVisible) {
        if (!_headView) {
            [self.doEGOHeaderView egoRefreshScrollViewDidScroll:scrollView];
            NSLog(@"currentOffset.y : %lf",self.contentOffset.y);
            float movedownOffset = fabs(self.contentOffset.y);
            if (movedownOffset > 65) {
                if (!_pullStatus) {
                    _pullStatus = true;
                    [self fireEvent:1 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
                }
            }else if (movedownOffset > 0 && movedownOffset <= 65) {
                if (movedownOffset > _currentHeadViewMoveDownOffset) {
                    if (!_endDrag) {
                        _pullStatus = NO;
                        _currentHeadViewMoveDownOffset = movedownOffset;
                        [self fireEvent:0 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
                    }

                }
            }
        }
        else
        {
            if(scrollView.contentOffset.y >= ((UIView *)_headView).frame.size.height*(-1))
            {
                [self fireEvent:0 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
                _pullStatus = NO;//实时改变状态，解决滑动过1之后，不松手往会滑动不会再出发1的bug
            }
            else
            {
                if (!_pullStatus) {
                    _pullStatus = YES;
                    [self fireEvent:1 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
                }
            }
        }
    }
    
}
- (void)footViewDidScroll:(UIScrollView *) scrollView
{
    if (_isFooterVisible) {
        if (!_footView) {
            float footHeight = CGRectGetHeight(_footerView.frame);
            float heightDif = ((UIView*)_childView).frame.size.height - self.frame.size.height;
            if (self.contentOffset.y >= heightDif) {
                float footerViewMoveUpOffset = self.contentOffset.y - heightDif;
                if (footerViewMoveUpOffset >= footHeight && !_pushStatus) {
                    _pushStatus = YES;
                    [self fireEvent:1 withOffsetY:footerViewMoveUpOffset  withEventName:@"push"];
                }else if (footerViewMoveUpOffset > 0 && footerViewMoveUpOffset < footHeight) {
                    if (footerViewMoveUpOffset > _currentFooterViewMoveUpOffset) {
                        if (!_endDrag) {
                            _currentFooterViewMoveUpOffset = footerViewMoveUpOffset;
                            _pushStatus = NO;
                            [self fireEvent:0 withOffsetY:footerViewMoveUpOffset  withEventName:@"push"];
                        }
                    }
                }
            }

        }
        else
        {
            float valueDif = scrollView.contentOffset.y -( scrollView.contentSize.height - scrollView.frame.size.height);
            if (0 <=valueDif && valueDif < _footerView.frame.size.height) {
                [self fireEvent:0 withOffsetY:valueDif withEventName:@"push"];
                _pushStatus = NO;//下拉后，回滑不触发1
            }
            else if(_footerView.frame.size.height <= valueDif)
            {
                if (!_pushStatus) {
                    _pushStatus = YES;
                    [self fireEvent:1 withOffsetY:valueDif withEventName:@"push"];
                }
            }
        }
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (_isPosition) {
        [self fireScrollEvent:scrollView.contentOffset];
    }
    if (!_isRefreshing) {
        if (self.contentOffset.y<=0) {
            if (!_headView && !_isHeaderVisible) {
                return;
            }
            [self headViewDidScroll:scrollView];
        }else{
            if (!_footerView && !_isFooterVisible) {
                return;
            }
            [self footViewDidScroll:scrollView];
        }
    }
}


- (void)headViewEndDragging:(UIScrollView *)scrollView
{
    if (_isHeaderVisible) {
        UIEdgeInsets edgeInsets;
        if (_headView) {
            edgeInsets = UIEdgeInsetsMake(((UIView *)_headView).frame.size.height, 0, 0, 0);
        }
        else
        {
            edgeInsets = UIEdgeInsetsMake(60, 0, 0, 0);
        }
        if(scrollView.contentOffset.y <= edgeInsets.top*(-1))
        {
            if (_headView) {
                [UIView animateWithDuration:0.2 animations:^{
                    self.contentInset = edgeInsets;
                }];
                _isRefreshing = YES;
            }
            _pullStatus = NO;
            [self fireEvent:2 withOffsetY:scrollView.contentOffset.y withEventName:@"pull"];
        }
        
    }
}


- (void)footerViewEndDragging:(UIScrollView *)scrollView
{
    if (_isFooterVisible) {
        CGFloat diffVisibleHeight = (scrollView.bounds.size.height - MIN(scrollView.bounds.size.height, scrollView.contentSize.height));
        CGFloat defaultDiffHeight = scrollView.bounds.size.height - scrollView.contentSize.height;
        
        if((fabs(scrollView.contentOffset.y)+ defaultDiffHeight - diffVisibleHeight)>CGRectGetHeight(self.footerView.frame))
        {
            if (_isRefreshing == YES) {
                return;
            }
            _isRefreshing = YES;
            self.activityView.hidden = NO;
            [self.activityView startAnimating];
            [UIView animateWithDuration:0.2 animations:^{
                self.contentInset = UIEdgeInsetsMake(0, 0, diffVisibleHeight+_footerView.frame.size.height, 0);
            }];
            float value = scrollView.contentOffset.y -( scrollView.contentSize.height - scrollView.frame.size.height);
            [self fireEvent:2 withOffsetY:value withEventName:@"push"];
            _pushStatus = NO;
        }else
            [self.activityView stopAnimating];
    }
    
}
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!_isRefreshing) {
        if (self.contentOffset.y<=0) {
            if (!_headView && !_isHeaderVisible) {
                return;
            }
            [self headViewEndDragging:scrollView];
        }
        if (self.contentOffset.y>0) {
            if (!_footerView && !_isFooterVisible) {
                return;
            }
            [self footerViewEndDragging:scrollView];
        }
        if (!_headView && _isHeaderVisible) {
            if (self.contentOffset.y<=0) {
                [self.doEGOHeaderView egoRefreshScrollViewDidEndDragging:scrollView];
                if(scrollView.contentOffset.y <= -60)
                    _isRefreshing = YES;
            }
        }
    }
}
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    _pullStatus = NO;
    _pushStatus = NO;
}

#pragma mark - private method
#pragma mark - keyboard
//开始编辑的时候收到抬起的通知，键盘消失的时候收到放下通知（键盘放下通知不能放到文本框结束编辑的时候，否则在有两个文本框互相切换的时候，borderview会上下反复收放）

- (void)keyboardShow:(NSNotification *)noti
{
    _firstResponse = [noti object];
    if ([self findFirstResponder:self]) {
        NSDictionary *info = [noti userInfo];
        NSValue *value = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
        _keyBoardFrame = [value CGRectValue];
        [self responseKeyBoard:YES];
    }
}
- (void)didBeginEdit:(NSNotification *)noti
{
    _firstResponse = [noti object];
    if ([self findFirstResponder:self]) {
        NSDictionary *info = [noti userInfo];
        NSValue *value = [info objectForKey:UIKeyboardFrameEndUserInfoKey];
        _keyBoardFrame = [value CGRectValue];
        if (_keyBoardFrame.size.height < 2) {
            return;
        }
        [self responseKeyBoard:YES];
    }
}

- (void)keyboardDidHid:(NSNotification *)noti
{
    [UIView animateWithDuration:0.25 animations:^{
        [self setContentSize:originContentSize];
    }];
}
- (void)responseKeyBoard:(BOOL)isShow
{
    CGFloat contentSizeHeight = CGRectGetHeight(_keyBoardFrame) + originContentSize.height;
    [self setContentSize:CGSizeMake(CGRectGetWidth(self.frame), contentSizeHeight)];
    CGRect rectInRootView = [self rectInRootView];
    if (isShow) {
        CGFloat diff = CGRectGetMaxY(rectInRootView) - CGRectGetMinY(_keyBoardFrame);
        if (diff > 0) {
            CGFloat contentOffset = self.contentOffset.y + diff;
            [UIView animateWithDuration:0.25 animations:^{
                [self setContentOffset:CGPointMake(0, contentOffset)];
            }];
            
        }
    }
}
- (BOOL)findFirstResponder:(UIView *)view {
    NSArray *subviews = [view subviews];
    
    BOOL isFirst = NO;
    
    if ([subviews count] == 0)
        isFirst = NO;
    
    for (UIView *subview in subviews) {
        if ([subview isEqual:_firstResponse]) {
            isFirst = YES;
            break;
        }else{
            isFirst = [self findFirstResponder:subview];
            if (isFirst) {
                break;
            }
        }
        
    }
    return isFirst;
}
- (CGRect)rectInRootView
{
    UIView *rootView = ((UIViewController *)_model.CurrentPage.PageView).view;
    CGRect rect = [_firstResponse.superview convertRect:_firstResponse.frame toView:rootView];
    return rect;
}

#pragma mark - 调整headView的大小
- (void)setContent
{
    UIView *childView = (UIView *)_childView;
    CGFloat w = childView.frame.origin.x+childView.frame.size.width;
    CGFloat h = childView.frame.origin.y+childView.frame.size.height;
    if(_direction)
    {
//        if(_headView)
//        {
//            UIView *headView = (UIView *)_headView;
//            headView.frame = CGRectMake(-headView.frame.size.width, headView.frame.origin.y, headView.frame.size.width, headView.frame.size.height);
//            
//            if(w <= self.frame.size.width)
//                w = self.frame.size.width+1;
//        }
        if (_headView) {
            [((UIView *)_headView) removeFromSuperview];
        }
        if (_footView) {
            [((UIView *)_footView) removeFromSuperview];
        }
        UIView *v = [self viewWithTag:9911];
        if (v) {
            [v removeFromSuperview];
        }
        if (_footerView) {
            [_footerView removeFromSuperview];
        }
        self.contentSize = CGSizeMake(w, 0);
    }
    else
    {
        if(_headView)
        {
            UIView *headView = (UIView *)_headView;
            headView.frame = CGRectMake(headView.frame.origin.x, -headView.frame.size.height, headView.frame.size.width, headView.frame.size.height);
            
            if(h <= self.frame.size.height)
                h = self.frame.size.height+1;
        }
        if (_footerView) {
            CGFloat visibleTableDiffBoundsHeight = (self.bounds.size.height - MIN(self.bounds.size.height, self.contentSize.height));
            CGRect footerFrame = self.footerView.frame;
            footerFrame.origin.y = self.contentSize.height + visibleTableDiffBoundsHeight;
            self.footerView.frame = footerFrame;
        }
        self.contentSize = CGSizeMake(0, h);
    }
}
#pragma mark -
#pragma mark 重写get方法
- (doEGORefreshTableHeaderView *)doEGOHeaderView
{
    if (!_doEGOHeaderView) {
        _doEGOHeaderView = [[doEGORefreshTableHeaderView alloc]initWithFrame:CGRectMake(0, 0 - self.bounds.size.height, self.bounds.size.width, self.bounds.size.height)];
        _doEGOHeaderView.backgroundColor = [UIColor clearColor];
        _firstLoad = NO;
        _doEGOHeaderView.delegate = self;
        if (!_direction) {
            [self addSubview:_doEGOHeaderView];
        }
    }
    return _doEGOHeaderView;
}

#pragma mark - 发送pull事件
- (void)fireScrollEvent:(CGPoint)contentOffset
{
    if (_isRefreshing) {
        return;
    }
    if (!_scrollEventResult) {
        _scrollEventResult = [[doInvokeResult alloc] init:_model.UniqueKey];
    }
    if (_direction) {
        CGFloat currentLeft = contentOffset.x /_model.XZoom;
        if (fabs(currentLeft)<1) {
            currentLeft = 0;
        }
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setObject:[@(_oldLeft) stringValue] forKey:@"oldLeft"];
        [dict setObject:[@(currentLeft) stringValue] forKey:@"left"];
        [_scrollEventResult SetResultNode:dict];
        _oldLeft = currentLeft;
    }
    else
    {
        CGFloat currentTop = contentOffset.y /_model.YZoom;
        if (fabs(currentTop)<1) {
            currentTop = 0;
        }
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setObject:[@(_oldTop) stringValue] forKey:@"oldTop"];
        [dict setObject:[@(currentTop) stringValue] forKey:@"top"];
        [_scrollEventResult SetResultNode:dict];
        _oldTop = currentTop;
    }
    [_model.EventCenter FireEvent:@"scroll" :_scrollEventResult];
}

- (void)fireEvent:(int)state withOffsetY:(CGFloat)y withEventName :(NSString *)name
{
    if (_direction) {
        return;
    }
    if (!_invokeResult1) {
        _invokeResult1 = [[doInvokeResult alloc] init:_model.UniqueKey];
    }
    if (!_node) {
        _node = [NSMutableDictionary dictionary];
    }
    CGSize s = self.contentSize;
    CGPoint p = self.contentOffset;
    CGFloat maxValue = 0;
    if (_direction) {
        maxValue = s.width-CGRectGetWidth(self.frame);
        if (p.x>=0&&p.x<=maxValue) {
            return;
        }
    }else{
        maxValue = s.height-CGRectGetHeight(self.frame);
        if (p.y>=0&&p.y<=maxValue) {
            return;
        }
    }
    [_node setObject:@(state) forKey:@"state"];
    [_node setObject:@(fabs(y/_model.YZoom)) forKey:@"offset"];
    [_invokeResult1 SetResultNode:_node];
    [_model.EventCenter FireEvent:name :_invokeResult1];
}

#pragma mark - doIUIModuleView协议方法（必须）<大部分情况不需修改>
- (BOOL) OnPropertiesChanging: (NSMutableDictionary *) _changedValues
{
    //属性改变时,返回NO，将不会执行Changed方法
    return YES;
}
- (void) OnPropertiesChanged: (NSMutableDictionary*) _changedValues
{
    //_model的属性进行修改，同时调用self的对应的属性方法，修改视图
    [doUIModuleHelper HandleViewProperChanged: self :_model : _changedValues ];
}
- (BOOL) InvokeSyncMethod: (NSString *) _methodName : (NSDictionary *)_dicParas :(id<doIScriptEngine>)_scriptEngine : (doInvokeResult *) _invokeResult
{
    //同步消息
    return [doScriptEngineHelper InvokeSyncSelector:self : _methodName :_dicParas :_scriptEngine :_invokeResult];
}
- (BOOL) InvokeAsyncMethod: (NSString *) _methodName : (NSDictionary *) _dicParas :(id<doIScriptEngine>) _scriptEngine : (NSString *) _callbackFuncName
{
    //异步消息
    return [doScriptEngineHelper InvokeASyncSelector:self : _methodName :_dicParas :_scriptEngine: _callbackFuncName];
}
- (doUIModule *) GetModel
{
    //获取model对象
    return _model;
}
- (void)screenShot:(NSArray *)parms
{
    id<doIScriptEngine> _scriptEngine = [parms objectAtIndex:1];
    NSString *_callbackName = [parms objectAtIndex:2];
    
    if (self.subviews.count==0) {
        return;
    }
    
    //垂直方向
    if (!_direction || _direction == NO) {
        if (_headView) {
            _screenShotView = [self.subviews objectAtIndex:1];
        } else {
            _screenShotView = [self.subviews objectAtIndex:0];
        }
//        UIView * view = [self.subviews objectAtIndex:1];
//        CGRect rect = view.frame;
        CGRect rect = _screenShotView.frame;
        //    UIGraphicsBeginImageContext(rect.size);
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [_screenShotView.layer renderInContext:context];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        NSData *imageData = UIImageJPEGRepresentation(img, 1.0);
        
        NSString *_fileFullName = [_scriptEngine CurrentApp].DataFS.RootPath;
        NSDate *date = [NSDate date];
        NSDateFormatter  *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMddHHmmss"];
        NSString *fileName = [NSString stringWithFormat:@"%@.jpg",[formatter stringFromDate:date]];
        
        NSString *filePath = [NSString stringWithFormat:@"%@/temp/do_ScrollView/%@",_fileFullName,fileName];
        NSString *returnPath = [NSString stringWithFormat:@"data://temp/do_ScrollView/%@",fileName];
        NSString *path = [NSString stringWithFormat:@"%@/temp/do_ScrollView",_fileFullName];
        if(![doIOHelper ExistDirectory:path])
            [doIOHelper CreateDirectory:path];
        [doIOHelper WriteAllBytes:filePath :imageData];
        
        doInvokeResult *_invokeResult = [doInvokeResult new];
        [_invokeResult SetResultText:returnPath];
        
        [_scriptEngine Callback:_callbackName :_invokeResult];

    }else {
        //水平方向
        UIView *view = [self.subviews firstObject];
        CGRect rect = view.frame;
        //    UIGraphicsBeginImageContext(rect.size);
        UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
        CGContextRef context = UIGraphicsGetCurrentContext();
        [view.layer renderInContext:context];
        UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        
        NSData *imageData = UIImageJPEGRepresentation(img, 1.0);
        
        NSString *_fileFullName = [_scriptEngine CurrentApp].DataFS.RootPath;
        NSDate *date = [NSDate date];
        NSDateFormatter  *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"yyyyMMddHHmmss"];
        NSString *fileName = [NSString stringWithFormat:@"%@.jpg",[formatter stringFromDate:date]];
        
        NSString *filePath = [NSString stringWithFormat:@"%@/temp/do_ScrollView/%@",_fileFullName,fileName];
        NSString *returnPath = [NSString stringWithFormat:@"data://temp/do_ScrollView/%@",fileName];
        NSString *path = [NSString stringWithFormat:@"%@/temp/do_ScrollView",_fileFullName];
        if(![doIOHelper ExistDirectory:path])
            [doIOHelper CreateDirectory:path];
        [doIOHelper WriteAllBytes:filePath :imageData];
        
        doInvokeResult *_invokeResult = [doInvokeResult new];
        [_invokeResult SetResultText:returnPath];
        
        [_scriptEngine Callback:_callbackName :_invokeResult];

    }
}

@end
