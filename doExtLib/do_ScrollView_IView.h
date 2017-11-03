
//
//  TYPEID_UI.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol do_ScrollView_IView <NSObject>

@required
//属性方法
- (void)change_isShowbar:(NSString *)newValue;
- (void)change_direction:(NSString *)newValue;
- (void)change_headerView:(NSString *)newValue;
- (void)change_isHeaderVisible:(NSString *)newValue;
- (void)change_isFooterVisible:(NSString *)newValue;
- (void)change_footerView:(NSString *)newValue;

//同步或异步方法
- (void)toBegin:(NSArray *)parms;
- (void)toEnd:(NSArray *)parms;
- (void)getOffsetX:(NSArray *)parms;
- (void)getOffsetY:(NSArray *)parms;
- (void)rebound:(NSArray *)parms;
- (void)scrollTo:(NSArray *)parms;
- (void)screenShot:(NSArray *)parms;


@end
