/*
 * Copyright (c) Microsoft. All rights reserved. Licensed under the MIT license. See full license at the bottom of this file.
 */

#import "Office365Snippets.h"
#import "AuthenticationManager.h"
#import "Office365ClientFetcher.h"

// Office 365, Outlook Services, and SharePoint dependencies
#import <office365_odata_base/office365_odata_base.h>
#import <office365_exchange_sdk/office365_exchange_sdk.h>
#import <office365_files_sdk/office365_files_sdk.h>


@interface Office365Snippets ()
@property (strong, nonatomic) Office365ClientFetcher *o365ClientFetcher;
@end




@implementation Office365Snippets


#pragma mark - Properties
//Initialze an Office 365 client fetcher
- (Office365ClientFetcher *)o365ClientFetcher
{
    if (!_o365ClientFetcher) {
        _o365ClientFetcher = [[Office365ClientFetcher alloc] init];
    }
    
    return _o365ClientFetcher;
}



#pragma mark - Helper Methods

//These helpers are used to populate new Outlook item objects and
//are used while creating new items on the server

//Populates a new email message item
- (MSOutlookMessage *)outlookMessageWithProperties:(NSArray *)recipients
                                           subject:(NSString *)subject
                                              body:(NSString *)body
{
    MSOutlookMessage *message = [[MSOutlookMessage alloc] init];
    
    message.Subject = subject;
    
    message.Body = [[MSOutlookItemBody alloc] init];
    message.Body.Content = body;
    message.Body.ContentType = Text;
    
    NSMutableArray *toRecipients = [[NSMutableArray alloc] init];
    
    for (NSString *emailAddress in recipients) {
        MSOutlookRecipient *recipient = [[MSOutlookRecipient alloc] init];
        
        recipient.EmailAddress = [[MSOutlookEmailAddress alloc] init];
        recipient.EmailAddress.Address = emailAddress;
        
        [toRecipients addObject:recipient];
    }
    
    message.ToRecipients = [toRecipients copy];
    
    return message;
}

//Populates a new calendar event item
- (MSOutlookEvent *)outlookEventWithProperties:(NSArray *)attendees
                                       subject:(NSString *)subject
                                          body:(NSString *)body
                                         start: (NSDate *)start
                                           end: (NSDate *)end
{

    MSOutlookEvent *event = [[MSOutlookEvent alloc] init];
    
    event.Subject = subject;
    [event setStart:start];
    [event setEnd:end];
    [event setRecurrence:SingleInstance];
    
    
    
    event.Body = [[MSOutlookItemBody alloc] init];
    event.Body.Content = body;
    event.Body.ContentType = Text;
    
    NSMutableArray *toAttendees = [[NSMutableArray alloc] init];
    for (NSString *emailAddress in attendees) {
        MSOutlookAttendee *attendee = [[MSOutlookAttendee alloc] init];
        
        attendee.EmailAddress = [[MSOutlookEmailAddress alloc] init];
        attendee.EmailAddress.Address = emailAddress;
        
        [toAttendees addObject:attendee];
    }
    
    event.Attendees = [toAttendees copy];
    
    return event;
}

////Populates a new contact
- (MSOutlookContact *)outlookContactWithProperties:(NSArray *)emailAddresses
                                           subject:(NSString *)givenName
                                              body:(NSString *)displayName
                                           surname:(NSString *)surname
                                             title: (NSString *)title
                                      mobilePhone1: (NSString *)mobilePhone1
{
    
    MSOutlookContact *contact = [[MSOutlookContact alloc] init];
    
    contact.GivenName = givenName;
    contact.Surname = surname;
    contact.DisplayName = displayName;
    
    contact.Title = title;
    contact.MobilePhone1 = mobilePhone1;
    
    
    NSMutableArray<MSOutlookEmailAddress> *contactEmailAddresses = (NSMutableArray<MSOutlookEmailAddress>*)
    [[NSMutableArray alloc] init];
    for (NSString *emailAddress in emailAddresses) {
        
        MSOutlookEmailAddress *email = [[MSOutlookEmailAddress alloc]init];
        [email setAddress:emailAddress];
        
        [contactEmailAddresses addObject:email];
        
    }
    
    
    [contact setEmailAddresses:contactEmailAddresses];
    
    return contact;
}


#pragma mark - Mail snippets
//Get the 10 most recent email messages in the user's inbox
- (void)fetchMailMessages:(void (^)(NSArray *messages, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];

    // Get the MSOutlookClient. This object contains access tokens and methods to call the service.
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        // Retrieve mail messages from O365 and pass the status to the callback. Uses a default page size of 10.
        // This results in a call to the service.
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookMessageCollectionFetcher *messageCollectionFetcher = [userFetcher getMessages];

        NSURLSessionTask *task = [messageCollectionFetcher read:^(NSArray *messages, MSODataException *error) {
            completion(messages, error);
        }];

        [task resume];
    }];
}

