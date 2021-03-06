/*
 * Copyright (c) Microsoft. All rights reserved. Licensed under the MIT license. See full license at the bottom of this file.
 */

#import "MasterViewController.h"
#import "DetailViewController.h"
#import "Office365Snippets.h"
#import "SnippetInfo.h"
#import "Office365ClientFetcher.h"

@interface MasterViewController ()
@property (copy, nonatomic) NSArray *sectionHeaders;
@property (copy, nonatomic) NSArray *snippetInfosBySection;
@property (strong, nonatomic) NSMutableString *runAllResultsString;
@property (assign, nonatomic) int              runAllSnippetsRemainingCount;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *runAllBarButtonItem;
@end

@implementation MasterViewController
- (void)awakeFromNib {
    [super awakeFromNib];

    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        self.clearsSelectionOnViewWillAppear = NO;
        self.preferredContentSize = CGSizeMake(320.0, 600.0);
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self setupTableSections];

    //Retrieve Office 365 service endpoint and resource ID paths for clients (Office365ClientFetcher)
    Office365Snippets *O365 = [[Office365Snippets alloc] init];
    [O365 fetchDiscoveryServiceEndpoints];

    //Creating two notifications for the O365 connect and disconnect state. If the app is in a disconnected state
    //we will disable the runAllBarButtonItem
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(office365Disconnect) name:@"Office365DidDisconnectNotification" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(office365Connect) name:@"Office365DidConnectNotification" object:nil];

}


-(void)office365Disconnect
{
    //Disables "Run All" bar buttom item. If the app is in a disconnected state
    //we will disable the runAllBarButtonItem
    self.runAllBarButtonItem.enabled = NO;

    // Automatically start the connect process after you disconnect.
    Office365Snippets *O365 = [[Office365Snippets alloc] init];
    [O365 fetchDiscoveryServiceEndpoints];
}

-(void)office365Connect
{
    //Enables "Run All" bar buttom item
    self.runAllBarButtonItem.enabled = YES;

}


-(void) dealloc
{

    [[NSNotificationCenter defaultCenter] removeObserver:self];

}


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    //Create a spinner to use in the app for long running operations
    if (!self.spinner)
    {
        self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        self.spinner.color = [UIColor blackColor];
        self.spinner.center = self.view.center;

        [self.view addSubview:self.spinner];
    }
}

- (void)setupTableSections
{
    NSMutableArray *calendarRows = [[NSMutableArray alloc] init];
    [calendarRows addObject:[SnippetInfo snippetInfoWithName:@"Get events"   action:@selector(performFetchCalendarEvents)]];
    [calendarRows addObject:[SnippetInfo snippetInfoWithName:@"Create event" action:@selector(performCreateCalendarEvent)]];
    [calendarRows addObject:[SnippetInfo snippetInfoWithName:@"Update event" action:@selector(performUpdateCalendarEvent)]];
    [calendarRows addObject:[SnippetInfo snippetInfoWithName:@"Delete event" action:@selector(performDeleteCalendarEvent)]];

    NSMutableArray *contactRows = [[NSMutableArray alloc] init];
    [contactRows addObject:[SnippetInfo snippetInfoWithName:@"Get contacts"   action:@selector(performFetchContacts)]];
    [contactRows addObject:[SnippetInfo snippetInfoWithName:@"Create contact" action:@selector(performCreateContact)]];
    [contactRows addObject:[SnippetInfo snippetInfoWithName:@"Update contact" action:@selector(performUpdateContact)]];
    [contactRows addObject:[SnippetInfo snippetInfoWithName:@"Delete contact" action:@selector(performDeleteContact)]];

    NSMutableArray *mailRows = [[NSMutableArray alloc] init];
    [mailRows addObject:[SnippetInfo snippetInfoWithName:@"Get messages"   action:@selector(performFetchMailMessages)]];
    [mailRows addObject:[SnippetInfo snippetInfoWithName:@"Create message" action:@selector(performCreateMailMessage)]];
    [mailRows addObject:[SnippetInfo snippetInfoWithName:@"Update message" action:@selector(performUpdateMailMessage)]];
    [mailRows addObject:[SnippetInfo snippetInfoWithName:@"Delete message" action:@selector(performDeleteMailMessage)]];

    NSMutableArray *filesRows = [[NSMutableArray alloc] init];
    [filesRows addObject:[SnippetInfo snippetInfoWithName:@"Get files" action:@selector(performFetchFiles)]];

    self.sectionHeaders        = @[@"Calendar", @"Contacts", @"Mail", @"Files"];
    self.snippetInfosBySection = @[calendarRows, contactRows, mailRows, filesRows];
}

