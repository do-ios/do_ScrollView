//
//  TYPEID_View.h
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "do_ScrollView_IView.h"
#import "do_ScrollView_UIModel.h"
#import "doIUIModuleView.h"
#import "doIScrollView.h"

@interface do_ScrollView_UIView : UIScrollView<do_ScrollView_IView,doIUIModuleView,UIScrollViewDelegate,doIScrollView>
//可根据具体实现替换UIView
{
    @private
    __weak do_ScrollView_UIModel *_model;
}
- (void)loadModuleJS;
@end
