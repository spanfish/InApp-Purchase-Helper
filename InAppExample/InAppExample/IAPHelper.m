//
//  IAPHelper.h
//  GSPro
//
//  Created by Xiangwei Wang on 1/28/15.
//  Copyright (c) 2015 Xiangwei Wang. All rights reserved.
//

#import "IAPHelper.h"
#import "VerifyStoreReceipt.h"

//update to app version every time before new version is submited
const NSString * global_bundleVersion = @"1.0";
const NSString * global_bundleIdentifier = @"com.xiang.InAppExample";

@interface IAPHelper () <SKProductsRequestDelegate>
@end

@implementation IAPHelper {
    SKProductsRequest * _productsRequest;
    NSSet * _productIdentifiers;
    BOOL _requestingProduct;
    SKReceiptRefreshRequest *_refreshRequest;
    NSMutableDictionary *_productIdsInPurchasing;
}

//Call this in application:didFinishLaunchingWithOptions
+ (IAPHelper *)sharedInstance {
    static dispatch_once_t once;
    static IAPHelper * sharedInstance;
    
    dispatch_once(&once, ^{
        sharedInstance = [[IAPHelper alloc] init];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:sharedInstance];
    });
    
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if(self) {
        NSURL *url = [[NSBundle mainBundle] URLForResource:@"product_ids"
                                             withExtension:@"plist"];
        _productIdentifiers = [NSSet setWithArray:[NSArray arrayWithContentsOfURL:url]];
        _productIdsInPurchasing = [NSMutableDictionary dictionary];
    }
    
    return self;
}

-(BOOL) requestingProduct {
    return _requestingProduct;
}

- (void)requestProducts {
    if(_requestingProduct) {
        return;
    }

    _productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:_productIdentifiers];
    _productsRequest.delegate = self;
    [_productsRequest start];
    _requestingProduct = YES;
}

#pragma mark - SKProductsRequestDelegate
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response {
   
    _productsRequest = nil;
    _requestingProduct = NO;
    NSArray * skProducts = response.products;
#ifdef DEBUG
    NSNumberFormatter *numberFmt = [[NSNumberFormatter alloc] init];
    [numberFmt setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFmt setNumberStyle:NSNumberFormatterCurrencyStyle];
    
    for (SKProduct * product in skProducts) {
        [numberFmt setLocale:product.priceLocale];
        NSLog(@"Found product: %@ %@, %@f",
              product.productIdentifier,
              product.localizedTitle,
              [numberFmt stringFromNumber:product.price]);
    }
#endif
    [[NSNotificationCenter defaultCenter] postNotificationName:ProductsNotification object:self userInfo:@{kProducts: skProducts}];
}

- (void)requestDidFinish:(SKRequest *)request {
    if([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        _restoring = NO;
        _refreshRequest = nil;
        [self processReceipt];

        [[NSNotificationCenter defaultCenter] postNotificationName:RestoreNotification
                                                            object:self
                                                          userInfo:nil];
    } else if([request isKindOfClass:[SKProductsRequest class]]) {
        _requestingProduct = NO;
    }
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if([request isKindOfClass:[SKProductsRequest class]]) {
        _productsRequest = nil;
        _requestingProduct = NO;
        [[NSNotificationCenter defaultCenter] postNotificationName:ProductsNotification
                                                            object:self
                                                          userInfo:nil];
    } else if([request isKindOfClass:[SKReceiptRefreshRequest class]]) {
        _restoring = NO;
        _refreshRequest = nil;
        NSError *error = [NSError errorWithDomain:InAppErrorDomain
                                             code:InAppErrorCodeRestoreFailed
                                         userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"RestoreFailed", nil)}];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:RestoreNotification
                                                            object:self
                                                          userInfo: @{kInappError: error}];
    }
}

-(BOOL) paymentAllowed {
    return [SKPaymentQueue canMakePayments];
}

#pragma mark - Purchase

