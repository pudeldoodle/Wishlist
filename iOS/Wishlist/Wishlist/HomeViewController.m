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

#import "HomeViewController.h"
#import "NearbyViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "AppDelegate.h"

// View tags
#define WISHLIST_TITLE_TAG 1001
#define PRODUCT_NAME_TAG 1002
#define PLACE_NAME_TAG 1003

// Server for uploading photos and hosting objects 
static NSString *kBackEndServer = @"https://growing-leaf-2900.herokuapp.com";

@implementation HomeViewController

@synthesize facebook;

@synthesize loginButton;
@synthesize wishlistPickerView;
@synthesize wishlistChoices;
@synthesize infoTableView;
@synthesize productPhotoImageView;
@synthesize imagePickerController;
@synthesize cameraButton;
@synthesize libraryButton;
@synthesize cameraLabel;
@synthesize libraryLabel;
@synthesize nearbyData;
@synthesize locationManager;
@synthesize mostRecentLocation;
@synthesize activityIndicatorView;
@synthesize activityIndicator;
@synthesize activityLabel;
@synthesize uploadConnection;
@synthesize receivedData;
@synthesize selectedPlace;
@synthesize productName;
@synthesize productImageData;
@synthesize profileImageView;
@synthesize productImage;
@synthesize profileNameLabel;

- (void)dealloc
{
    [loginButton release];
    [wishlistPickerView release];
    [wishlistChoices release];
    [infoTableView release];
    [productPhotoImageView release];
    [nearbyData release];
    [mostRecentLocation release];
    [activityIndicatorView release];
    [activityIndicator release];
    [activityLabel release];
    
    [locationManager stopUpdatingLocation];
    locationManager.delegate = nil;
    [locationManager release];
    
    [uploadConnection cancel];
    [uploadConnection release];
    [receivedData release];
    
    [selectedPlace release];
    [productImageData release];
    [productName release];
    [productImage release];
    [profileNameLabel release];
    [profileImageView release];
    
    [cameraButton release];
    [libraryButton release];
    [cameraLabel release];
    [libraryLabel release];
    
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

/*
 * This method shows the activity indicator and
 * deactivates the table to avoid user input.
 */
- (void) showActivityIndicator:(NSString *)message
{
    if (![activityIndicator isAnimating]) {
        activityIndicatorView.hidden = NO;
        infoTableView.userInteractionEnabled = NO;
        if ([message isEqualToString:@""]) {
            activityLabel.text = @"Loading";
        } else {
            activityLabel.text = message;
        }
        [activityIndicator startAnimating];   
    }
}

/*
 * This method hides the activity indicator
 * and enables user interaction once more.
 */
- (void) hideActivityIndicator
{
    if ([activityIndicator isAnimating]) {
        [activityIndicator stopAnimating];   
        infoTableView.userInteractionEnabled = YES;
        activityIndicatorView.hidden = YES;
        activityLabel.text = @"";
    }
}

#pragma mark - Facebook API Calls
/**
 * Make a Graph API Call to get information about the current logged in user.
 */
- (void) apiFQLIMe {
    currentAPICall = kAPIFQLMe;
    // Using the "pic" picture since this currently has a maximum width of 100 pixels
    // and since the minimum profile picture size is 180 pixels wide we should be able
    // to get a 100 pixel wide version of the profile picture
    NSMutableDictionary *params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"SELECT uid, name, pic FROM user WHERE uid=me()", @"query",
                                   nil];
    [facebook requestWithMethodName:@"fql.query"
                                     andParams:params
                                 andHttpMethod:@"POST"
                                   andDelegate:self];
}

/*
 * Graph API: Search query to get nearby location.
 */
- (void) apiGraphSearchPlace:(CLLocation *)location
{
    currentAPICall = kAPIGraphSearchPlace;
    [self showActivityIndicator:@"Searching"];
    NSString *centerLocation = [[NSString alloc] initWithFormat:@"%f,%f", 
                                location.coordinate.latitude, 
                                location.coordinate.longitude]; 
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"place",  @"type",
                                   centerLocation, @"center",
                                   @"1000",  @"distance",
                                   nil];
    [centerLocation release];
    [facebook requestWithGraphPath:@"search" andParams:params andDelegate:self];
}

/*
 * Graph API: Search query to get nearby location.
 */
- (void) apiGraphAddToWishlist
{
    currentAPICall = kAPIGraphWishlist;
    [self showActivityIndicator:@"Adding to Timeline"];

    // Set up the Product object instance, a dynamic URL that
    // represents the object (image and name)
    NSString *productLink = [[NSString alloc] 
                             initWithFormat:@"%@/product.php?image=%@&name=%@", 
                             kBackEndServer,
                             [productImageData objectForKey:@"image_name"],
                             productName];
    
    // Build the params list
    NSMutableDictionary *params = [[NSMutableDictionary alloc] initWithCapacity:1];
    // - wishlist object
    [params setValue:[[wishlistChoices objectAtIndex:selectedWishlist] objectForKey:@"link"] forKey:@"wishlist"];
    // - product, custom property for the action
    [params setValue:productLink forKey:@"product"];
    // - place, property for the action (optional)
    if (![self.selectedPlace isEqualToString:@""]) {
        [params setValue:self.selectedPlace forKey:@"place"];
    }
    // - image, property for the action
    [params setValue:[productImageData objectForKey:@"image_url"] forKey:@"image"];

    // Make the Graph API call to add to the wishlist
    [facebook requestWithGraphPath:@"me/samplewishlist:add_to" 
                         andParams:params
                     andHttpMethod:@"POST"
                       andDelegate:self];
    
    [params release];
    [productLink release];
}

