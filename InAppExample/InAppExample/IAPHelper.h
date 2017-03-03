//
//  IAPHelper.h
//  GSPro
//
//  Created by Xiangwei Wang on 1/28/15.
//  Copyright (c) 2015 Xiangwei Wang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

#define InAppErrorDomain @"com.xiangwei.InappError"
typedef enum : NSUInteger {
    InAppErrorCodeNone = 0,
    InAppErrorCodeNotAllowed,
    InAppErrorCodePayFailed,
    InAppErrorCodeRestoreFailed
} InAppErrorCode;

#define RestoreNotification           @"RestoreNotification"
#define PurchaseNotification          @"PurchaseNotification"
#define ProductsNotification          @"ProductsNotification"
#define kInappError                   @"Error"
#define kProducts                     @"Products"

@interface IAPHelper : NSObject<SKPaymentTransactionObserver, SKProductsRequestDelegate>

+ (IAPHelper *)sharedInstance;

@property(nonatomic, assign, getter=isRestoring, readonly) BOOL restoring;

/**
* By default, it will request products listed in file product_ids.plist.
*/
-(void) requestProducts;

/**
 * Purchase product, PurchaseNotification will be posted when purchase is finished.
 */
-(void) purchaseProduct:(SKProduct *) product;

/**
 * Restore purchased product, RestoreNotification will be posted when purchase is finished.
 */
-(void) restorePurchasedProducts;

/**
 * Is it requesting product.
 */
-(BOOL) requestingProduct;

/*Return true if the product is being purchased*/
-(BOOL) purchasingForProduct:(NSString *) productId;
/*Return true if the product has been purchased already*/
-(BOOL) purchasedProduct:(NSString *) productId;
/*Return false if IAP is not allowed, this can be set in setting*/
-(BOOL) paymentAllowed;
@end