-(void) purchaseProduct:(SKProduct *) product {
    if(![self paymentAllowed]) {
        NSError *error = [NSError errorWithDomain:InAppErrorDomain
                                             code:InAppErrorCodeNotAllowed
                                         userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"InAppNotAllowed", nil)}];
        [[NSNotificationCenter defaultCenter] postNotificationName:PurchaseNotification
                                                            object:self
                                                          userInfo: @{kInappError: error}];
        return;
    }
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
    [[SKPaymentQueue defaultQueue] addPayment:payment];

    [_productIdsInPurchasing setObject:[NSNumber numberWithBool:YES] forKey:product.productIdentifier];
}

#pragma mark Transaction statuses and corresponding actions
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
                // Call the appropriate custom method for the transaction state.
            case SKPaymentTransactionStatePurchasing:
                break;
            case SKPaymentTransactionStateDeferred:
                break;
            case SKPaymentTransactionStateFailed:
                [self finishPaymentTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchased:
                [self finishPaymentTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self finishPaymentTransaction:transaction];
                break;
            default:
                break;
        }
    }
}

/*
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions {
    DLog(@"removedTransactions");
    for (SKPaymentTransaction *transaction in transactions) {
        if(transaction.transactionState == SKPaymentTransactionStatePurchased || transaction.transactionState == SKPaymentTransactionStateRestored) {
        } else {
        }
    }
}
*/
-(void) finishPaymentTransaction:(SKPaymentTransaction *) transaction {
    //[[NSUserDefaults standardUserDefaults] removeObjectForKey:[NSString stringWithFormat:@"%@_inpurchasing", transaction.payment.productIdentifier]];
    //[[NSUserDefaults standardUserDefaults] synchronize];

    if(transaction.transactionState == SKPaymentTransactionStatePurchased) {
        [self purchaseProductFinished:transaction.payment.productIdentifier];
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:transaction.payment.productIdentifier];
        [[NSNotificationCenter defaultCenter] postNotificationName:PurchaseNotification
                                                            object:self
                                                          userInfo: nil];
    } else if(transaction.transactionState == SKPaymentTransactionStateFailed) {
        [self purchaseProductFinished:transaction.payment.productIdentifier];
        NSError *error = [NSError errorWithDomain:InAppErrorDomain
                                             code:InAppErrorCodePayFailed
                                         userInfo:@{NSLocalizedDescriptionKey: NSLocalizedString(@"PurchaseFailed", nil)}];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:PurchaseNotification
                                                            object:self
                                                          userInfo: @{kInappError: error}];
    } else if(transaction.transactionState == SKPaymentTransactionStateRestored) {
    }
    
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

-(BOOL) purchasingForProduct:(NSString *) productId {
    return [[_productIdsInPurchasing objectForKey:productId] boolValue];
}

-(void) purchaseProductFinished:(NSString *) productId {
    [_productIdsInPurchasing removeObjectForKey:productId];
}

-(BOOL) purchasedProduct:(NSString *) productId {
    BOOL purchased = [[NSUserDefaults standardUserDefaults] boolForKey:productId];
    return purchased;
}

-(void) processReceipt {
    NSArray *products = obtainInAppPurchases([[[NSBundle mainBundle] appStoreReceiptURL] path]);
    for (NSDictionary *purchase in products) {
        if([purchase objectForKey:kReceiptInAppCancellationDate] != nil) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[purchase objectForKey:kReceiptInAppProductIdentifier]];
            continue;
        }

        NSDate *expiredDate = [purchase objectForKey:kReceiptExpirationDate];
        if(expiredDate != nil && [expiredDate compare:[NSDate date]] != NSOrderedDescending) {
            [[NSUserDefaults standardUserDefaults] setBool:NO forKey:[purchase objectForKey:kReceiptInAppProductIdentifier]];
            continue;
        }

        [[NSUserDefaults standardUserDefaults] setBool: YES forKey:[purchase objectForKey:kReceiptInAppProductIdentifier]];
    }
}
#pragma mark Restore
-(void) restorePurchasedProducts {
    if(self.isRestoring) {
        return;
    }

    if(!_refreshRequest) {
        _refreshRequest = [[SKReceiptRefreshRequest alloc] init];
        _refreshRequest.delegate = self;
    }
    [_refreshRequest start];
    _restoring = YES;
}
@end
