Data & Account Deletion Policy
===============================

This page explains how you can delete your data and account associated with the DailyRhythm app.

Option 1: Delete Specific Data (Keep Your Account)
---------------------------------------------------

You can delete your data without removing your Google account access. This gives you control over what information is removed while keeping the app functional.

Delete Google Drive Backups
~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Open `Google Drive <https://drive.google.com>`_
2. Find the folder named **"DailyRhythm_Backups"**
3. Right-click the folder and select **"Move to trash"**
4. Empty your Google Drive trash to permanently delete the backups

Delete Local App Data
~~~~~~~~~~~~~~~~~~~~~~

1. Open your device **Settings**
2. Go to **Apps** → **DailyRhythm**
3. Tap **Storage** → **Clear Data**
4. Confirm the deletion

.. note::
   This deletes all mood tracking data, activities, and app settings stored on your device.

Option 2: Delete Account & All Data
------------------------------------

To completely remove DailyRhythm's access to your Google account and delete all associated data:

Revoke Google Account Access
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

1. Visit `Google Account Permissions <https://myaccount.google.com/permissions>`_
2. Sign in to your Google account if prompted
3. Find **"DailyRhythm"** in the list of apps with access
4. Click on it and select **"Remove Access"**
5. Confirm the removal

Delete All App Data
~~~~~~~~~~~~~~~~~~~~

1. Follow the steps in **Option 1** above to delete:

   * Google Drive backups
   * Local app data

2. **Uninstall the app** from your device (optional but recommended)

What Data Gets Deleted?
------------------------

Data Deleted Immediately
~~~~~~~~~~~~~~~~~~~~~~~~~

* **Google Drive Backups:** All backup database files (.db files) are permanently deleted when you remove them from Google Drive trash
* **Local Database:** All mood entries, activity logs, and personal tracking data stored on your device
* **App Preferences:** Settings, last backup time, and other configuration data
* **Authentication Tokens:** Google Sign-In tokens are revoked immediately

Data Retention
~~~~~~~~~~~~~~

* **No server-side data:** DailyRhythm does not store any user data on external servers
* **Google account info:** Your Google account email and profile remain with Google (not controlled by DailyRhythm)
* **Immediate deletion:** All app-specific data is deleted immediately when you follow the steps above

.. warning::
   **Important:** Data deletion is permanent and cannot be undone. Make sure you have exported any data you want to keep before proceeding with deletion.

Need Help?
----------

If you need assistance with deleting your data or have questions about this policy, please:

* Open an issue on our `GitHub repository <https://github.com/NotYuSheng/DailyRhythm/issues>`_
* Review our `privacy practices <https://github.com/NotYuSheng/DailyRhythm>`_

----

*Last updated: December 25, 2025*

*DailyRhythm - Daily stats tracking app with rhythm aesthetic*
