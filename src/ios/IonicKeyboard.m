#import "IonicKeyboard.h"
// #import "UIWebViewExtension.h"
#import <Cordova/CDVAvailability.h>

@implementation IonicKeyboard

@synthesize hideKeyboardAccessoryBar = _hideKeyboardAccessoryBar;
@synthesize disableScroll = _disableScroll;
static UIKeyboardAppearance _keyboardStyle;

- (void)pluginInitialize {

    Class wkClass = NSClassFromString([@[@"UI", @"Web", @"Browser", @"View"] componentsJoinedByString:@""]);
    wkMethod = class_getInstanceMethod(wkClass, @selector(inputAccessoryView));
    wkOriginalImp = method_getImplementation(wkMethod);
    Class uiClass = NSClassFromString([@[@"WK", @"Content", @"View"] componentsJoinedByString:@""]);
    uiMethod = class_getInstanceMethod(uiClass, @selector(inputAccessoryView));
    uiOriginalImp = method_getImplementation(uiMethod);
    nilImp = imp_implementationWithBlock(^(id _s) {
        return nil;
    });

    //set defaults
    self.hideKeyboardAccessoryBar = YES;
    self.disableScroll = NO;
    // disable Shake to Undo gesture
    [UIApplication sharedApplication].applicationSupportsShakeToEdit = NO;

    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];
    __weak IonicKeyboard* weakSelf = self;
    _keyboardShowObserver = [nc addObserverForName:UIKeyboardWillShowNotification
                               object:nil
                               queue:[NSOperationQueue mainQueue]
                               usingBlock:^(NSNotification* notification) {

                                   CGRect keyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
                                   keyboardFrame = [self.viewController.view convertRect:keyboardFrame fromView:nil];

                                   [weakSelf.commandDelegate evalJs:[NSString stringWithFormat:@"cordova.plugins.Keyboard.isVisible = true; cordova.fireWindowEvent('native.keyboardshow', { 'keyboardHeight': %@ }); ", [@(keyboardFrame.size.height) stringValue]]];

                                   //deprecated
                                   [weakSelf.commandDelegate evalJs:[NSString stringWithFormat:@"cordova.fireWindowEvent('native.showkeyboard', { 'keyboardHeight': %@ }); ", [@(keyboardFrame.size.height) stringValue]]];
                               }];

    _keyboardHideObserver = [nc addObserverForName:UIKeyboardWillHideNotification
                               object:nil
                               queue:[NSOperationQueue mainQueue]
                               usingBlock:^(NSNotification* notification) {
                                   [weakSelf.commandDelegate evalJs:@"cordova.plugins.Keyboard.isVisible = false; cordova.fireWindowEvent('native.keyboardhide'); "];

                                   //deprecated
                                   [weakSelf.commandDelegate evalJs:@"cordova.fireWindowEvent('native.hidekeyboard'); "];
                               }];
}

- (BOOL)disableScroll {
    return _disableScroll;
}

- (void)setDisableScroll:(BOOL)disableScroll {
    if (disableScroll == _disableScroll) {
        return;
    }
    if (disableScroll) {
        self.webView.scrollView.scrollEnabled = NO;
        self.webView.scrollView.delegate = self;
    }
    else {
        self.webView.scrollView.scrollEnabled = YES;
        self.webView.scrollView.delegate = nil;
    }

    _disableScroll = disableScroll;
}

//keyboard swizzling inspired by:
//https://github.com/cjpearson/cordova-plugin-keyboard/

- (BOOL)hideKeyboardAccessoryBar {
    return _hideKeyboardAccessoryBar;
}

- (void)setHideKeyboardAccessoryBar:(BOOL)hideKeyboardAccessoryBar {
    if (hideKeyboardAccessoryBar == _hideKeyboardAccessoryBar) {
        return;
    }

    if (hideKeyboardAccessoryBar) {
        method_setImplementation(wkMethod, nilImp);
        method_setImplementation(uiMethod, nilImp);
    } else {
        method_setImplementation(wkMethod, wkOriginalImp);
        method_setImplementation(uiMethod, uiOriginalImp);
    }

    _hideKeyboardAccessoryBar = hideKeyboardAccessoryBar;
}


/* ------------------------------------------------------------- */

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [scrollView setContentOffset: CGPointZero];
}

/* ------------------------------------------------------------- */

- (void)dealloc {
    NSNotificationCenter* nc = [NSNotificationCenter defaultCenter];

    [nc removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [nc removeObserver:self name:UIKeyboardWillHideNotification object:nil];
}

/* ------------------------------------------------------------- */

- (void) disableScroll:(CDVInvokedUrlCommand*)command {
    if (!command.arguments || ![command.arguments count]){
      return;
    }
    id value = [command.arguments objectAtIndex:0];
    if (value != [NSNull null]) {
      self.disableScroll = [value boolValue];
    }
}

- (void) hideKeyboardAccessoryBar:(CDVInvokedUrlCommand*)command {
    if (!command.arguments || ![command.arguments count]){
        return;
    }
    id value = [command.arguments objectAtIndex:0];
    if (value != [NSNull null]) {
        self.hideKeyboardAccessoryBar = [value boolValue];
    }
}

- (void) close:(CDVInvokedUrlCommand*)command {
    [self.webView endEditing:YES];
}

- (void) show:(CDVInvokedUrlCommand*)command {
    NSLog(@"Showing keyboard not supported in iOS due to platform limitations.");
}

- (UIKeyboardAppearance)keyboardAppearance {
    return _keyboardStyle;
}

- (void) styleDark:(CDVInvokedUrlCommand*)command {
    if (!command.arguments || ![command.arguments count]){
      return;
    }
    id value = [command.arguments objectAtIndex:0];
    if ([value boolValue]) {
        _keyboardStyle = UIKeyboardAppearanceDark;
    } else {
        _keyboardStyle = UIKeyboardAppearanceLight;
    }

    [self registerKeyboardAppearance];
}

- (void)registerKeyboardAppearance {
    for (UIView *view in [[self.webView scrollView] subviews]) {
        if([[view.class description] containsString:@"WKContent"]) {
            UIView *content = view;
            NSString *className = [NSString stringWithFormat:@"%@_%@",[[content class] superclass],[self class]];
            Class newClass = NSClassFromString(className);
            if (!newClass) {
                newClass = objc_allocateClassPair([content class], [className cStringUsingEncoding:NSASCIIStringEncoding], 0);
                Method method = class_getInstanceMethod([self class], @selector(keyboardAppearance));
                class_addMethod(newClass, @selector(keyboardAppearance), method_getImplementation(method), method_getTypeEncoding(method));
                objc_registerClassPair(newClass);
            }
            object_setClass(content, newClass);
            return;
        }
    }
}

@end