#pragma mark - Segues
- (void)prepareForSegue:(UIStoryboardSegue *)segue
                 sender:(id)sender
{
    //When a table cell is clicked, show detail
    if ([segue.identifier isEqualToString:@"showDetail"]) {
        if ([sender isKindOfClass:[UITableViewCell class]]) {
            NSIndexPath *indexPath = [self.tableView indexPathForCell:sender];
            SnippetInfo *snippetInfo = self.snippetInfosBySection[indexPath.section][indexPath.row];

            [self.spinner startAnimating];
            [self.view bringSubviewToFront:self.spinner];

            IMP imp = [self methodForSelector:snippetInfo.action];
            void (*func)(id, SEL) = (void *)imp;
            func(self, snippetInfo.action);
        }

        // Get handle to the DetailViewController
        self.detailViewController = (DetailViewController *)[[segue destinationViewController] topViewController];

        self.detailViewController.navigationItem.leftBarButtonItem = self.splitViewController.displayModeButtonItem;
        self.detailViewController.navigationItem.leftItemsSupplementBackButton = YES;

        self.tableView.userInteractionEnabled = NO;
    }
}

#pragma mark - UITableViewDataSource
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return self.snippetInfosBySection.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [self.snippetInfosBySection[section] count];
}

// Get the section titles.
- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return self.sectionHeaders[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];

    SnippetInfo *snippetInfo = self.snippetInfosBySection[indexPath.section][indexPath.row];

    cell.textLabel.text = snippetInfo.name;

    return cell;
}

#pragma mark - Snippets and UI
// Update the UI based on the results of running a snippet.
- (void)updateUIWithResultString:(NSString *)resultString
                         success:(BOOL)success
                  snippetService:(NSString *)snippetService
                     snippetName:(NSString *)snippetName
{
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *displayString = resultString;

        if (self.runAllSnippetsRemainingCount > 0) {
            NSString *color   = success ? @"green" : @"red";
            NSString *message = success ? @"SUCCEEDED" : @"FAILED";

            NSString *tempString = [NSString stringWithFormat:@"<h4 style=\"color:%@\">%@ : %@ -- %@!</h4><br/>",
                                    color, snippetService, snippetName, message];

            [self.runAllResultsString appendString:tempString];
            self.runAllSnippetsRemainingCount--;

            displayString = [self.runAllResultsString copy];
        }

        [self.detailViewController setDetailItem:displayString];
        [self.detailViewController updateUI];

        if (self.runAllSnippetsRemainingCount == 0) {
            [self.spinner stopAnimating];
            self.tableView.userInteractionEnabled = YES;
        }
    });
}

