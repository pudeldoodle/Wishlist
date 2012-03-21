/*
 * Copyright 2010 Facebook
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *    http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <UIKit/UIKit.h>
#import "NearbyViewController.h"
#import "FBConnect.h"
#import <CoreLocation/CoreLocation.h>

typedef enum apiCall {
    kAPIFQLMe,
    kAPIGraphSearchPlace,
    kAPIGraphWishlist,
} apiCall;

@interface HomeViewController : UIViewController
<FBRequestDelegate,
FBSessionDelegate,
FBDialogDelegate,
UIPickerViewDelegate,
UITableViewDataSource,
UITableViewDelegate,
UINavigationControllerDelegate,
UIImagePickerControllerDelegate,
UITextFieldDelegate,
CLLocationManagerDelegate,
UIAlertViewDelegate,
NearbyViewControllerDelegate,
UIPopoverControllerDelegate>
{
    Facebook *facebook;
    int currentAPICall;
    UIButton *loginButton;
    UIPickerView *wishlistPickerView;
    NSMutableArray *wishlistChoices;
    NSInteger selectedWishlist;
    UITableView *infoTableView;
    BOOL wishlistPickerVisible;
    UIImageView *productPhotoImageView;
    UIImage *productImage;
    UIImagePickerController *imagePickerController;
    UIButton *cameraButton;
    UIButton *libraryButton;
    UILabel *cameraLabel;
    UILabel *libraryLabel;
    NSMutableArray *nearbyData;
    CLLocationManager *locationManager;
    CLLocation *mostRecentLocation;
    UIView *activityIndicatorView;
    UIActivityIndicatorView *activityIndicator;
    UILabel *activityLabel;
    NSURLConnection *uploadConnection;
    NSMutableData *receivedData;
    NSString *selectedPlace;
    NSMutableDictionary *productImageData;
    NSString *productName;
    UILabel *profileNameLabel;
    UIImageView *profileImageView;
}

@property (nonatomic, retain) Facebook *facebook;

@property (nonatomic, retain) UIButton *loginButton;
@property (nonatomic, retain) UIPickerView *wishlistPickerView;
@property (nonatomic, retain) NSMutableArray *wishlistChoices;
@property (nonatomic, retain) UITableView *infoTableView;
@property (nonatomic, retain) UIImageView *productPhotoImageView;
@property (nonatomic, retain) UIImage *productImage;
@property (nonatomic, retain) UIImagePickerController *imagePickerController;
@property (nonatomic, retain) UIButton *cameraButton;
@property (nonatomic, retain) UIButton *libraryButton;
@property (nonatomic, retain) UILabel *cameraLabel;
@property (nonatomic, retain) UILabel *libraryLabel;
@property (nonatomic, retain) NSMutableArray *nearbyData;
@property (nonatomic, retain) CLLocationManager *locationManager;
@property (nonatomic, retain) CLLocation *mostRecentLocation;
@property (nonatomic, retain) UIView *activityIndicatorView;
@property (nonatomic, retain) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) UILabel *activityLabel;
@property (nonatomic, retain) NSURLConnection *uploadConnection;
@property (nonatomic, retain) NSMutableData *receivedData;
@property (nonatomic, retain) NSString *selectedPlace;
@property (nonatomic, retain) NSMutableDictionary *productImageData;
@property (nonatomic, retain) NSString *productName;
@property (nonatomic, retain) UILabel *profileNameLabel;
@property (nonatomic, retain) UIImageView *profileImageView;

@end
