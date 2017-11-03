//
//  TYPEID_Model.m
//  DoExt_UI
//
//  Created by @userName on @time.
//  Copyright (c) 2015年 DoExt. All rights reserved.
//

#import "do_ScrollView_UIModel.h"
#import "doProperty.h"
#import "do_ScrollView_UIView.h"

@implementation do_ScrollView_UIModel

#pragma mark - 注册属性（--属性定义--）
/*
[self RegistProperty:[[doProperty alloc]init:@"属性名" :属性类型 :@"默认值" : BOOL:是否支持代码修改属性]];
 */
-(void)OnInit
{
    [super OnInit];
    //属性声明
    [self RegistProperty:[[doProperty alloc]init:@"canScrollToTop" :Bool :@"true" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"direction" :String :@"horizontal" :NO]];
    [self RegistProperty:[[doProperty alloc]init:@"isShowbar" :Bool :@"true" :NO]];
    [self RegistProperty:[[doProperty alloc]init:@"isHeaderVisible" :Bool :@"false" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"headerView" :String :@"" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"isFooterVisible" :Bool :@"false" :YES]];
    [self RegistProperty:[[doProperty alloc]init:@"footerView" :String :@"" :YES]];
}
- (void)DidLoadView
{
    [super DidLoadView];
    
    [((do_ScrollView_UIView *)self.CurrentUIModuleView) loadModuleJS];
}
@end