#pragma mark - Private Methods

/*
 Called to make sure the text view is visible above the keyboard
 when the keyboard is displayed. Registers for the required 
 notifications.
 */
- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

/*
 Unregisters for the keyboard notifications.
 */
- (void)unregisterForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillHideNotification object:nil];
    
}

/*
 Called when the UIKeyboardDidShowNotification is sent.
 */
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    infoTableView.contentInset = contentInsets;
    infoTableView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your application might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    UITextField *textField = (UITextField *) [self.view viewWithTag:PRODUCT_NAME_TAG];
    if (!CGRectContainsPoint(aRect, textField.frame.origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, textField.frame.origin.y+kbSize.height);
        [infoTableView setContentOffset:scrollPoint animated:YES];
    }
}

/*
 Called when the UIKeyboardWillHideNotification is sent.
 */
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    infoTableView.contentInset = contentInsets;
    infoTableView.scrollIndicatorInsets = contentInsets;
}

/*
 * Helper for generic error messages
 * showin in UIAlertView
 */
- (void) showAlertErrorMessage:(NSString *)message {
    UIAlertView *alertView = [[UIAlertView alloc] 
                              initWithTitle:@"Error" 
                              message:message
                              delegate:nil 
                              cancelButtonTitle:@"OK" 
                              otherButtonTitles:nil, 
                              nil];
    [alertView show];
    [alertView release];
}

#pragma mark -

/*
 * Private methods
 */
- (void) showLoggedIn {
    loginButton.hidden = YES;
    wishlistPickerView.hidden = NO;
    infoTableView.hidden = NO;
    
    [self apiFQLIMe];
}

- (void) showLoggedOut:(BOOL)clearInfo {
    // Remove saved authorization information if it exists and it is
    // ok to clear it (logout, session invalid, app unauthorized)
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (clearInfo && [defaults objectForKey:@"FBAccessTokenKey"]) {
        [defaults removeObjectForKey:@"FBAccessTokenKey"];
        [defaults removeObjectForKey:@"FBExpirationDateKey"];
        [defaults synchronize];
        
        // Nil out the session variables to prevent
        // the app from thinking there is a valid session
        if (nil != [facebook accessToken]) {
            facebook.accessToken = nil;
        }
        if (nil != [facebook expirationDate]) {
            facebook.expirationDate = nil;
        }
    }
    
    // Clear personal info
    profileNameLabel.text = @"";
    // Get the profile image
    [profileImageView setImage:nil];
    
    loginButton.hidden = NO;
    wishlistPickerView.hidden = YES;
    infoTableView.hidden = YES;
}

/**
 * Show the authorization dialog.
 */
- (void)login {
    // Check and retrieve authorization information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FBAccessTokenKey"] 
        && [defaults objectForKey:@"FBExpirationDateKey"]) {
        facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
        facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
    }
    if (![facebook isSessionValid]) {
        facebook.sessionDelegate = self;
        NSArray *permissions = [[NSArray alloc] initWithObjects:
                                @"publish_actions", 
                                @"offline_access", 
                                nil];
        [facebook authorize:permissions];
        [permissions release];
    } else {
        [self showLoggedIn];
        //[self apiFQLIMe];
    }
}

/**
 * Invalidate the access token and clear the cookie.
 */
- (void)logout {
    [facebook logout:self];
}

#pragma mark -

/*
 * Bring the picker up from the bottom
 */
- (void) showWishlistPicker {
    CGRect moveFrame = wishlistPickerView.frame;
    moveFrame.origin.y = self.view.bounds.size.height - wishlistPickerView.frame.size.height;
    [UIView animateWithDuration:0.5
                          delay:0.5
                        options: UIViewAnimationCurveEaseOut
                     animations:^{
                         wishlistPickerView.frame = moveFrame;
                     } 
                     completion:^(BOOL finished){
                         wishlistPickerVisible = YES;
                     }];
}

/* 
 * Send the picker back to the bottom
 */
- (void) hideWishlistPicker {
    CGRect moveFrame = wishlistPickerView.frame;
    moveFrame.origin.y = self.view.bounds.size.height + wishlistPickerView.frame.size.height;
    [UIView animateWithDuration:0.5
                          delay:1.0
                        options: UIViewAnimationCurveEaseOut
                     animations:^{
                         wishlistPickerView.frame = moveFrame;
                     } 
                     completion:^(BOOL finished){
                         wishlistPickerVisible = NO;
                     }];
}

#pragma mark - 

/*
 Called when either the camera or library button is tapped. Sets up the
 image picker and presents it.
 */
- (void)showImagePicker:(UIImagePickerControllerSourceType)sourceType
{
    // Do not show the picker if not supported, example if there is
    // no camera, tapping the camera button will do nothing.
    if ([UIImagePickerController isSourceTypeAvailable:sourceType])
    {
        if (UIUserInterfaceIdiomPad == UI_USER_INTERFACE_IDIOM()) {
            UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:self.imagePickerController] ;
            //popover.delegate = self;
            [popover presentPopoverFromRect:CGRectMake(self.view.bounds.size.width,0,10,10) inView:self.view permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
        } else {
            self.imagePickerController.sourceType = sourceType;
            [self presentModalViewController:self.imagePickerController animated:YES];
        }
    }
}

/*
 Called to show the camera/library buttons. This is needed
 since these buttons share the same space with the image
 taken. So when the selected image is shown the buttons are
 hidden.
 */