//// Run all of the snippets.
- (IBAction)tapRunAll:(id)sender
{
    // Clear the results of detail view.
    self.runAllResultsString          = [[NSMutableString alloc] init];
    self.runAllSnippetsRemainingCount = 0;

    [self performSegueWithIdentifier:@"showDetail" sender:sender];

    //Show UI Spinner and disable user interaction on the table view
    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    [_spinner setColor:[UIColor blackColor]];
    _spinner.center = self.view.center;
    [self.tableView addSubview: _spinner];
    [self.tableView bringSubviewToFront:_spinner];
    _spinner.hidesWhenStopped = YES;
    [_spinner startAnimating];
    self.tableView.userInteractionEnabled = NO;

    // Run the list of snippets.

    for (NSArray *snippetGroup in self.snippetInfosBySection) {
        for (SnippetInfo *snippetInfo in snippetGroup) {
            self.runAllSnippetsRemainingCount++;
            // [self performSelector:snippetInfo.action];
            // http://stackoverflow.com/questions/7017281/performselector-may-cause-a-leak-because-its-selector-is-unknown
            IMP imp = [self methodForSelector:snippetInfo.action];
            void (*func)(id, SEL) = (void *)imp;
            func(self, snippetInfo.action);
        }
    }

    self.tableView.userInteractionEnabled=YES;
}


#pragma mark - Actions -Sample Cases

//This section contains sample cases that call into the O365 Snippets library (Office365Snippets.m).
//Here each sample corresponds with an action listed in the Office 365 Snippets pane in the app. They call
//the base snippet(s) needed to complete a particular operation, and return the result to the UI.
//Again, for just the pure snippet library, see Office365Snippets.m.



