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

#import "NearbyViewController.h"


@implementation NearbyViewController

@synthesize myData;
@synthesize delegate;

- (id)initWithTitle:(NSString *) title data:(NSArray *)data
{
    self = [super init];
    if (self) {
        if (nil != data) {
            myData = [[NSMutableArray alloc] initWithArray:data copyItems:YES];
        }
        self.title = title;
    }
    return self;
}


- (void)dealloc
{
    [myData release];
    [delegate release];
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle


// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView
{
    UIView *view = [[UIView alloc] initWithFrame:[UIScreen 
                                                  mainScreen].applicationFrame]; 
    [view setBackgroundColor:[UIColor whiteColor]]; 
    self.view = view; 
    [view release]; 
    
    // Main Menu Table
    UITableView *myTableView = [[UITableView alloc] initWithFrame:self.view.bounds 
                                                            style:UITableViewStylePlain];
    [myTableView setBackgroundColor:[UIColor whiteColor]];
    myTableView.dataSource = self;
    myTableView.delegate = self;
    myTableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addSubview:myTableView];
    [myTableView release];
}


/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad
{
    [super viewDidLoad];
}
*/

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

#pragma mark - Private Methods
/*
 * Helper method to return the picture endpoint for a given Facebook
 * object. Useful for displaying user, friend, or location pictures.
 */
- (UIImage *) imageForObject:(NSString *)objectID {
    // Get the object image
    NSString *url = [[NSString alloc] initWithFormat:@"https://graph.facebook.com/%@/picture",objectID];
    UIImage *image = [UIImage imageWithData:[NSData dataWithContentsOfURL:[NSURL URLWithString:url]]];
    [url release];
    return image;
}


#pragma mark - UITableView Datasource and Delegate Methods
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 80.0;
}

// Customize the number of sections in the table view.
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [myData count];
}

- (void)cancelAction:(id)sender
{
    // Tell the delegate about the cancellation.
    if ( (self.delegate != nil) && [self.delegate respondsToSelector:@selector(placeSelector:didSelectPlace:)] ) {
        [self.delegate placeSelector:self didSelectPlace:nil];
    }
}

- (void)showNearbyPicker:(UIViewController *)parent
{
    UINavigationController *    nav;
    
    // Create a navigation controller with us as its root.
    
    nav = [[[UINavigationController alloc] initWithRootViewController:self] autorelease];
    
    // Set up the Cancel button on the left of the navigation bar.
    
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction:)] autorelease];
    
    // Present the navigation controller on the specified parent 
    // view controller.
    
    [parent presentModalViewController:nav animated:YES];
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier] autorelease];
    }
    
    cell.textLabel.text = [[myData objectAtIndex:indexPath.row] objectForKey:@"name"];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:14.0];
    cell.textLabel.lineBreakMode = UILineBreakModeWordWrap;
    cell.textLabel.numberOfLines = 2;
    // The object's image
    cell.imageView.image = [self imageForObject:[[myData objectAtIndex:indexPath.row] objectForKey:@"id"]];
    // Configure the cell.
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    // Tell the delegate about the selection.
    if ( (self.delegate != nil) && [self.delegate respondsToSelector:@selector(placeSelector:didSelectPlace:)] ) {
        [self.delegate placeSelector:self didSelectPlace:[self.myData objectAtIndex:indexPath.row]];
    }
}

@end