-(void) setPhotoButtonsVisibility:(BOOL)showButtons {
    if (showButtons) {
        productPhotoImageView.hidden = YES;
        libraryButton.hidden = NO;
        libraryLabel.hidden = NO;
        cameraButton.hidden = NO;
        cameraLabel.hidden = NO;
    } else {
        productPhotoImageView.hidden = NO;
        libraryButton.hidden = YES;
        cameraButton.hidden = YES;
        libraryLabel.hidden = YES;
        cameraLabel.hidden = YES;
    }
}

/*
 * Handles the camera button click
 */
- (void) cameraButtonClicked:(id) sender {
    if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
        [self setPhotoButtonsVisibility:NO];
        [self showImagePicker:UIImagePickerControllerSourceTypeCamera];
    }
}

/*
 * Handles the photo library click
 */
- (void) libraryButtonClicked:(id) sender {
    [self setPhotoButtonsVisibility:NO];
    [self showImagePicker:UIImagePickerControllerSourceTypePhotoLibrary];
}
   
/*
 * To help scale and crop the images
 */
- (UIImage *)imageByScalingAndCroppingForSize:(CGSize)targetSize source:(UIImage *)sourceImage
{
	UIImage *newImage = nil;        
	CGSize imageSize = sourceImage.size;
	CGFloat width = imageSize.width;
	CGFloat height = imageSize.height;
	CGFloat targetWidth = targetSize.width;
	CGFloat targetHeight = targetSize.height;
	CGFloat scaleFactor = 0.0;
	CGFloat scaledWidth = targetWidth;
	CGFloat scaledHeight = targetHeight;
	CGPoint thumbnailPoint = CGPointMake(0.0,0.0);
	
	if (CGSizeEqualToSize(imageSize, targetSize) == NO) 
	{
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;
		
        if (widthFactor > heightFactor) 
			scaleFactor = widthFactor; // scale to fit height
        else
			scaleFactor = heightFactor; // scale to fit width
        scaledWidth  = width * scaleFactor;
        scaledHeight = height * scaleFactor;
		
        // center the image
        if (widthFactor > heightFactor)
		{
			thumbnailPoint.y = (targetHeight - scaledHeight) * 0.5; 
		}
        else 
			if (widthFactor < heightFactor)
			{
				thumbnailPoint.x = (targetWidth - scaledWidth) * 0.5;
			}
	}       
	
	UIGraphicsBeginImageContext(targetSize); // this will crop
	
	CGRect thumbnailRect = CGRectZero;
	thumbnailRect.origin = thumbnailPoint;
	thumbnailRect.size.width  = scaledWidth;
	thumbnailRect.size.height = scaledHeight;
	
	[sourceImage drawInRect:thumbnailRect];
	
	newImage = UIGraphicsGetImageFromCurrentImageContext();
	
	//pop the context to get back to the default
	UIGraphicsEndImageContext();
	return newImage;
}

#pragma mark -

/*
 Method called to show the list of nearby search results
 */
- (void) showNearbyViewModally:(NSArray *)placeData
{
    NearbyViewController *nearbyController = [[[NearbyViewController alloc] initWithTitle:@"Nearby" data:placeData] autorelease];
    nearbyController.delegate = self;
    [nearbyController showNearbyPicker:self];
}

/*
 Method called when user location found. Calls the search API with the most
 recent location reading.
 */
- (void) processLocationData
{
    // Stop updating location information
    [locationManager stopUpdatingLocation];
    locationManager.delegate = nil;
    
    // Call the API to get nearby search results
    [self apiGraphSearchPlace:mostRecentLocation];
}

/*
 Helper method to kick off GPS to get the user's location. 
 */
