# Exceptions and Errors Catalog

This catalog lists user-facing exception, warning, and confirmation dialog texts found across Mandala Project's pages.

## Summary by Page

### AuthScreen.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `You must agree to the Terms of Service & EULA to proceed` | Action confirmation or status message. |
| SnackBar | `Account created! Please check your email for the 6-digit verification code.` | Action confirmation or status message. |
| SnackBar | `e.message` | Action confirmation or status message. |
| SnackBar | `e.toString(` | Action confirmation or status message. |
| SnackBar | `Please enter the verification code` | Action confirmation or status message. |
| SnackBar | `Verification successful! Logging you in...` | Action success message. |
| SnackBar | `e.message` | Action confirmation or status message. |
| SnackBar | `e.toString(` | Action confirmation or status message. |
| SnackBar | `Google Sign-In was cancelled` | Action confirmation or status message. |
| SnackBar | `Failed to complete Google Sign In: $e` | API or Database exception (e.g. *Failed to complete Google Sign In: Connection refused*). |
| SnackBar | `Apple Sign-In was cancelled` | Action confirmation or status message. |
| SnackBar | `'Apple Sign-In failed: ${errorStr.replaceAll("Exception: "` | API or Database exception (e.g. *'Apple Sign-In failed: ${errorStr.replaceAll("Exception: "*). |
| SnackBar | `Please enter your email address` | Action confirmation or status message. |
| SnackBar | `Recovery code sent! Please check your email.` | Action confirmation or status message. |
| SnackBar | `e.message` | Action confirmation or status message. |
| SnackBar | `e.toString(` | Action confirmation or status message. |
| SnackBar | `Please enter the recovery code` | Action confirmation or status message. |
| SnackBar | `Code verified! Redirecting to reset password...` | Action confirmation or status message. |
| SnackBar | `e.message` | Action confirmation or status message. |
| SnackBar | `e.toString(` | Action confirmation or status message. |
| SnackBar | `Could not open link: $urlString` | Action confirmation or status message. |
| SnackBar | `Error opening link: $e` | API or Database exception (e.g. *Error opening link: Connection refused*). |
| Text Label | `Failed to complete Google Sign In: $e` | API or Database exception (e.g. *Failed to complete Google Sign In: Connection refused*). |
| Text Label | `Error opening link: $e` | API or Database exception (e.g. *Error opening link: Connection refused*). |

### ConnectionProfilePage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Copied $label to clipboard!` | Action confirmation or status message. |
| SnackBar | `Copied link to clipboard!` | Action confirmation or status message. |
| SnackBar | `"Sharing settings updated to ${accessType.toUpperCase(` | Action confirmation or status message. |
| SnackBar | `User unblocked successfully` | Confirmation that a user has been blocked. |
| SnackBar | `Error unblocking user: $e` | API or Database exception (e.g. *Error unblocking user: Connection refused*). |
| SnackBar | `User blocked` | Confirmation that a user has been blocked. |
| SnackBar | `Error blocking user: $e` | API or Database exception (e.g. *Error blocking user: Connection refused*). |
| SnackBar | `Connection and chat history deleted` | Action confirmation or status message. |
| SnackBar | `Error deleting connection: $e` | API or Database exception (e.g. *Error deleting connection: Connection refused*). |
| SnackBar | `Connection deleted and contact reported.` | Action confirmation or status message. |
| SnackBar | `Failed to report user: $e` | API or Database exception (e.g. *Failed to report user: Connection refused*). |
| Dialog Title | `Manage Connection` | Action confirmation or status message. |
| Dialog Title | `Report & Disconnect $name` | Action confirmation or status message. |
| Text Label | `Error unblocking user: $e` | API or Database exception (e.g. *Error unblocking user: Connection refused*). |
| Text Label | `Error blocking user: $e` | API or Database exception (e.g. *Error blocking user: Connection refused*). |
| Text Label | `Error deleting connection: $e` | API or Database exception (e.g. *Error deleting connection: Connection refused*). |
| Text Label | `Failed to report user: $e` | API or Database exception (e.g. *Failed to report user: Connection refused*). |

### DirectMessagesHubPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `User unblocked` | Confirmation that a user has been blocked. |
| SnackBar | `User blocked` | Confirmation that a user has been blocked. |
| SnackBar | `Connection removed` | Action confirmation or status message. |
| SnackBar | `Connection deleted and contact reported.` | Action confirmation or status message. |
| SnackBar | `Failed to report user: $e` | API or Database exception (e.g. *Failed to report user: Connection refused*). |
| SnackBar | `Error: ${error.message}` | API or Database exception (e.g. *Error: ${error.message}*). |
| SnackBar | `Successfully joined Mafia!` | Action success message. |
| SnackBar | `Failed to join: $e` | API or Database exception (e.g. *Failed to join: Connection refused*). |
| SnackBar | `Mafia \"$tribeName\" deleted successfully.` | Action success message. |
| SnackBar | `Error deleting Mafia: $e` | API or Database exception (e.g. *Error deleting Mafia: Connection refused*). |
| Dialog Title | `Manage Connection` | Action confirmation or status message. |
| Dialog Title | `Report & Disconnect $name` | Action confirmation or status message. |
| Dialog Title | `Create a Mafia` | Action confirmation or status message. |
| Text Label | `Failed to report user: $e` | API or Database exception (e.g. *Failed to report user: Connection refused*). |
| Text Label | `Error: ${error.message}` | API or Database exception (e.g. *Error: ${error.message}*). |
| Text Label | `Failed to join: $e` | API or Database exception (e.g. *Failed to join: Connection refused*). |
| Text Label | `Error deleting Mafia: $e` | API or Database exception (e.g. *Error deleting Mafia: Connection refused*). |

### IndividualChatPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Contact unblocked successfully` | Confirmation that a user has been blocked. |
| SnackBar | `"Thank you` | Action confirmation or status message. |
| SnackBar | `Failed to report message: $e` | API or Database exception (e.g. *Failed to report message: Connection refused*). |
| Dialog Title | `Report Message` | Action confirmation or status message. |
| Dialog Title | `Delete Message?` | Action confirmation or status message. |
| Text Label | `Failed to report message: $e` | API or Database exception (e.g. *Failed to report message: Connection refused*). |

### NotificationPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Error: $err` | API or Database exception (e.g. *Error: Connection refusedrr*). |
| SnackBar | `Action failed: $e` | API or Database exception (e.g. *Action failed: Connection refused*). |
| SnackBar | `Decline failed: $e` | API or Database exception (e.g. *Decline failed: Connection refused*). |
| SnackBar | `Introduction request approved and sent!` | Action confirmation or status message. |
| SnackBar | `Error: $err` | API or Database exception (e.g. *Error: Connection refusedrr*). |
| SnackBar | `Error: $err` | API or Database exception (e.g. *Error: Connection refusedrr*). |
| Text Label | `Error: $err` | API or Database exception (e.g. *Error: Connection refusedrr*). |

### OtherProfilesPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `User unblocked successfully` | Confirmation that a user has been blocked. |
| SnackBar | `Error unblocking user: $e` | API or Database exception (e.g. *Error unblocking user: Connection refused*). |
| SnackBar | `User blocked` | Confirmation that a user has been blocked. |
| SnackBar | `Error blocking user: $e` | API or Database exception (e.g. *Error blocking user: Connection refused*). |
| SnackBar | `Connection and chat history deleted` | Action confirmation or status message. |
| SnackBar | `Error deleting connection: $e` | API or Database exception (e.g. *Error deleting connection: Connection refused*). |
| SnackBar | `Connection deleted and contact reported.` | Action confirmation or status message. |
| SnackBar | `Failed to report user: $e` | API or Database exception (e.g. *Failed to report user: Connection refused*). |
| Dialog Title | `Manage Connection` | Action confirmation or status message. |
| Dialog Title | `Report & Disconnect $name` | Action confirmation or status message. |
| Text Label | `Error unblocking user: $e` | API or Database exception (e.g. *Error unblocking user: Connection refused*). |
| Text Label | `Error blocking user: $e` | API or Database exception (e.g. *Error blocking user: Connection refused*). |
| Text Label | `Error deleting connection: $e` | API or Database exception (e.g. *Error deleting connection: Connection refused*). |
| Text Label | `Failed to report user: $e` | API or Database exception (e.g. *Failed to report user: Connection refused*). |

### PlanDetailPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Meeting link copied` | Action confirmation or status message. |
| Dialog Title | `Delete Plan` | Action confirmation or status message. |

### ProfilePage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Error generating VIP code: $e` | API or Database exception (e.g. *Error generating VIP code: Connection refused*). |
| Text Label | `Error generating VIP code: $e` | API or Database exception (e.g. *Error generating VIP code: Connection refused*). |

### QrCodeScanner.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Joined tribe successfully!` | Action success message. |
| SnackBar | `Failed to join tribe: $e` | API or Database exception (e.g. *Failed to join tribe: Connection refused*). |
| SnackBar | `Profile data not found` | Action confirmation or status message. |
| SnackBar | `Invalid QR Code` | Action confirmation or status message. |
| SnackBar | `No Permission` | Authorization/permission check failed. |
| SnackBar | `Please set up your profile first` | Action confirmation or status message. |
| SnackBar | `Invalid scanned profile data` | Action confirmation or status message. |
| SnackBar | `Error saving connection: $e` | API or Database exception (e.g. *Error saving connection: Connection refused*). |
| Dialog Title | `Profile Preview` | Action confirmation or status message. |
| Text Label | `Failed to join tribe: $e` | API or Database exception (e.g. *Failed to join tribe: Connection refused*). |
| Text Label | `Error saving connection: $e` | API or Database exception (e.g. *Error saving connection: Connection refused*). |

### QrDisplayPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `QR code saved at: $filePath` | Action confirmation or status message. |
| SnackBar | `Failed to access the Downloads folder.` | API or Database exception (e.g. *Failed to access the Downloads folder.*). |
| Text Label | `Failed to access the Downloads folder.` | API or Database exception (e.g. *Failed to access the Downloads folder.*). |

### ResetPasswordScreen.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Password updated successfully! Please sign in with your new password.` | Action success message. |
| SnackBar | `e.message` | Action confirmation or status message. |
| SnackBar | `e.toString(` | Action confirmation or status message. |

### SettingsPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Signed out successfully` | Action success message. |
| SnackBar | `Account deleted successfully` | Action success message. |
| SnackBar | `Error deleting account: $e` | API or Database exception (e.g. *Error deleting account: Connection refused*). |
| Dialog Title | `Sign Out` | Action confirmation or status message. |
| Dialog Title | `Delete Account` | Action confirmation or status message. |
| Dialog Title | `Final Confirmation` | Action confirmation or status message. |
| Text Label | `Error deleting account: $e` | API or Database exception (e.g. *Error deleting account: Connection refused*). |

### Tribe/TribeChatPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `You do not have permission to post messages.` | Authorization/permission check failed. |
| SnackBar | `Failed to send message: $e` | API or Database exception (e.g. *Failed to send message: Connection refused*). |
| SnackBar | `"Thank you` | Action confirmation or status message. |
| SnackBar | `Failed to report message: $e` | API or Database exception (e.g. *Failed to report message: Connection refused*). |
| SnackBar | `$senderName has been blocked.` | Confirmation that a user has been blocked. |
| SnackBar | `Failed to block user: $e` | API or Database exception (e.g. *Failed to block user: Connection refused*). |
| Dialog Title | `Report Message` | Action confirmation or status message. |
| Dialog Title | `Block $senderName?` | Action confirmation or status message. |
| Text Label | `Failed to send message: $e` | API or Database exception (e.g. *Failed to send message: Connection refused*). |
| Text Label | `Failed to report message: $e` | API or Database exception (e.g. *Failed to report message: Connection refused*). |
| Text Label | `Failed to block user: $e` | API or Database exception (e.g. *Failed to block user: Connection refused*). |

### Tribe/TribeCreatePage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Mafia image uploaded successfully!` | Action success message. |
| SnackBar | `Upload failed: $e` | API or Database exception (e.g. *Upload failed: Connection refused*). |
| SnackBar | `Mafia name cannot be empty.` | Validation error when a required text field is left empty. |
| SnackBar | `Error creating Mafia: $e` | API or Database exception (e.g. *Error creating Mafia: Connection refused*). |
| Text Label | `Error creating Mafia: $e` | API or Database exception (e.g. *Error creating Mafia: Connection refused*). |

### Tribe/TribeDetailsPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Invitation sent successfully!` | Action success message. |
| SnackBar | `Failed to invite: $e` | API or Database exception (e.g. *Failed to invite: Connection refused*). |
| SnackBar | `Request Approved` | Action confirmation or status message. |
| SnackBar | `Failed to approve: $e` | API or Database exception (e.g. *Failed to approve: Connection refused*). |
| SnackBar | `Failed to decline: $e` | API or Database exception (e.g. *Failed to decline: Connection refused*). |
| SnackBar | `Failed to change role: $e` | API or Database exception (e.g. *Failed to change role: Connection refused*). |
| SnackBar | `Invite code copied to clipboard!` | Action confirmation or status message. |
| SnackBar | `Failed to leave: $e` | API or Database exception (e.g. *Failed to leave: Connection refused*). |
| SnackBar | `Failed to delete: $e` | API or Database exception (e.g. *Failed to delete: Connection refused*). |
| SnackBar | `Mafia name cannot be empty.` | Validation error when a required text field is left empty. |
| SnackBar | `Error updating mafia: $e` | API or Database exception (e.g. *Error updating mafia: Connection refused*). |
| SnackBar | `Failed to remove member: $e` | API or Database exception (e.g. *Failed to remove member: Connection refused*). |
| Dialog Title | `displayTitle` | Action confirmation or status message. |
| Dialog Title | `role['name'] ?? ''` | Action confirmation or status message. |
| Dialog Title | `_isEditing ? "Edit Mafia" : "Mafia Details"` | Action confirmation or status message. |
| Dialog Title | `Remove Member?` | Action confirmation or status message. |
| Text Label | `Failed to invite: $e` | API or Database exception (e.g. *Failed to invite: Connection refused*). |
| Text Label | `Failed to approve: $e` | API or Database exception (e.g. *Failed to approve: Connection refused*). |
| Text Label | `Failed to decline: $e` | API or Database exception (e.g. *Failed to decline: Connection refused*). |
| Text Label | `Failed to change role: $e` | API or Database exception (e.g. *Failed to change role: Connection refused*). |
| Text Label | `Failed to leave: $e` | API or Database exception (e.g. *Failed to leave: Connection refused*). |
| Text Label | `Failed to delete: $e` | API or Database exception (e.g. *Failed to delete: Connection refused*). |
| Text Label | `Error updating mafia: $e` | API or Database exception (e.g. *Error updating mafia: Connection refused*). |
| Text Label | `Failed to remove member: $e` | API or Database exception (e.g. *Failed to remove member: Connection refused*). |

### Tribe/TribeRoleBuilderPage.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Failed to save: $e` | API or Database exception (e.g. *Failed to save: Connection refused*). |
| SnackBar | `Failed to delete role: $e` | API or Database exception (e.g. *Failed to delete role: Connection refused*). |
| Dialog Title | `Manage Members` | Action confirmation or status message. |
| Text Label | `Failed to create role: $e` | API or Database exception (e.g. *Failed to create role: Connection refused*). |
| Text Label | `Failed to save: $e` | API or Database exception (e.g. *Failed to save: Connection refused*). |
| Text Label | `Failed to delete role: $e` | API or Database exception (e.g. *Failed to delete role: Connection refused*). |

### crop_image_page.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Error loading image: $e` | API or Database exception (e.g. *Error loading image: Connection refused*). |
| SnackBar | `Cropping failed: $e` | API or Database exception (e.g. *Cropping failed: Connection refused*). |
| Text Label | `Error loading image: $e` | API or Database exception (e.g. *Error loading image: Connection refused*). |

### edit_profile_page.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Error saving profile: $e` | API or Database exception (e.g. *Error saving profile: Connection refused*). |
| SnackBar | `Profile photo updated and saved!` | Action confirmation or status message. |
| Dialog Title | `Discard changes?` | Action confirmation or status message. |
| Dialog Title | `Edit $title` | Action confirmation or status message. |
| Dialog Title | `existingLink == null ? "Add Custom Link" : "Edit Custom Link"` | Action confirmation or status message. |
| Text Label | `Error saving profile: $e` | API or Database exception (e.g. *Error saving profile: Connection refused*). |

### yet_to_be_built_profile_page.dart

| Type | Exact Text / Expression | Context / Example |
|------|-------------------------|-------------------|
| SnackBar | `Error completing onboarding: $e` | API or Database exception (e.g. *Error completing onboarding: Connection refused*). |
| SnackBar | `Copied $displayName link to clipboard!` | Action confirmation or status message. |
| SnackBar | `Profile photo updated and saved!` | Action confirmation or status message. |
| Text Label | `Error completing onboarding: $e` | API or Database exception (e.g. *Error completing onboarding: Connection refused*). |
