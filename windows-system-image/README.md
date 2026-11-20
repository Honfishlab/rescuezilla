# Windows System Image

This Windows companion uses Microsoft's wbadmin to create a live image of the Windows volume and all Windows-critical volumes. It includes installed apps and data on those volumes. Other data volumes require separate backups. Rescuezilla can create a separate offline disk image using its own format.

## First use

1. Extract the ZIP into a folder you control. If Windows marks the download as blocked, inspect the included scripts and use the ZIP's Properties > Unblock before extracting.
2. Connect the separate NTFS SSD. Double-click **Open-System-Image.cmd**, then approve the Windows administrator prompt.
3. Select the SSD by its label, model and available space. Click **Update backup**. Next time the app matches the saved SSD volume identity even if Windows changes its drive letter. Keep it connected until the operation finishes.
4. Read the catalog result. **Check backup catalog** repeats that read without imaging the disk. The bare-metal status uses the English wbadmin output. The app leaves native output visible for other languages. Operation logs are under %LOCALAPPDATA%\SystemImageBackup.

## Restore after disk failure

- Create a dedicated **Windows Recovery Drive** with Windows' Recovery Drive tool. Choose the USB carefully because creation erases it. Keep the SSD for the image and retain any BitLocker recovery keys offline.
- Boot the PC from the recovery USB. In Windows Recovery Environment, open **Troubleshoot > Advanced options > System Image Recovery**. If the recovery drive does not expose that option, boot matching Windows installation media and choose **Repair your computer** to enter Windows Recovery Environment.
- Connect the SSD and check that recovery can see the expected image date. Exit before initiating recovery during a readiness check. An end-to-end test needs a spare disk or a suitable test environment. A restore can overwrite its destination.
- A Rescuezilla USB is useful for a separate offline backup and restore workflow. The Windows image made by this app should be restored using Windows Recovery Environment.

References: [Windows backup command](https://learn.microsoft.com/windows-server/administration/windows-commands/wbadmin-start-backup), [Rescuezilla](https://github.com/rescuezilla/rescuezilla).