- (void) getNearby {
    [self showActivityIndicator:@"Finding location"];
    // A warning if the user turned off location services.
    if (![CLLocationManager locationServicesEnabled]) {
        UIAlertView *servicesDisabledAlert = [[UIAlertView alloc] initWithTitle:@"Location Services Disabled" message:@"You currently have all location services for this device disabled. If you proceed, you will be asked to confirm whether location services should be reenabled." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [servicesDisabledAlert show];
        [servicesDisabledAlert release];
    }
    // Start the location manager
    self.locationManager = [[[CLLocationManager alloc] init] autorelease];
    locationManager.delegate = self;
    locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    [locationManager startUpdatingLocation];
    // Time out if it takes too long to get a reading.
    [self performSelector:@selector(processLocationData) withObject:nil afterDelay:10.0];
}

#pragma mark -

/*
 Helper method for posting photo.
 */
-(NSURLRequest *) postRequestWithURL:(NSString *)url data: (NSData *)data   
                            fileName: (NSString*)fileName
{
    NSMutableURLRequest *urlRequest = [[[NSMutableURLRequest alloc] init] autorelease];
    [urlRequest setURL:[NSURL URLWithString:url]];
    
    [urlRequest setHTTPMethod:@"POST"];
    
    NSString *myboundary = [NSString stringWithString:@"---------------------------14737809831466499882746641449"];
    NSString *contentType = [NSString stringWithFormat:@"multipart/form-data; boundary=%@",myboundary];
    [urlRequest addValue:contentType forHTTPHeaderField: @"Content-Type"];
    
    NSMutableData *postData = [NSMutableData data];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"source\"; filename=\"%@\"\r\n", fileName]dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[[NSString stringWithString:@"Content-Type: application/octet-stream\r\n\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];
    [postData appendData:[NSData dataWithData:data]];
    [postData appendData:[[NSString stringWithFormat:@"\r\n--%@--\r\n", myboundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    [urlRequest setHTTPBody:postData];
    return urlRequest;
}

/*
 Start sending product information to server
 */
- (void) sendInfoButtonClicked:(id) sender {
    // Do some data checks and throw an error if information has not been
    // provided
    if (self.productImage == nil) {
        [self showAlertErrorMessage:@"Please add a product photo." ];
    } else if ([self.productName isEqualToString:@""]) {
        [self showAlertErrorMessage:@"Please enter a product name." ];
    } else {
        [self showActivityIndicator:@"Uploading photo"];
        
        // Prepare the photo data that will be sent to the server first.
        // We are sending the photo in JPEG format.
        NSData *imageData = UIImageJPEGRepresentation(productImage, 90);
        
        // Set up the call to post the photo
        NSURLRequest *urlRequest = [self postRequestWithURL:
                                    [NSString stringWithFormat:@"%@/photo_upload.php",kBackEndServer]
                                                       data:imageData
                                                   fileName:@"myImage"];
        
        uploadConnection =[[NSURLConnection alloc] initWithRequest:urlRequest delegate:self];
    }
    
}

/*
 Clear product information so user can enter new info
 */
- (void) clearProductInfo {
    [self setPhotoButtonsVisibility:YES];
    [self.productPhotoImageView setImage:nil];
    self.productImage = nil;
    self.productName = @"";
    UITextField *textField = (UITextField *) [self.view viewWithTag:PRODUCT_NAME_TAG];
    textField.text = @"";
}

/*
 Send the app request
 */

//sendRequestButtonClicked
- (void) sendRequestButtonClicked:(id) sender {
    NSMutableDictionary* params = [NSMutableDictionary dictionaryWithObjectsAndKeys:
                                   @"Check out this awesome app I am using.",  @"message",
                                   @"Check this out", @"notification_text",
                                   nil];
     
    [facebook dialog:@"apprequests"
                      andParams:params
                    andDelegate:self];
}

#pragma mark - View lifecycle


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    // ----------------------------------
    // Initialize Facebook
    // ----------------------------------
    facebook = [[Facebook alloc] initWithAppId:kAppId andDelegate:self];
    
    // ----------------------------------
    // Data
    // ----------------------------------
    
    // Wishlist choices
    wishlistChoices = [[NSMutableArray alloc] init];
    [wishlistChoices addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                @"Birthday Wishlist", @"name", 
                                [NSString stringWithFormat:@"%@/wishlists/birthday.php",kBackEndServer], @"link",  
                                nil]];
    [wishlistChoices addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                @"Holiday Wishlist", @"name", 
                                [NSString stringWithFormat:@"%@/wishlists/holiday.php",kBackEndServer], @"link",  
                                nil]];
    [wishlistChoices addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                @"Wedding Wishlist", @"name", 
                                [NSString stringWithFormat:@"%@/wishlists/wedding.php",kBackEndServer], @"link",  
                                nil]];
    
    selectedWishlist = 0;
    
    self.selectedPlace = [[NSString alloc] initWithString:@""];
    
    self.productImageData = [[NSMutableDictionary alloc] init];
    
    self.nearbyData = [[NSMutableArray alloc] init];
    
    self.productImage = nil;
    self.productName = [[NSString alloc] initWithString:@""];
    
    // Setup main view
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen 
                                                  mainScreen].applicationFrame]; 
    [view setBackgroundColor:[UIColor whiteColor]]; 
    self.title = @"Home";
    self.view = view; 
    [view release]; 
    
    // ----------------------------------
    // Logged out view elements
    // ----------------------------------
    
    // Login Button
    loginButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    loginButton.frame = CGRectMake(0,0,318,58);
    loginButton.center = CGPointMake(self.view.center.x, self.view.center.y);
    [loginButton addTarget:self
                    action:@selector(login)
          forControlEvents:UIControlEventTouchUpInside];
    [loginButton setImage:
     [UIImage imageNamed:@"FBConnect.bundle/images/LoginWithFacebookNormal@2x.png"] 
                 forState:UIControlStateNormal];
    [loginButton setImage:
     [UIImage imageNamed:@"FBConnect.bundle/images/LoginWithFacebookPressed@2x.png"] 
                 forState:UIControlStateHighlighted];
    [loginButton sizeToFit];
    [self.view addSubview:loginButton];
    
    // ----------------------------------
    // Logged in view elements
    // ----------------------------------
    
    // Table View for Info
    UIView *headerView = [[UIView alloc] 
                  initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 60)];
    headerView.autoresizingMask =  UIViewAutoresizingFlexibleWidth;
    UIColor *facebookBlue = [UIColor 
                             colorWithRed:59.0/255.0 
                             green:89.0/255.0 
                             blue:152.0/255.0 
                             alpha:1.0];
    headerView.backgroundColor = facebookBlue;
    profileImageView = [[UIImageView alloc] initWithFrame:CGRectMake(5, 5, 50, 50)];
    [headerView addSubview:profileImageView];
    profileNameLabel = [[UILabel alloc] initWithFrame:CGRectMake(60, 5, (self.view.bounds.size.width-60), 20)];
    profileNameLabel.backgroundColor = facebookBlue;
    profileNameLabel.numberOfLines = 2;
    profileNameLabel.font = [UIFont fontWithName:@"Helvetica" size:14.0];
    profileNameLabel.textColor = [UIColor whiteColor];
    [headerView addSubview:profileNameLabel];
    UIButton *logoutButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    logoutButton.frame = CGRectMake(60,25,81,29);
    [logoutButton addTarget:self
                    action:@selector(logout)
          forControlEvents:UIControlEventTouchUpInside];
    [logoutButton setImage:
     [UIImage imageNamed:@"FBConnect.bundle/images/LogoutNormal.png"] 
                 forState:UIControlStateNormal];
    [logoutButton setImage:
     [UIImage imageNamed:@"FBConnect.bundle/images/LogoutPressed.png"] 
                 forState:UIControlStateHighlighted];
    [logoutButton sizeToFit];
    [headerView addSubview:logoutButton];
    
    UIView *footerView = [[UIView alloc] 
                  initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 120)];
    footerView.autoresizingMask =  UIViewAutoresizingFlexibleWidth;
    
    // Add to Timeline button
    UIButton *addToTimeLineButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    addToTimeLineButton.frame = CGRectMake(10, 10, (self.view.bounds.size.width - 20), 40);
    addToTimeLineButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    [addToTimeLineButton setTitle:@"Add to Timeline" 
            forState:UIControlStateNormal];
    [addToTimeLineButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [addToTimeLineButton addTarget:self action:@selector(sendInfoButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:addToTimeLineButton];
    
    // Send App Request button
    UIButton *sendRequestButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    sendRequestButton.frame = CGRectMake(10, 70, (self.view.bounds.size.width - 20), 40);
    sendRequestButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
    [sendRequestButton setTitle:@"Send Request" 
                         forState:UIControlStateNormal];
    [sendRequestButton setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    [sendRequestButton addTarget:self action:@selector(sendRequestButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
    [footerView addSubview:sendRequestButton];
    
    infoTableView = [[UITableView alloc] initWithFrame:self.view.bounds 
                                                style:UITableViewStylePlain];
    [infoTableView setBackgroundColor:[UIColor whiteColor]];
    infoTableView.dataSource = self;
    infoTableView.delegate = self;
    infoTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    infoTableView.tableHeaderView = headerView;
    infoTableView.tableFooterView = footerView;
    [self.view addSubview:infoTableView];
    [footerView release];
    
    // Wishlist Picker
    // Place picker beyond the bottom
    if (UIUserInterfaceIdiomPad == UI_USER_INTERFACE_IDIOM()) {
        CGFloat yPickerOffset = self.view.frame.size.height + 216;
        wishlistPickerView = [[UIPickerView alloc]initWithFrame: CGRectMake (0, yPickerOffset, self.view.frame.size.width, 216)];
    } else {
        wishlistPickerView = [[UIPickerView alloc] init];
        CGSize pickerSize = [self.wishlistPickerView sizeThatFits:CGSizeZero];
        CGFloat yPickerOffset = self.view.frame.size.height + wishlistPickerView.frame.size.height;
        CGRect pickerFrame = CGRectMake(0.0,yPickerOffset,pickerSize.width,pickerSize.height);
        self.wishlistPickerView.frame = pickerFrame;
    }
    wishlistPickerView.delegate = self;
    wishlistPickerView.showsSelectionIndicator = YES;
    [self.view addSubview:wishlistPickerView];
    
    self.imagePickerController = [[[UIImagePickerController alloc] init] autorelease];
    self.imagePickerController.delegate = self;

    // Activity Indicator
    activityIndicatorView = [[UIView alloc] initWithFrame:CGRectMake((self.view.center.x-60.0), (self.view.center.y-60.0), 120, 120)];
    activityIndicatorView.layer.cornerRadius = 8;
    activityIndicatorView.alpha = 0.8;
    activityIndicatorView.backgroundColor = [UIColor blackColor];
    activityIndicator = [[UIActivityIndicatorView alloc] initWithFrame:CGRectMake(40, 30, 40, 40)];
    activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleWhiteLarge;
    [activityIndicatorView addSubview:activityIndicator];
    activityLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 90, 120, 20)];
    activityLabel.textAlignment = UITextAlignmentCenter;
    activityLabel.textColor = [UIColor whiteColor];
    activityLabel.backgroundColor = [UIColor clearColor];
    activityLabel.font = [UIFont fontWithName:@"Helvetica" size:12.0];
    activityLabel.text = @"";
    [activityIndicatorView addSubview:activityLabel];
    [self.view addSubview:activityIndicatorView];
    activityIndicatorView.hidden = YES;
    
    // Register for notifications to detect keyboard changes if
    // not an iPad
    if (UIUserInterfaceIdiomPad != UI_USER_INTERFACE_IDIOM()) {
        [self registerForKeyboardNotifications];
    }
}

- (void)viewDidUnload
{
    [self unregisterForKeyboardNotifications];
    
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // Check and retrieve authorization information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults objectForKey:@"FBAccessTokenKey"] 
        && [defaults objectForKey:@"FBExpirationDateKey"]) {
        facebook.accessToken = [defaults objectForKey:@"FBAccessTokenKey"];
        facebook.expirationDate = [defaults objectForKey:@"FBExpirationDateKey"];
    }
    // After retrieving any authorization data, make an additional
    // check to see if it is still valid.
    if (![facebook isSessionValid]) {
        // Show logged out state
        [self showLoggedOut:NO];
    } else {
        // Show logged in state
        [self showLoggedIn];
    }
}

/*
 This method handles any clean up needed if the view
 is about to disappear.
 */
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    // Hide the activitiy indicator
    [self hideActivityIndicator];
}
    
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:
(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration
{
    if (wishlistPickerView) {
        if (UIUserInterfaceIdiomPad == UI_USER_INTERFACE_IDIOM()) {
            CGFloat yPickerOffset = self.view.bounds.size.height + 216;
            wishlistPickerView.frame = CGRectMake (0, yPickerOffset, self.view.bounds.size.width, 216);
        } else {
            CGFloat yPickerOffset = self.view.frame.size.height + wishlistPickerView.frame.size.height;
            wishlistPickerView.frame = CGRectMake (0, yPickerOffset, self.view.bounds.size.width, wishlistPickerView.frame.size.height);
        }
    }
}

#pragma mark - UITableViewDatasource and UITableViewDelegate Methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGFloat rowHeight = 40.0;
    switch (indexPath.section) {
        case 0:
            rowHeight = 40;
            break;
        case 1:
            rowHeight = 220;
            break; 
        case 4:
            rowHeight = 60;
            break;
        default:
            break;
    }
    return rowHeight;
}

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 5;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 4) {
        return 0;
    } else {
        return 1;
    }
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier] autorelease];
        
        switch (indexPath.section) {
            case 0:
            {
                // Wishlist row
                cell.textLabel.text = @"Wishlist";
                cell.detailTextLabel.text = [[wishlistChoices objectAtIndex:selectedWishlist] objectForKey:@"name"];
                cell.detailTextLabel.tag = WISHLIST_TITLE_TAG;
                cell.detailTextLabel.textColor = [UIColor darkGrayColor];
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
            case 1:
            {
                // Camera/Library/Product Photo row
                
                // Product photo
                productPhotoImageView = [[UIImageView alloc]
                                         initWithFrame:CGRectMake(20, 10, (cell.contentView.frame.size.width-40), 200)];
                productPhotoImageView.autoresizingMask =  UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
                [productPhotoImageView setImage:nil];
                productPhotoImageView.hidden = YES;
                [cell.contentView addSubview:productPhotoImageView];
                
                // Library button
                libraryButton = [UIButton buttonWithType:UIButtonTypeCustom];
                [libraryButton setImage:[UIImage imageNamed:@"library.png"] forState:UIControlStateNormal];
                [libraryButton addTarget:self action:@selector(libraryButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
                libraryButton.frame = CGRectMake(0, 0, 100, 100);
                libraryButton.center = CGPointMake((cell.contentView.bounds.size.width*0.75), 100);
                libraryButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
                [cell.contentView addSubview:libraryButton];
                
                // Library label
                libraryLabel = [[UILabel alloc] initWithFrame:CGRectZero];
                libraryLabel.textAlignment = UITextAlignmentCenter;
                libraryLabel.font = [UIFont boldSystemFontOfSize:12.0];
                libraryLabel.text = @"Library";
                libraryLabel.frame = CGRectMake(0, 0, 100, 20);
                libraryLabel.center = CGPointMake((cell.contentView.bounds.size.width*0.75), 160);
                libraryLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
                [cell.contentView addSubview:libraryLabel];
                
                // Camera button
                cameraButton = [UIButton buttonWithType:UIButtonTypeCustom];
                cameraButton.frame = CGRectMake(0, 0, 100, 100);
                cameraButton.center = CGPointMake((cell.contentView.bounds.size.width/4), 100);
                [cameraButton setImage:[UIImage imageNamed:@"camera.png"] forState:UIControlStateNormal];
                [cameraButton addTarget:self action:@selector(cameraButtonClicked:) forControlEvents:UIControlEventTouchUpInside];
                cameraButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
                [cell.contentView addSubview:cameraButton];
                
                // Camera label
                cameraLabel = [[UILabel alloc] initWithFrame:CGRectZero];
                cameraLabel.textAlignment = UITextAlignmentCenter;
                cameraLabel.font = [UIFont boldSystemFontOfSize:12.0];
                cameraLabel.text = @"Camera";
                cameraLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
                cameraLabel.frame = CGRectMake(0, 0, 100, 20);
                cameraLabel.center = CGPointMake((cell.contentView.bounds.size.width/4), 160);
                [cell.contentView addSubview:cameraLabel];
                
                if (productImage) {
                    [self.productPhotoImageView setImage:productImage];
                    [self setPhotoButtonsVisibility:NO];
                } else {
                    [self setPhotoButtonsVisibility:YES];
                }
                break;
            }
            case 2:
            {
                // Product name row
                cell.textLabel.text = @"Name";
                UITextField *textField = [[UITextField alloc] initWithFrame:CGRectMake(5, 10, (cell.contentView.frame.size.width- 15), 20)];
                textField.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
                textField.tag = PRODUCT_NAME_TAG;
                textField.textAlignment = UITextAlignmentRight;
                textField.textColor = [UIColor darkGrayColor];
                textField.placeholder = @"Enter name";
                textField.delegate = self;
                textField.text = self.productName;
                [cell.contentView addSubview:textField];
                [textField release];
                break;
            }
            case 3:
            {
                // Location row
                cell.textLabel.text = @"Location";
                cell.detailTextLabel.text = @"(optional)";
                cell.detailTextLabel.textColor = [UIColor darkGrayColor];
                cell.detailTextLabel.tag = PLACE_NAME_TAG;
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            }
            default:
            {
                break;
            }
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    switch (indexPath.section) {
        case 0:
        {
            // Show or hide the wishlist picker based on
            // it's current state, visible or not. This
            // provides an easy way to dismiss the picker
            // by tapping the corresponding table row.
            if (wishlistPickerVisible) {
                [self hideWishlistPicker];
            } else {
                [self showWishlistPicker];
            }
            break;
        }
        case 3: {
            // Get the nearby locations by kicking of the current
            // location information
            [self getNearby];
            break;
        }
        default:
        {
            break;
        }
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

#pragma mark - UIPickerView Methods
- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)thePickerView numberOfRowsInComponent:(NSInteger)component {
    return [wishlistChoices count];
}

- (NSString *)pickerView:(UIPickerView *)thePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [[wishlistChoices objectAtIndex:row] objectForKey:@"name"];
}

- (void)pickerView:(UIPickerView *)thePickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {
    selectedWishlist = row;
    UILabel *wishListLabel = (UILabel *) [self.view viewWithTag:WISHLIST_TITLE_TAG];
    wishListLabel.text = [[wishlistChoices objectAtIndex:row] objectForKey:@"name"];
    // Hide the picker after a user choice
    [self hideWishlistPicker];
}

- (CGFloat)pickerView:(UIPickerView *)pickerView widthForComponent:(NSInteger)component {
    return self.view.bounds.size.width;
}

#pragma mark - UIImagePickerControllerDelegate

/*
 Called when an image has been chosen from the library or taken from the camera. The
 continue button is made visible so the user can continue the product upload flow.
 */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [self dismissModalViewControllerAnimated:YES];
    
    // Scale and crop image as necessary
	UIImage *image = [info valueForKey:UIImagePickerControllerOriginalImage];
	CGSize targetSize = CGSizeMake(productPhotoImageView.bounds.size.width, productPhotoImageView.bounds.size.height);
    
    // Save the image so that if table cleared we still have the information
	self.productImage = [self imageByScalingAndCroppingForSize:targetSize source:image];
    [self.productPhotoImageView setImage:productImage];
}

/*
 Called when the user cancels the photo picker action.
 */
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [self dismissModalViewControllerAnimated:YES];
    [self setPhotoButtonsVisibility:YES];
}

/*
 * For iPad, is user clicks outside popover
 */
- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController{
    
	[self dismissModalViewControllerAnimated:YES];
    [self setPhotoButtonsVisibility:YES];
}

#pragma mark - UITextFieldDelegate
/*
 Return should close keyboard
 */
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

/*
 Save the product name information when the keyboard is dismissed
 */
- (void)textFieldDidEndEditing:(UITextField *)textField
{
    self.productName = textField.text;
}

#pragma mark - NearbyViewControllerDelegate
/*
 Delegate handler for our NearbyViewController. This method is called when
 the user has selected a place.
 */
- (void) placeSelector:(NearbyViewController *)controller didSelectPlace:(NSDictionary *)place
{
    // If the user did not tap Cancel on the nearby page selection.
    if (place != nil) {
        // Fill the information in the relevant table row
        UILabel *placeLabel = (UILabel *) [self.view viewWithTag:PLACE_NAME_TAG];
        placeLabel.text = [place objectForKey:@"name"];
        // Save the information for the final submission
        self.selectedPlace = [place objectForKey:@"id"];
    }
    [self dismissModalViewControllerAnimated:YES];
}

#pragma mark - CLLocationManager Delegate Methods
- (void)locationManager:(CLLocationManager *)manager didUpdateToLocation:(CLLocation *)newLocation fromLocation:(CLLocation *)oldLocation {
    // We will care about horizontal accuracy for this example
    
    // Try and avoid cached measurements
    NSTimeInterval locationAge = -[newLocation.timestamp timeIntervalSinceNow];
    if (locationAge > 5.0) return;
    // test that the horizontal accuracy does not indicate an invalid measurement
    if (newLocation.horizontalAccuracy < 0) return;
    // test the measurement to see if it is more accurate than the previous measurement
    if (mostRecentLocation == nil || mostRecentLocation.horizontalAccuracy > newLocation.horizontalAccuracy) {
        // Store current location
        self.mostRecentLocation = newLocation;
        if (newLocation.horizontalAccuracy <= locationManager.desiredAccuracy) {
            // Measurement is good
            [self processLocationData];
            // we can also cancel our previous performSelector:withObject:afterDelay: - it's no longer necessary
            [NSObject cancelPreviousPerformRequestsWithTarget:self 
                                                     selector:@selector(processLocationData) 
                                                       object:nil];
        }
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    if ([error code] != kCLErrorLocationUnknown) {
        [locationManager stopUpdatingLocation];
        locationManager.delegate = nil;
    }
    [self hideActivityIndicator];
}

#pragma mark - NSURLConnectionDelegate
- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    receivedData = [[NSMutableData alloc] init];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [receivedData appendData:data];
}

- (NSCachedURLResponse *)connection:(NSURLConnection *)connection
                  willCacheResponse:(NSCachedURLResponse*)cachedResponse {
    return nil;
}

- (void) clearConnection {
    [receivedData release];
    receivedData = nil;
    [uploadConnection release];
    uploadConnection = nil;
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    [self hideActivityIndicator];
    
    NSString* responseString = [[[NSString alloc] initWithData:receivedData
                                                      encoding:NSUTF8StringEncoding]
                                autorelease];
    NSLog(@"Response from photo upload: %@",responseString);
    [self clearConnection];
    // Check the photo upload server completes successfully
    if ([responseString rangeOfString:@"ERROR:"].location == NSNotFound) {
        SBJSON *jsonParser = [[SBJSON new] autorelease];
        id result = [jsonParser objectWithString:responseString];
        // Look for expected parameter back
        if ([result objectForKey:@"image_name"]) {
            productImageData = [result copy];
            // Now that we have successfully uploaded the photo
            // we will make the Graph API call to send our Wishlist
            // information.
            [self apiGraphAddToWishlist];
        } else {
            [self showAlertErrorMessage:@"Could not upload the photo." ];
        }
    } else {
        [self showAlertErrorMessage:@"Could not upload the photo." ];
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Err message: %@", [[error userInfo] objectForKey:@"error_msg"]);
    NSLog(@"Err code: %d", [error code]);
    [self hideActivityIndicator];
    [self showAlertErrorMessage:@"Could not upload the photo." ];
    [self clearConnection];
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    // Clear product information, leave wishlist and location along
    [self clearProductInfo];
}

#pragma mark - FBSessionDelegate Methods
/**
 * Called when the user has logged in successfully.
 */
- (void)fbDidLogin {
    [self showLoggedIn];
    //[self apiFQLIMe];
    
    // Save authorization information
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:[facebook accessToken] forKey:@"FBAccessTokenKey"];
    [defaults setObject:[facebook expirationDate] forKey:@"FBExpirationDateKey"];
    [defaults synchronize];
}

/**
 * Called when the user canceled the authorization dialog.
 */
-(void)fbDidNotLogin:(BOOL)cancelled {
    NSLog(@"did not login");
}

/**
 * Called when the request logout has succeeded.
 */
- (void)fbDidLogout {
    [self showLoggedOut:YES];
}

#pragma mark - FBRequestDelegate Methods
/**
 * Called when the Facebook API request has returned a response. This callback
 * gives you access to the raw response. It's called before
 * (void)request:(FBRequest *)request didLoad:(id)result,
 * which is passed the parsed response object.
 */
- (void)request:(FBRequest *)request didReceiveResponse:(NSURLResponse *)response {
    //NSLog(@"received response");
}

/**
 * Called when a request returns and its response has been parsed into
 * an object. The resulting object may be a dictionary, an array, a string,
 * or a number, depending on the format of the API response. If you need access
 * to the raw response, use:
 *
 * (void)request:(FBRequest *)request
 *      didReceiveResponse:(NSURLResponse *)response
 */
- (void)request:(FBRequest *)request didLoad:(id)result {
    [self hideActivityIndicator];
    if ([result isKindOfClass:[NSArray class]]) {
        result = [result objectAtIndex:0];
    }
    switch (currentAPICall) {
        case kAPIFQLMe:
        {
            // This callback can be a result of getting the user's basic
            // information or getting the user's permissions.
            if ([result objectForKey:@"name"]) {
                // If basic information callback, set the UI objects to
                // display this.
                self.profileNameLabel.text = [result objectForKey:@"name"];
                // Get the profile image
                UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:[result objectForKey:@"pic"]]]];
                
                // Resize, crop the image to make sure it is square and renders
                // well on Retina display
                float ratio;
                float delta;
                float px = 100; // Double the pixels of the UIImageView (to render on Retina)
                CGPoint offset;
                CGSize size = image.size;
                if (size.width > size.height) {
                    ratio = px / size.width;
                    delta = (ratio*size.width - ratio*size.height);
                    offset = CGPointMake(delta/2, 0);
                } else {
                    ratio = px / size.height;
                    delta = (ratio*size.height - ratio*size.width);
                    offset = CGPointMake(0, delta/2);
                }
                CGRect clipRect = CGRectMake(-offset.x, -offset.y,
                                             (ratio * size.width) + delta,
                                             (ratio * size.height) + delta);
                UIGraphicsBeginImageContext(CGSizeMake(px, px));
                UIRectClip(clipRect);
                [image drawInRect:clipRect];
                UIImage *imgThumb =   UIGraphicsGetImageFromCurrentImageContext();
                [imgThumb retain];
                
                [profileImageView setImage:imgThumb];
            } 
            break;
        }
        case kAPIGraphSearchPlace: {
            // Nearby data
            NSMutableArray *places = [[NSMutableArray alloc] initWithCapacity:1];
            NSArray *resultData = [result objectForKey:@"data"];
            for (NSUInteger i=0; i<[resultData count] && i < 5; i++) {
                [places addObject:[resultData objectAtIndex:i]];
            }
            [self showNearbyViewModally:places];
            [places release];
            break;
        }
        case kAPIGraphWishlist: {
            // Wishlist call
            //NSLog(@"Result: %@", result);
            UIAlertView *alertView = [[UIAlertView alloc] 
                                      initWithTitle:@"Success" 
                                      message:@"Your wishlist was added to your timeline." 
                                      delegate:self 
                                      cancelButtonTitle:@"Done" 
                                      otherButtonTitles:nil, 
                                      nil];
            [alertView show];
            [alertView release];
            break;
        }
        default:
            break;
    }
}