- (void)performFetchCalendarEvents
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    [snippetLibrary fetchCalendarEvents:^(NSArray *events, NSError *error) {
        NSString *resultText;
        BOOL success = (events.count != 0);

        if (!success) {
            resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to get the events from your O365 calendar. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the readme.", [error localizedDescription]];
        }
        else {
            NSMutableString *workingText = [[NSMutableString alloc] init];

            [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We retrieved the following events from your calendar:</h3>"];

            for(MSOutlookEvent *event in events) {
                [workingText appendFormat:@"<p>%@<br></p>", event.Subject];
            }

            [workingText appendFormat:@"</br><hr><p>For the code, see fetchCalendarEvents in Office365Snippets.m."];

            resultText = [workingText copy];
        }

        [self updateUIWithResultString:resultText
                               success:success
                        snippetService:@"Calendar"
                           snippetName:@"Get Events"];
    }];
}
- (void)performCreateCalendarEvent
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Populate the event details
    NSString *toEmailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *subject = [NSString stringWithFormat:@"New event created on %@", dateString];
    NSString *body = @"Congratulations, you created  this event from the Snippets app!";
    NSDate *start = [NSDate date];
    NSDate *end = [[NSDate date] dateByAddingTimeInterval: 3600];

    MSOutlookEvent *eventToCreate = [snippetLibrary outlookEventWithProperties:@[toEmailAddress]
                                                                           subject:subject
                                                                              body:body
                                                                             start:start
                                                                               end: end
                                       ];

    [snippetLibrary createCalendarEvent:eventToCreate
                         completion:^(MSOutlookEvent *addedEvent,  NSError *error) {
                             NSString *resultText;
                             BOOL success = (error== nil);

                             if (!success) {
                                 resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create an event in your calendar. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                             }
                             else {
                                 NSMutableString *workingText = [[NSMutableString alloc] init];
                                 [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new event in your calendar.</h3>"];
                                 [workingText appendFormat:@"<p>%@<br></p>", addedEvent.Subject];
                                 [workingText appendFormat:@"</br><hr><p>For the code, see createCalendarEvent in Office365Snippets.m."];

                                 resultText = workingText;
                             }

                             [self updateUIWithResultString:resultText
                                                    success:success
                                             snippetService:@"Calendar"
                                                snippetName:@"Create Event"];
                         }];

}
- (void)performUpdateCalendarEvent
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Populate the event details
    NSString *toEmailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *subject = [NSString stringWithFormat:@"New event created on %@", dateString];
    NSString *body = @"Congratulations, you created  this event from the Snippets app!";
    NSDate *start = [NSDate date];
    NSDate *end = [[NSDate date] dateByAddingTimeInterval: 3600];

    MSOutlookEvent *eventToCreate = [snippetLibrary outlookEventWithProperties:@[toEmailAddress]
                                                                       subject:subject
                                                                          body:body
                                                                         start:start
                                                                           end: end
                                     ];


    [snippetLibrary createCalendarEvent:eventToCreate
                                completion:^(MSOutlookEvent *addedEvent, NSError *error) {
                                    if (!addedEvent) {
                                        NSString *errorMessage = [NSString stringWithFormat: @"FAIL<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and update an event in your Office 365 calendar. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];

                                        [self updateUIWithResultString:errorMessage
                                                               success:NO
                                                        snippetService:@"Calendar"
                                                           snippetName:@"Update Event"];
                                        return;
                                    }

                                    //Create a date formatter to get the current date and time in the desired format
                                    NSDateFormatter *formatter;
                                    NSString        *dateString;
                                    formatter = [[NSDateFormatter alloc] init];
                                    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
                                    dateString = [formatter stringFromDate:[NSDate date]];

                                    addedEvent.Subject = [addedEvent.Subject stringByAppendingFormat:@" updated at %@", dateString];
                                    [addedEvent setRecurrence:SingleInstance];

                                    [snippetLibrary updateCalendarEvent:addedEvent
                                                           completion:^(MSOutlookEvent *updatedEvent, NSError *error) {
                                                               BOOL success = (updatedEvent != nil);
                                                               NSString *resultText;

                                                               if (!success) {
                                                                   resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to update an event in your calendar. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                                               }
                                                               else {
                                                                   NSMutableString *workingText = [[NSMutableString alloc] init];
                                                                   [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new event and updated the subject in your calendar.</h3>"];
                                                                   [workingText appendFormat:@"<p>%@<br></p>", addedEvent.Subject];
                                                                   [workingText appendFormat:@"</br><hr><p>For the code, see createCalendarEvent and updateCalendarEvent in Office365Snippets.m."];

                                                                   resultText = workingText;
                                                               }

                                                               [self updateUIWithResultString:resultText
                                                                                      success:success
                                                                               snippetService:@"Calendar"
                                                                                  snippetName:@"Update Event"];
                                                           }];
                                }];
}

- (void)performDeleteCalendarEvent
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Populate the event details
    NSString *toEmailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *subject = [NSString stringWithFormat:@"New event created on %@", dateString];
    NSString *body = @"Congratulations, you created  this event from the Snippets app!";
    NSDate *start = [NSDate date];
    NSDate *end = [[NSDate date] dateByAddingTimeInterval: 3600];

    MSOutlookEvent *eventToCreate = [snippetLibrary outlookEventWithProperties:@[toEmailAddress]
                                                                       subject:subject
                                                                          body:body
                                                                         start:start
                                                                           end: end
                                     ];

    [snippetLibrary createCalendarEvent:eventToCreate
                                completion:^(MSOutlookEvent *addedEvent, NSError *error) {
                                    if (!addedEvent) {
                                        NSString *errorMessage = [NSString stringWithFormat: @"FAIL<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and delete an event in your Office 365 calendar. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];

                                        [self updateUIWithResultString:errorMessage
                                                               success:NO
                                                        snippetService:@"Calendar"
                                                           snippetName:@"Delete Event"];
                                        return;
                                    }

                                    [snippetLibrary deleteCalendarEvent:addedEvent
                                                           completion:^(BOOL success, NSError *error) {
                                                               NSString *resultText;

                                                               if (!success) {
                                                                   resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and delete an event in your Office 365 calendar. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                                               }
                                                               else {
                                                                   NSMutableString *workingText = [[NSMutableString alloc] init];
                                                                   [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new event and then deleted it from your calendar.</h3>"];
                                                                   [workingText appendFormat:@"<p>%@<br></p>", subject];
                                                                   [workingText appendFormat:@"</br><hr><p>For the code, see createCalendarEvent and deleteCalendarEvent in Office365Snippets.m."];

                                                                   resultText = workingText;
                                                               }

                                                               [self updateUIWithResultString:resultText
                                                                                      success:success
                                                                               snippetService:@"Calendar"
                                                                                  snippetName:@"Delete Event"];
                                                           }];
                                }];
}


- (void)performFetchContacts
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    [snippetLibrary fetchContacts:^(NSArray *contacts, NSError *error) {
        NSString *resultText;
        BOOL success = (contacts.count !=0);

        if (!success) {
            resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to get your contacts from Office 365. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the readme.", [error localizedDescription]];
        }
        else {
            NSMutableString *workingText = [[NSMutableString alloc] init];

            [workingText appendFormat:@"<h2><font color=#6AFB92>SUCCESS!</h2></font><h3>We retrieved the following contacts from Office 365:</h3>"];

            for(MSOutlookContact *contact in contacts) {
                [workingText appendFormat:@"<p>%@<br></p>", contact.DisplayName];
            }

            [workingText appendFormat:@"</br><hr><p>For the code, see fetchContacts in Office365Snippets.m."];

            resultText = [workingText copy];
        }

        [self updateUIWithResultString:resultText
                               success:success
                        snippetService:@"Contacts"
                           snippetName:@"Get Contacts"];
    }];

}

- (void)performCreateContact
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];


    // Populate the contact details
    NSString *emailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *givenName = @"New Contact";
    NSString *surname = [NSString stringWithFormat:@" created on %@", dateString];
    NSString *displayName = [NSString stringWithFormat:@"%@%@%@", givenName, @" ", surname];
    NSString *title = @"Architect";
    NSString *mobilePhone1 = @"5554251212";


    MSOutlookContact *contactToCreate = [snippetLibrary outlookContactWithProperties:@[emailAddress]
                                                                             subject:givenName
                                                                                body:displayName
                                                                             surname:surname
                                                                               title:title
                                                                        mobilePhone1:mobilePhone1
                                     ];

    [snippetLibrary createContact:contactToCreate
                             completion:^(MSOutlookContact *addedContact,  NSError *error) {
                                 NSString *resultText;
                                 BOOL success = (error == nil);

                                 if (!success) {
                                     resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create a contact in Office 365. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                 }
                                 else {
                                     NSMutableString *workingText = [[NSMutableString alloc] init];
                                     [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new contact in Office 365.</h3>"];
                                     [workingText appendFormat:@"<p>%@<br></p>", addedContact.DisplayName];
                                     [workingText appendFormat:@"</br><hr><p>For the code, see createContact in Office365Snippets.m."];

                                     resultText = workingText;
                                 }

                                 [self updateUIWithResultString:resultText
                                                        success:success
                                                 snippetService:@"Contacts"
                                                    snippetName:@"Create Contact"];
                             }];


}