//Sends a new email message to the user
- (void)sendMailMessage:(MSOutlookMessage *)message
             completion:(void (^)(BOOL success, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];

    // Get the MSOutlookClient. This object contains access tokens and methods to call the service.
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookUserOperations *operations = [userFetcher getOperations];

        // The returnValue is the HTTP status code
        NSURLSessionTask *task = [operations sendMail:message :YES :^(int returnValue, MSODataException *error) {
            BOOL success = (returnValue == 0);

            completion(success, error);
        }];
        
        [task resume];
    }];
}

//Creates a new email message in the user's Drafts folder
//Does not send the email
- (void)createDraftMailMessage:(MSOutlookMessage *)message
                    completion:(void (^)(MSOutlookMessage *addedMessage, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];

    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookMessageCollectionFetcher *messageCollectionFetcher = [userFetcher getMessages];

        NSURLSessionDataTask *task = [messageCollectionFetcher addMessage:message
                                                             withCallback:^(MSOutlookMessage *addedMessage, MSODataException *error) {
                                                                 completion(addedMessage, error);
                                                             }];

        [task resume];
    }];
}

//Updates an email message on the server
- (void)updateMailMessage:(MSOutlookMessage *)message
               completion:(void (^)(MSOutlookMessage *updatedMessage, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];

    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookMessageCollectionFetcher *messageCollectionFetcher = [userFetcher getMessages];
        MSOutlookMessageFetcher *messageFetcher = [messageCollectionFetcher getById:message.Id];

        NSURLSessionDataTask *task = [messageFetcher updateMessage:message
                                                      withCallback:^(MSOutlookMessage *updatedMessage, MSODataException *error) {
                                                          completion(updatedMessage, error);
                                                      }];

        [task resume];
    }];
}

//Deletes an email message from the server
- (void)deleteMailMessage:(MSOutlookMessage *)message
               completion:(void (^)(BOOL, NSError *))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];

    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookMessageCollectionFetcher *messageCollectionFetcher = [userFetcher getMessages];
        MSOutlookMessageFetcher *messageFetcher = [messageCollectionFetcher getById:message.Id];

        NSURLSessionDataTask *task = [messageFetcher deleteMessage:^(int status, MSODataException *error) {
            BOOL success = (error == nil);

            completion(success, error);
        }];

        [task resume];
    }];

}



#pragma mark - Calendar

//Gets the 10 most recent calendar events from the user's calendar
- (void)fetchCalendarEvents:(void (^)(NSArray *events, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    // Get the MSOutlookClient. This object contains access tokens and methods to call the service.
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        // Retrieve mail messages from O365 and pass the status to the callback. Uses a default page size of 10.
        // This results in a call to the service.
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookEventCollectionFetcher *eventFetcher = [userFetcher getEvents];
        
        NSURLSessionTask *task = [eventFetcher read:^(NSArray *events, MSODataException *error) {
            completion(events, error);
        }];
        
        [task resume];
    }];
}

//Creates a new event in the user's calendar
- (void)createCalendarEvent:(MSOutlookEvent *)event
                    completion:(void (^)(MSOutlookEvent *addedEvent, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookEventCollectionFetcher *eventCollectionFetcher = [userFetcher getEvents];
        
        NSURLSessionDataTask *task = [eventCollectionFetcher addEvent:event
                                                             withCallback:^(MSOutlookEvent *addedEvent, MSODataException *error) {
                                                                 completion(addedEvent, error);
                                                             }];
        
        [task resume];
    }];
}

//Updates an event in the user's calendar
- (void)updateCalendarEvent:(MSOutlookEvent *)event
               completion:(void (^)(MSOutlookEvent *updatedEvent, NSError *error))completion
{

    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookEventCollectionFetcher *eventCollectionFetcher = [userFetcher getEvents];
        MSOutlookEventFetcher *eventFetcher = [eventCollectionFetcher getById:event.Id];
        
        NSURLSessionDataTask *task = [eventFetcher updateEvent:event
                                                      withCallback:^(MSOutlookEvent *updatedEvent, MSODataException *error) {
                                                          completion(updatedEvent, error);
                                                      }];
        
        [task resume];
    }];
}

//Deletes an event from the user's calendar
- (void)deleteCalendarEvent:(MSOutlookEvent *)event
               completion:(void (^)(BOOL, NSError *))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookEventCollectionFetcher *eventCollectionFetcher = [userFetcher getEvents];
        MSOutlookEventFetcher *eventFetcher = [eventCollectionFetcher getById:event.Id];
        
        NSURLSessionDataTask *task = [eventFetcher deleteEvent:^(int status, MSODataException *error) {
            BOOL success = (error == nil);
            
            completion(success, error);
        }];
        
        [task resume];
    }];
    
}

#pragma mark - Contacts

//Gets the 10 most recently added user's contacts from Office 365
- (void)fetchContacts:(void (^)(NSArray *contacts, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    // Get the MSOutlookClient. This object contains access tokens and methods to call the service.
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        // Retrieve mail messages from O365 and pass the status to the callback. Uses a default page size of 10.
        // This results in a call to the service.
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookContactCollectionFetcher *contactFetcher = [userFetcher getContacts];
        
        NSURLSessionTask *task = [contactFetcher read:^(NSArray *contacts, MSODataException *error) {
            completion(contacts, error);
        }];
        
        [task resume];
    }];
}