/**
 * Called when an error prevents the Facebook API request from completing
 * successfully.
 */
- (void)request:(FBRequest *)request didFailWithError:(NSError *)error {
    [self hideActivityIndicator];
    NSLog(@"Err message: %@", [[error userInfo] objectForKey:@"error_msg"]);
    NSLog(@"Err code: %d", [error code]);
    if ([error code] == 190) {
        [self showLoggedOut:YES];
    } else {
        [self showAlertErrorMessage:@"There was an error making your request." ];
    }
}

#pragma mark - FBDialogDelegate Methods

/**
 * Called when a UIServer Dialog successfully return.
 */
- (void)dialogDidComplete:(FBDialog *)dialog {
    UIAlertView *alertView = [[UIAlertView alloc] 
                              initWithTitle:@"Success" 
                              message:@"Your request was sent out." 
                              delegate:self 
                              cancelButtonTitle:@"Done" 
                              otherButtonTitles:nil, 
                              nil];
    [alertView show];
    [alertView release];
}

- (void) dialogDidNotComplete:(FBDialog *)dialog {
    NSLog(@"Dialog dismissed.");
}

- (void)dialog:(FBDialog*)dialog didFailWithError:(NSError *)error {
    NSLog(@"Error message: %@", [[error userInfo] objectForKey:@"error_msg"]);
    [self showAlertErrorMessage:@"There was an error making your request." ];
}

@end