- (void)performUpdateContact
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Populate the contact details
    NSString *emailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *givenName = @"New Contact";
    NSString *surname = [NSString stringWithFormat:@" created on %@", dateString];
    NSString *displayName = [NSString stringWithFormat:@"%@%@%@", givenName, @" ", surname];
    NSString *title = @"Architect";
    NSString *mobilePhone1 = @"5554251212";


    MSOutlookContact *contactToCreate = [snippetLibrary outlookContactWithProperties:@[emailAddress]
                                                                             subject:givenName
                                                                                body:displayName
                                                                             surname:surname
                                                                               title:title
                                                                        mobilePhone1:mobilePhone1
                                         ];



    [snippetLibrary createContact:contactToCreate
                             completion:^(MSOutlookContact *addedContact, NSError *error) {
                                 if (!addedContact) {
                                     NSString *errorMessage = [NSString stringWithFormat: @"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and update a contact in Office 365. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];

                                     [self updateUIWithResultString:errorMessage
                                                            success:NO
                                                     snippetService:@"Contacts"
                                                        snippetName:@"Update Contact"];
                                     return;
                                 }

                                 //Create a date formatter to get the current date and time in the desired format
                                 NSDateFormatter *formatter;
                                 NSString        *dateString;
                                 formatter = [[NSDateFormatter alloc] init];
                                 [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
                                 dateString = [formatter stringFromDate:[NSDate date]];

                                 addedContact.Surname = [addedContact.Surname stringByAppendingFormat:@" & updated at %@", dateString];

                                 [snippetLibrary updateContact:addedContact
                                                          completion:^(MSOutlookContact *updatedContact, NSError *error) {
                                                              BOOL success = (updatedContact != nil);
                                                              NSString *resultText;

                                                              if (!success) {
                                                                  resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to update a contact in Office 365. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                                              }
                                                              else {
                                                                  NSMutableString *workingText = [[NSMutableString alloc] init];
                                                                  [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new contact and updated the surname property.</h3>"];
                                                                  [workingText appendFormat:@"<p>%@<br></p>", updatedContact.DisplayName];
                                                                  [workingText appendFormat:@"</br><hr><p>For the code, see createContact and updateContact in Office365Snippets.m."];

                                                                  resultText = workingText;
                                                              }

                                                              [self updateUIWithResultString:resultText
                                                                                     success:success
                                                                              snippetService:@"Contacts"
                                                                                 snippetName:@"Update Contact"];
                                                          }];
                             }];

}

- (void)performDeleteContact
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Populate the contact details
    NSString *emailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *givenName = @"New Contact";
    NSString *surname = [NSString stringWithFormat:@" created on %@", dateString];
    NSString *displayName = [NSString stringWithFormat:@"%@%@%@", givenName, @" ", surname];
    NSString *title = @"Architect";
    NSString *mobilePhone1 = @"5554251212";


    MSOutlookContact *contactToCreate = [snippetLibrary outlookContactWithProperties:@[emailAddress ]
                                                                             subject:givenName
                                                                                body:displayName
                                                                             surname:surname
                                                                               title:title
                                                                        mobilePhone1:mobilePhone1
                                         ];


    [snippetLibrary createContact:contactToCreate
                             completion:^(MSOutlookContact *addedContact, NSError *error) {
                                 if (!addedContact) {
                                     NSString *errorMessage = [NSString stringWithFormat: @"FAIL<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and delete a contact in Office 365 Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];

                                     [self updateUIWithResultString:errorMessage
                                                            success:NO
                                                     snippetService:@"Contacts"
                                                        snippetName:@"Delete Contact"];
                                     return;
                                 }

                                 [snippetLibrary deleteContact:addedContact
                                                          completion:^(BOOL success, NSError *error) {
                                                              NSString *resultText;

                                                              if (!success) {
                                                                  resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and delete a contact in Office 365. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                                              }
                                                              else {
                                                                  NSMutableString *workingText = [[NSMutableString alloc] init];
                                                                  [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new contact and then deleted it from Office 365.</h3>"];
                                                                  [workingText appendFormat:@"<p>%@<br></p>", displayName];
                                                                  [workingText appendFormat:@"</br><hr><p>For the code, see createContact and deleteContact in Office365Snippets.m."];

                                                                  resultText = workingText;
                                                              }

                                                              [self updateUIWithResultString:resultText
                                                                                     success:success
                                                                              snippetService:@"Contacts"
                                                                                 snippetName:@"Delete Contact"];
                                                          }];
                             }];
}



- (void)performFetchMailMessages
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    [snippetLibrary fetchMailMessages:^(NSArray *messages, NSError *error) {
        NSString *resultText;
        BOOL success = (messages.count != 0);

        if (!success) {
            resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Error: %@</p><hr></br>We were unable to read the messages in your O365 inbox. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the readme.", [error localizedDescription]];
        }
        else {
            NSMutableString *workingText = [[NSMutableString alloc] init];

            [workingText appendFormat:@"<h2><font color=#6AFB92>SUCCESS!</h2></font><h3>We retrieved the following items from your inbox:</h3>"];

            for(MSOutlookMessage *message in messages) {
                [workingText appendFormat:@"<p>%@<br></p>", message.Subject];
            }

            [workingText appendFormat:@"</br><hr><p>For the code, see fetchMailMessages in Office365Snippets.m."];

            resultText = [workingText copy];
        }

        [self updateUIWithResultString:resultText
                               success:success
                        snippetService:@"Mail"
                           snippetName:@"Get messages"];
    }];
}

- (void)performCreateMailMessage
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Create the message that we would like to send
    NSString *toEmailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *subject = [NSString stringWithFormat:@"New mail created on %@", dateString];
    NSString *body = @"Congratulations, you sent this message from the Snippets app!";

    MSOutlookMessage *messageToSend = [snippetLibrary outlookMessageWithProperties:@[toEmailAddress]
                                                                           subject:subject
                                                                              body:body];

    [snippetLibrary sendMailMessage:messageToSend
                         completion:^(BOOL success, NSError *error) {
                             NSString *resultText;
                             success = (error == nil);

                             if (!success) {
                                 resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and send a mail message. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                             }
                             else {
                                 NSMutableString *workingText = [[NSMutableString alloc] init];
                                 [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new mail message and sent it to your inbox.</h3>"];
                                 [workingText appendFormat:@"<p>%@<br></p>", subject];
                                 [workingText appendFormat:@"</br><hr><p>For the code, see createMailMessage in Office365Snippets.m."];

                                 resultText = workingText;
                             }

                             [self updateUIWithResultString:resultText
                                                    success:success
                                             snippetService:@"Mail"
                                                snippetName:@"Create Message"];
                         }];
}

- (void)performUpdateMailMessage
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Create the message that we would like to send
    NSString *toEmailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *subject = [NSString stringWithFormat:@"Sample draft message created at %@", dateString];
    NSString *body = @"Sample message from the Snippets App!";

    MSOutlookMessage *messageToAdd = [snippetLibrary outlookMessageWithProperties:@[toEmailAddress]
                                                                          subject:subject
                                                                             body:body];

    [snippetLibrary createDraftMailMessage:messageToAdd
                                completion:^(MSOutlookMessage *addedMessage, NSError *error) {
                                    if (!addedMessage) {
                                        NSString *errorMessage = [NSString stringWithFormat: @"FAIL<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and update a mail message in your O365 mail Drafts folder. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];

                                        [self updateUIWithResultString:errorMessage
                                                               success:NO
                                                        snippetService:@"Mail"
                                                           snippetName:@"Update Message"];
                                        return;
                                    }

                                    //Create a date formatter to get the current date and time in the desired format
                                    NSDateFormatter *formatter;
                                    NSString        *dateString;
                                    formatter = [[NSDateFormatter alloc] init];
                                    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
                                    dateString = [formatter stringFromDate:[NSDate date]];

                                    addedMessage.Subject = [addedMessage.Subject stringByAppendingFormat:@" & updated at %@", dateString];

                                    [snippetLibrary updateMailMessage:addedMessage
                                                           completion:^(MSOutlookMessage *updatedMessage, NSError *error) {
                                                               BOOL success = (updatedMessage != nil);
                                                               NSString *resultText;

                                                               if (!success) {
                                                                   resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to update an email. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                                               }
                                                               else {
                                                                   NSMutableString *workingText = [[NSMutableString alloc] init];
                                                                   [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new mail message in your drafts folder and updated its subject.</h3>"];
                                                                   [workingText appendFormat:@"<p>%@<br></p>", updatedMessage.Subject];
                                                                   [workingText appendFormat:@"</br><hr><p>For the code, see createDraftMessage and updateMailMessage in Office365Snippets.m."];

                                                                   resultText = workingText;
                                                               }

                                                               [self updateUIWithResultString:resultText
                                                                                      success:success
                                                                               snippetService:@"Mail"
                                                                                  snippetName:@"Update Message"];
                                                           }];
                                }];
}

- (void)performDeleteMailMessage
{
    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    //Create a date formatter to get the current date and time in the desired format
    NSDateFormatter *formatter;
    NSString        *dateString;
    formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyy-dd-MM 'at' HH:mm"];
    dateString = [formatter stringFromDate:[NSDate date]];

    // Create the message that we would like to send
    NSString *toEmailAddress = [[NSUserDefaults standardUserDefaults] objectForKey:@"LogInUser"];
    NSString *subject = [NSString stringWithFormat:@"Sample draft message created at %@", dateString];
    NSString *body = @"Sample message from the Snippets App!";

    MSOutlookMessage *messageToAdd = [snippetLibrary outlookMessageWithProperties:@[toEmailAddress]
                                                                          subject:subject
                                                                             body:body];

    [snippetLibrary createDraftMailMessage:messageToAdd
                                completion:^(MSOutlookMessage *addedMessage, NSError *error) {
                                    if (!addedMessage) {
                                        NSString *errorMessage = [NSString stringWithFormat: @"FAIL<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and delete a mail message in your O365 mail Drafts folder. Please ensure your client ID and redirect URI have been set in the Authentication Controller, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];

                                        [self updateUIWithResultString:errorMessage
                                                               success:NO
                                                        snippetService:@"Mail"
                                                           snippetName:@"Delete Message"];
                                        return;
                                    }

                                    [snippetLibrary deleteMailMessage:addedMessage
                                                           completion:^(BOOL success, NSError *error) {
                                                               NSString *resultText;

                                                               if (!success) {
                                                                   resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Exception: %@</p><hr></br>We were unable to create and delete a mail message. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the read me.", [error localizedDescription]];
                                                               }
                                                               else {
                                                                   NSMutableString *workingText = [[NSMutableString alloc] init];
                                                                   [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We created a new mail message in your drafts folder and then deleted it.</h3>"];
                                                                   [workingText appendFormat:@"<p>%@<br></p>", subject];
                                                                   [workingText appendFormat:@"</br><hr><p>For the code, see createDraftMailMessage and deleteMailMessage in Office365Snippets.m."];

                                                                   resultText = workingText;
                                                               }

                                                               [self updateUIWithResultString:resultText
                                                                                      success:success
                                                                               snippetService:@"Mail"
                                                                                  snippetName:@"Delete Message"];
                                                           }];
                                }];
}


- (void)performFetchFiles
{

    NSLog(@"Action: %@", NSStringFromSelector(_cmd));

    Office365Snippets *snippetLibrary = [[Office365Snippets alloc] init];

    [self.spinner startAnimating];

    [snippetLibrary fetchFiles:^(NSArray *files, NSError *error) {
    NSString *resultText;
    BOOL success = (files.count != 0);

        if (!success) {
            resultText = [NSString stringWithFormat:@"<h2><font color=#DC381F>FAIL: </font></h2><p>Oops! The following exception was raised.</p><p>Error: %@</p><hr></br>We were unable to get the files in OneDrive for Business. Please ensure your client ID and redirect URI have been set in the Authentication Manager, and all of the service permissions have been correctly configured in your Azure app registration. Both of these procedures are covered in depth in the readme.", [error localizedDescription]];
        }
        else {
            NSMutableString *workingText = [[NSMutableString alloc] init];

            [workingText appendFormat:@"<h2><font color=green>SUCCESS!</h2></font><h3>We retrieved the following files from OneDrive for Business:</h3>"];

            for(MSSharePointItem *file in files)
                {
                    if ([file.type isEqual: @"Folder"]){
                    [workingText appendFormat:@"<p>Folder: %@<br></p>", file.name];
                }
                else
                [workingText appendFormat:@"<p>File: %@<br></p>", file.name];
                }


            [workingText appendFormat:@"</br><hr><p>For the code, see fetchFiles in Office365Snippets.m."];

            resultText = [workingText copy];


        }

        [self updateUIWithResultString:resultText
                               success:success
                        snippetService:@"Files"
                           snippetName:@"Get files"];

        }];

}


@end

// *********************************************************
//
// O365-iOS-Snippets, https://github.com/OfficeDev/O365-iOS-Snippets
//
// Copyright (c) Microsoft Corporation
// All rights reserved.
//
// MIT License:
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// *********************************************************
