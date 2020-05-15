PowerShell script that utilizes the Tenable.SC API to add an email alert when a ticket gets assigned to a specific user.

USAGE

The script requires four arguments:

  -userName: The Tenable.SC user name of the user you want to add the email alert for.
  
  -accessKey: Your Tenable.SC API access key
  
  -secretKey: Your Tenable.SC API secret key
  
  -baseURL: The base URL for your installation of Tenable.SC
  
EXAMPLE

Add-TscTicketAssigneeEmail.ps1 -userName jason -accessKey 1234abcd5678 -secretKey 8765dcba4321 -baseURL https://tenable.example.com
