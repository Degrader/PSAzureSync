# PSAzureSync
Module containing functions for comparing and synchronizing local Active Directory group membership to Azure groups (if you don't have Azure AD Premium)

I have modified this module to require a non-standard Active Directory attribute, as this increases speed and accuracy of the script tremendously. I make use of an attribute called azureOID to store each users ObjectID in the on-prem AD.