//Creates a new contact for the user
- (void)createContact:(MSOutlookContact *)contact
                 completion:(void (^)(MSOutlookContact *addedContact, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookContactCollectionFetcher *contactCollectionFetcher = [userFetcher getContacts];
        
        NSURLSessionDataTask *task = [contactCollectionFetcher addContact:contact
                                                         withCallback:^(MSOutlookContact *addedContact, MSODataException *error) {
                                                             completion(addedContact, error);
                                                         }];
        
        [task resume];
    }];
}

//Updates a contact in Office 365
- (void)updateContact:(MSOutlookContact *)contact
                 completion:(void (^)(MSOutlookContact *updatedContact, NSError *error))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookContactCollectionFetcher *contactCollectionFetcher = [userFetcher getContacts];
        MSOutlookContactFetcher *contactFetcher = [contactCollectionFetcher getById:contact.Id];
        
        NSURLSessionDataTask *task = [contactFetcher updateContact:contact
                                                  withCallback:^(MSOutlookContact *updatedContact, MSODataException *error) {
                                                      completion(updatedContact, error);
                                                  }];
        
        [task resume];
    }];
}

//Deletes a contact from Office 365
- (void)deleteContact:(MSOutlookContact *)contact
                 completion:(void (^)(BOOL, NSError *))completion
{
    Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
    
    [clientFetcher fetchOutlookClient:^(MSOutlookClient *client) {
        MSOutlookUserFetcher *userFetcher = [client getMe];
        MSOutlookContactCollectionFetcher *contactCollectionFetcher = [userFetcher getContacts];
        MSOutlookContactFetcher *contactFetcher = [contactCollectionFetcher getById:contact.Id];
        
        NSURLSessionDataTask *task = [contactFetcher deleteContact:^(int status, MSODataException *error) {
            BOOL success = (error == nil);
            
            completion(success, error);
        }];
        
        [task resume];
    }];
    
}



#pragma mark - OneDrive Files

//Gets 10 files or folders from the user's OneDrive for Business folder
- (void)fetchFiles:(void (^)(NSArray *files, NSError *error))completion
    {
        Office365ClientFetcher *clientFetcher = [[Office365ClientFetcher alloc] init];
        
        //Get the SharePoint client. This object contains access tokens and methods to call the service.
        [clientFetcher fetchSharePointClient:^(MSSharePointClient *sharePointClient) {

            // This results in a call to the service.
            
            MSSharePointItemCollectionFetcher *fileFetcher = [sharePointClient getfiles];
            // Retrieve files from O365 and pass the status to the callback. Uses a default page size of 10.
            NSURLSessionTask *task = [fileFetcher read:^(NSArray *files, MSODataException *error) {
                completion(files, error);
            }];
                    
            [task resume];
            }];
        
    }




#pragma mark - Discovery
-(void) fetchDiscoveryServiceEndpoints


{
    // Connect to the service by discovering the service endpoints and authorizing
    // the application to access the user's email. This will store the user's
    // service URLs in a property list to be accessed when calls are made to the
    // service. This results in two calls: one to authenticate, and one to get the
    // URLs. ADAL will cache the access and refresh tokens so you won't need to
    // provide credentials unless you sign out.
    
    // Get the discovery client. First time this is ran you will be prompted
    // to provide your credentials which will authenticate you with the service.
    // The application will get an access token in the response.
    [self.o365ClientFetcher   fetchDiscoveryClient:^(MSDiscoveryClient *discoveryClient) {
        MSDiscoveryServiceInfoCollectionFetcher *servicesInfoFetcher = [discoveryClient getservices];
        
        // Call the Discovery Service and get back an array of service endpoint information.
        NSURLSessionDataTask *servicesTask = [servicesInfoFetcher read:^(NSArray *serviceEndpoints, MSODataException *error) {
            if (serviceEndpoints) {
                // Here is where we cache the service URLs returned by the Discovery Service. You may not
                // need to call the Discovery Service again until either this cache is removed, or you
                // get an error that indicates that the endpoint is no longer valid.
                
                
                NSUserDefaults *userDefaults = [[NSUserDefaults alloc]init];
                
                for(MSDiscoveryServiceInfo *service in serviceEndpoints) {
                    [userDefaults setObject:service.serviceEndpointUri forKey:service.capability];
                    [userDefaults setObject:service.serviceResourceId forKey:[service.capability stringByAppendingString:@"ResourceID"]];
                }

                
                [userDefaults synchronize];
                
  
            }
            else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSLog(@"Error in the authentication: %@", error);
                    
                    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                                    message:@"Authentication failed. This may be because the Internet connection is offline  or perhaps the credentials are incorrect. Check the log for errors and try again."
                                                                   delegate:nil
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
                    [alert show];
                });
            }
        }];
        
        [servicesTask resume];
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
